"""
Knowledge-base ingestion + retrieval.

Pipeline:  document -> extract text -> chunk -> embed -> store
Retrieval: embed query -> cosine similarity over chunk embeddings -> top-k

Embeddings use a local fastembed ONNX model (BAAI/bge-small-en-v1.5, 384-dim,
no PyTorch, no API key). The model is loaded lazily so the API boots instantly
and mock/test runs never pay the download cost. Similarity search runs in
NumPy, which is fine for a knowledge base of this size; swap in pgvector for a
large corpus.
"""

from __future__ import annotations

import io
import re
import threading

import numpy as np
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import settings
from app.database.models import KnowledgeChunk, KnowledgeDocument

SUPPORTED_TYPES = {"pdf", "txt", "md", "markdown", "faq"}

_model = None


def _get_model():
    """Load the embedding model on first use."""
    global _model
    if _model is None:
        from fastembed import TextEmbedding

        _model = TextEmbedding(model_name=settings.EMBEDDING_MODEL)
    return _model


def _embed_passages(texts: list[str]) -> list[list[float]]:
    model = _get_model()
    return [vec.tolist() for vec in model.passage_embed(texts)]


def _embed_query(text: str) -> np.ndarray:
    model = _get_model()
    return next(iter(model.query_embed([text])))


# ---------------------------------------------------------------- extraction

def extract_text(data: bytes, file_type: str) -> str:
    file_type = file_type.lower().lstrip(".")

    if file_type == "pdf":
        from pypdf import PdfReader

        reader = PdfReader(io.BytesIO(data))
        return "\n".join((page.extract_text() or "") for page in reader.pages)

    if file_type in {"txt", "md", "markdown"}:
        return data.decode("utf-8", errors="ignore")

    raise ValueError(f"Unsupported file type: {file_type}")


def clean_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def chunk_text(
    text: str,
    chunk_size: int = 1000,
    chunk_overlap: int = 200,
) -> list[str]:
    if not text:
        return []

    chunks: list[str] = []
    start = 0
    length = len(text)

    while start < length:
        end = start + chunk_size
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end >= length:
            break
        start = end - chunk_overlap

    return chunks


# ---------------------------------------------------------------- ingestion

def create_document(
    db: Session,
    *,
    title: str,
    filename: str,
    file_type: str,
    content: str,
) -> KnowledgeDocument:
    """Store a document and its (un-embedded) chunks. Call reindex() to embed."""
    content = clean_text(content)

    document = KnowledgeDocument(
        title=title,
        filename=filename,
        file_type=file_type,
        content=content,
        status="active",
    )
    db.add(document)
    db.flush()

    for index, chunk in enumerate(chunk_text(content)):
        db.add(
            KnowledgeChunk(
                document_id=document.id,
                chunk_index=index,
                content=chunk,
                embedding=None,
            )
        )

    db.commit()
    db.refresh(document)
    return document


def reindex(db: Session, document_id: int | None = None, batch: int = 128) -> int:
    """Embed every chunk that is missing an embedding. Returns chunks embedded."""
    query = db.query(KnowledgeChunk).filter(KnowledgeChunk.embedding.is_(None))
    if document_id is not None:
        query = query.filter(KnowledgeChunk.document_id == document_id)

    chunks = query.order_by(KnowledgeChunk.id.asc()).all()
    if not chunks:
        return 0

    for i in range(0, len(chunks), batch):
        window = chunks[i : i + batch]
        vectors = _embed_passages([c.content for c in window])
        for chunk, vector in zip(window, vectors):
            chunk.embedding = vector
        db.commit()

    invalidate_index()
    return len(chunks)


def index_status(db: Session, document_id: int) -> tuple[int, int]:
    """(total_chunks, embedded_chunks) for a document."""
    total = (
        db.query(KnowledgeChunk)
        .filter(KnowledgeChunk.document_id == document_id)
        .count()
    )
    embedded = (
        db.query(KnowledgeChunk)
        .filter(
            KnowledgeChunk.document_id == document_id,
            KnowledgeChunk.embedding.isnot(None),
        )
        .count()
    )
    return total, embedded


# ---------------------------------------------------------------- retrieval

# ------------------------------------------------------------- search index
#
# Loading + JSON-decoding every embedding on each question dominated retrieval
# (~250 ms of a ~300 ms search at 417 chunks, and it grows linearly with the
# knowledge base). The normalized matrix is built once and reused.
#
# Rather than asking every mutation path to remember to invalidate, the cache
# is keyed on a cheap aggregate signature of the corpus - a few sub-millisecond
# COUNT/MAX queries - so it self-heals no matter who changes what.

