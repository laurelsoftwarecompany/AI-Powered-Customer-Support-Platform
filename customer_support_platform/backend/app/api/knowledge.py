from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.auth import get_current_user
from app.database.connection import get_db
from app.database.models import KnowledgeDocument, User, UserRole
from app.services import knowledge_service

router = APIRouter(prefix="/knowledge", tags=["Knowledge Base"])


# ============================================================
# helpers
# ============================================================

def _require_staff(user: User) -> None:
    if user.role not in {UserRole.AGENT, UserRole.ADMIN}:
        raise HTTPException(403, "Staff only")


def _require_admin(user: User) -> None:
    if user.role != UserRole.ADMIN:
        raise HTTPException(403, "Only administrators can manage the knowledge base")


def _serialize(db: Session, doc: KnowledgeDocument, include_content: bool = False) -> dict:
    total, embedded = knowledge_service.index_status(db, doc.id)
    summary = ""
    if doc.content:
        clean_lines = [
            line.strip().lstrip("#").strip()
            for line in doc.content.splitlines()
            if line.strip()
        ]
        body_lines = clean_lines[1:] if len(clean_lines) > 1 else clean_lines
        joined = " ".join(body_lines)
        summary = (joined[:180] + "...") if len(joined) > 180 else joined

    data = {
        "id": doc.id,
        "title": doc.title,
        "filename": doc.filename,
        "file_type": doc.file_type,
        "status": doc.status,
        "summary": summary,
        "chunk_count": total,
        "embedded_chunks": embedded,
        "indexed": total > 0 and embedded == total,
        "char_count": len(doc.content or ""),
        "created_at": doc.created_at,
        "updated_at": doc.updated_at,
    }
    if include_content:
        data["content"] = doc.content
    return data


# ============================================================
# schemas
# ============================================================

class FaqIn(BaseModel):
    question: str = Field(..., min_length=3, max_length=500)
    answer: str = Field(..., min_length=3)


class DocStatusIn(BaseModel):
    status: str = Field(..., pattern="^(active|archived)$")


# ============================================================
# list / detail
# ============================================================

@router.get("/documents")
def list_documents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(KnowledgeDocument)
    if current_user.role == UserRole.CUSTOMER:
        query = query.filter(KnowledgeDocument.status == "active")
    docs = query.order_by(KnowledgeDocument.id.asc()).all()
    return [_serialize(db, d, include_content=True) for d in docs]


@router.get("/documents/{document_id}")
def get_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(KnowledgeDocument).filter(KnowledgeDocument.id == document_id)
    if current_user.role == UserRole.CUSTOMER:
        query = query.filter(KnowledgeDocument.status == "active")
    doc = query.first()
    if not doc:
        raise HTTPException(404, "Document not found")
    return _serialize(db, doc, include_content=True)


# ============================================================
# create - file upload
# ============================================================

@router.post("/documents", status_code=201)
async def upload_document(
    file: UploadFile = File(...),
    title: str | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_admin(current_user)

    raw_name = file.filename or "document.txt"
    # Path traversal protection: strip directory components
    import os
    name = os.path.basename(raw_name).replace("..", "").strip()
    if not name:
        name = "document.txt"

    ext = name.rsplit(".", 1)[-1].lower() if "." in name else "txt"
    if ext not in {"pdf", "txt", "md", "markdown"}:
        raise HTTPException(400, "Supported file types: PDF, TXT, Markdown")

    # Bounded streaming read to prevent server OOM DoS attacks
    max_upload_size = 10 * 1024 * 1024  # 10 MB
    chunk_size = 64 * 1024
    total_bytes = 0
    buffer = bytearray()

    while True:
        chunk = await file.read(chunk_size)
        if not chunk:
            break
        total_bytes += len(chunk)
        if total_bytes > max_upload_size:
            raise HTTPException(
                status_code=413,
                detail=f"File exceeds maximum allowed size of {max_upload_size // (1024 * 1024)} MB",
            )
        buffer.extend(chunk)

    data = bytes(buffer)
    if not data:
        raise HTTPException(400, "The uploaded file is empty")

    try:
        text = knowledge_service.extract_text(data, ext)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(400, f"Could not read the file: {exc}")

    if not text.strip():
        raise HTTPException(400, "No text could be extracted from the file")

    doc = knowledge_service.create_document(
        db,
        title=title or name.rsplit(".", 1)[0],
        filename=name,
        file_type=ext,
        content=text,
    )

    # Index in the background-ish (synchronous but only this doc).
    try:
        knowledge_service.reindex(db, doc.id)
    except Exception:  # noqa: BLE001
        pass  # document is saved; indexing can be retried

    db.refresh(doc)
    return _serialize(db, doc)


# ============================================================
# create - FAQ
# ============================================================

@router.post("/faqs", status_code=201)
def add_faq(
    body: FaqIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_admin(current_user)
    content = f"Q: {body.question.strip()}\nA: {body.answer.strip()}"
    doc = knowledge_service.create_document(
        db,
        title=body.question.strip(),
        filename="faq",
        file_type="faq",
        content=content,
    )
    try:
        knowledge_service.reindex(db, doc.id)
    except Exception:  # noqa: BLE001
        pass
    db.refresh(doc)
    return _serialize(db, doc)


# ============================================================
# update status / delete / reindex
# ============================================================

@router.patch("/documents/{document_id}")
def set_status(
    document_id: int,
    body: DocStatusIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_admin(current_user)
    doc = db.query(KnowledgeDocument).filter(KnowledgeDocument.id == document_id).first()
    if not doc:
        raise HTTPException(404, "Document not found")
    doc.status = body.status
    db.commit()
    db.refresh(doc)
    return _serialize(db, doc)


@router.delete("/documents/{document_id}", status_code=204)
def delete_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_admin(current_user)
    doc = db.query(KnowledgeDocument).filter(KnowledgeDocument.id == document_id).first()
    if not doc:
        raise HTTPException(404, "Document not found")
    db.delete(doc)
    db.commit()


@router.post("/reindex")
def reindex_all(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_admin(current_user)
    try:
        count = knowledge_service.reindex(db)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            503,
            f"Indexing is unavailable (embedding model not installed?): {exc}",
        )
    return {"embedded_chunks": count}
