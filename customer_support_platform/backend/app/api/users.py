from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from pwdlib import PasswordHash

from app.api.auth import get_current_user
from app.database.connection import get_db
from app.database.models.user import User, UserRole


router = APIRouter(
    prefix="/users",
    tags=["Users"]
)

password_hash = PasswordHash.recommended()


# ============================================================
# USER DIRECTORY  (agents + admins)
# Lightweight id -> name/role lookup for the web dashboard so
# tickets and conversations can show names instead of raw ids.
# ============================================================

@router.get("/directory")
def user_directory(
    role: UserRole | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role not in {UserRole.AGENT, UserRole.ADMIN}:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can view the user directory",
        )

    query = db.query(User)
    if role is not None:
        query = query.filter(User.role == role)

    users = query.order_by(User.name.asc()).all()

    return [
        {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "role": user.role,
            "is_active": user.is_active,
            "created_at": user.created_at,
        }
        for user in users
    ]


@router.post("/")
def create_user(
    name: str,
    email: str,
    password: str,
    role: UserRole = UserRole.CUSTOMER,
    db: Session = Depends(get_db)
):
    # Check if email already exists
    existing_user = db.query(User).filter(
        User.email == email
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    # Hash password
    hashed_password = password_hash.hash(password)

    user = User(
        name=name,
        email=email,
        password_hash=hashed_password,
        role=role
    )

    try:
        db.add(user)
        db.commit()
        db.refresh(user)

    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "is_active": user.is_active
    }