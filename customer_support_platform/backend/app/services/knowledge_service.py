from pathlib import Path
import re

from pypdf import PdfReader
from sqlalchemy.orm import Session
from sentence_transformers import SentenceTransformer

from app.database.models import KnowledgeDocument, KnowledgeChunk


embedding_model = SentenceTransformer("all-MiniLM-L6-v2")


def extract_text(file_path: str, file_type: str) -> str:
    """
    Extract text from PDF, TXT, or Markdown files.
    """

    path = Path(file_path)

    if file_type == "pdf":
        reader = PdfReader(str(path))

        pages = []

        for page in reader.pages:
            text = page.extract_text() or ""
            pages.append(text)

        return "\n".join(pages).strip()

    if file_type in {"txt", "md", "markdown"}:
        return path.read_text(
            encoding="utf-8",
            errors="ignore",
        ).strip()

    raise ValueError(
        f"Unsupported file type: {file_type}"
    )
    
def clean_text(text: str) -> str:
    """
    Clean extracted document text before chunking.
    """

    # Normalize line breaks
    text = text.replace("\r\n", "\n")
    text = text.replace("\r", "\n")

    # Remove excessive spaces/tabs
    text = re.sub(r"[ \t]+", " ", text)

    # Remove excessive blank lines
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()

def chunk_text(
    text: str,
    chunk_size: int = 1000,
    chunk_overlap: int = 200,
) -> list[str]:
    """
    Split text into overlapping chunks for embedding and retrieval.
    """

    if not text:
        return []

    chunks = []
    start = 0
    text_length = len(text)

    while start < text_length:
        end = start + chunk_size

        chunk = text[start:end].strip()

        if chunk:
            chunks.append(chunk)

        if end >= text_length:
            break

        start = end - chunk_overlap

    return chunks

def save_document(
    db: Session,
    title: str,
    filename: str,
    file_type: str,
    content: str,
) -> KnowledgeDocument:
    """
    Save a knowledge document and its text chunks to PostgreSQL.
    """

    document = KnowledgeDocument(
        title=title,
        filename=filename,
        file_type=file_type,
        content=content,
        status="active",
    )

    db.add(document)
    db.flush()

    chunks = chunk_text(content)

    for index, chunk in enumerate(chunks):
        knowledge_chunk = KnowledgeChunk(
            document_id=document.id,
            chunk_index=index,
            content=chunk,
            embedding=embedding_model.encode(
                chunk,
                normalize_embeddings=True,
            ).tolist(),
        )

        db.add(knowledge_chunk)

    db.commit()
    db.refresh(document)

    return document