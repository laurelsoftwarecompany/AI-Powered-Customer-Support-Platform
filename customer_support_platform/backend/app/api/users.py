import re
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
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


class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=8, max_length=128)
    role: UserRole = UserRole.CUSTOMER

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        v = v.strip().lower()
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", v):
            raise ValueError("Invalid email format")
        return v

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.islower() for c in v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one number")
        return v


@router.post("/")
def create_user(
    user_in: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Customers self-register via POST /auth/register. This endpoint creates
    # staff accounts (or customers on an admin's behalf) and is admin-only -
    # it must never be reachable by an unauthenticated caller who could
    # otherwise pick role=admin for themselves.
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can create users"
        )

    # Check if email already exists
    existing_user = db.query(User).filter(
        User.email == user_in.email
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    # Hash password
    hashed_password = password_hash.hash(user_in.password)

    user = User(
        name=user_in.name,
        email=user_in.email,
        password_hash=hashed_password,
        role=user_in.role
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