_index_lock = threading.Lock()
_index_cache: dict | None = None


def _corpus_signature(db: Session) -> tuple:
    embedded = (
        db.query(func.count(KnowledgeChunk.id))
        .filter(KnowledgeChunk.embedding.isnot(None))
        .scalar()
    )
    max_chunk = db.query(func.max(KnowledgeChunk.id)).scalar()
    active_docs = (
        db.query(func.count(KnowledgeDocument.id))
        .filter(KnowledgeDocument.status == "active")
        .scalar()
    )
    last_touched = db.query(func.max(KnowledgeDocument.updated_at)).scalar()
    return (embedded, max_chunk, active_docs, str(last_touched))


def _load_index(db: Session) -> dict:
    """Build (or reuse) the normalized embedding matrix and its chunk metadata."""
    global _index_cache

    signature = _corpus_signature(db)
    cached = _index_cache
    if cached is not None and cached["signature"] == signature:
        return cached

    with _index_lock:
        # Re-check: another request may have rebuilt it while we waited.
        cached = _index_cache
        if cached is not None and cached["signature"] == signature:
            return cached

        rows = (
            db.query(
                KnowledgeChunk.chunk_index,
                KnowledgeChunk.content,
                KnowledgeChunk.embedding,
                KnowledgeDocument.id,
                KnowledgeDocument.title,
            )
            .join(
                KnowledgeDocument,
                KnowledgeChunk.document_id == KnowledgeDocument.id,
            )
            .filter(
                KnowledgeChunk.embedding.isnot(None),
                KnowledgeDocument.status == "active",
            )
            .all()
        )

        if not rows:
            index = {"signature": signature, "matrix": None, "meta": []}
        else:
            matrix = np.array([r[2] for r in rows], dtype=np.float32)
            # Normalize once at build time, not per query.
            matrix /= np.linalg.norm(matrix, axis=1, keepdims=True) + 1e-9
            index = {
                "signature": signature,
                "matrix": matrix,
                "meta": [
                    {
                        "document_id": r[3],
                        "document_title": r[4],
                        "chunk_index": r[0],
                        "content": r[1],
                    }
                    for r in rows
                ],
            }

        _index_cache = index
        return index


def invalidate_index() -> None:
    """Drop the cached matrix (called after ingestion; the signature check
    would catch it anyway, this just avoids one stale-read window)."""
    global _index_cache
    _index_cache = None


def search(db: Session, query: str, top_k: int | None = None) -> list[dict]:
    """Return the top-k most relevant active chunks for a query, with scores."""
    top_k = top_k or settings.RAG_TOP_K

    index = _load_index(db)
    matrix = index["matrix"]
    if matrix is None:
        return []

    q_vec = np.asarray(_embed_query(query), dtype=np.float32)
    q_vec /= np.linalg.norm(q_vec) + 1e-9

    # bge embeddings are L2-normalized, so a dot product is cosine similarity.
    scores = matrix @ q_vec

    # argpartition finds the top-k without sorting the whole corpus.
    k = min(top_k, scores.shape[0])
    top = np.argpartition(scores, -k)[-k:]
    order = top[np.argsort(scores[top])[::-1]]

    return [
        {**index["meta"][int(i)], "score": round(float(scores[i]), 4)}
        for i in order
    ]


def _snippet(text: str, limit: int = 240) -> str:
    """One-line preview of a chunk for citation display."""
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    return text[:limit].rsplit(" ", 1)[0].rstrip(",;:") + "…"


def retrieve_context(
    db: Session,
    query: str,
    top_k: int | None = None,
    min_score: float | None = None,
) -> tuple[str | None, list[dict]]:
    """
    Retrieve knowledge-base context for a user question (the RAG step).

    Returns ``(context, sources)``:
      * ``context`` - a numbered text block to hand the LLM, or ``None`` when
        nothing clears ``min_score`` (defaults to ``settings.RAG_MIN_SCORE``).
      * ``sources`` - ``[{document_id, title, score, snippet}]`` for citing the
        answer back to the customer/agent.
    """
    min_score = settings.RAG_MIN_SCORE if min_score is None else min_score
    hits = [h for h in search(db, query, top_k=top_k) if h["score"] >= min_score]
    if not hits:
        return None, []

    context = "\n\n".join(
        f"[{i}] {h['document_title']}\n{h['content']}"
        for i, h in enumerate(hits, start=1)
    )
    sources = [
        {
            "document_id": h["document_id"],
            "title": h["document_title"],
            "score": h["score"],
            "snippet": _snippet(h["content"]),
        }
        for h in hits
    ]
    return context, sources
