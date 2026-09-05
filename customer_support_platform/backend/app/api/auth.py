import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
import jwt
from pwdlib import PasswordHash
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import settings
from app.database.connection import get_db
from app.database.models.user import User, UserRole


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)


password_hash = PasswordHash.recommended()


oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/login"
)


# ============================================================
# JWT CONFIGURATION
# ============================================================

SECRET_KEY = settings.JWT_SECRET_KEY
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60


# ============================================================
# PASSWORD VERIFICATION
# ============================================================

def verify_password(
    password: str,
    hashed_password: str
):
    return password_hash.verify(
        password,
        hashed_password
    )


# ============================================================
# CREATE JWT ACCESS TOKEN
# ============================================================

def create_access_token(user_id: int):
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": str(user_id),
        "exp": expire
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM
    )


def _user_dict(user: User) -> dict:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "phone": getattr(user, "phone", None),
        "location": getattr(user, "location", None),
        "organization": getattr(user, "organization", None),
        "is_active": user.is_active,
    }


# ============================================================
# REGISTER  (public - customers only; agents/admins are created
# by an administrator, see app/api/users.py)
# ============================================================

class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=8, max_length=128)

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


@router.post("/register")
def register(
    payload: RegisterRequest,
    db: Session = Depends(get_db)
):
    existing = db.query(User).filter(
        User.email == payload.email
    ).first()

    if existing:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    user = User(
        name=payload.name,
        email=payload.email,
        password_hash=password_hash.hash(payload.password),
        role=UserRole.CUSTOMER
    )

    db.add(user)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    db.refresh(user)

    access_token = create_access_token(user.id)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": _user_dict(user)
    }


# ============================================================
# LOGIN
# ============================================================

@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(
        User.email == form_data.username
    ).first()

    if not user:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    if not verify_password(
        form_data.password,
        user.password_hash
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="User account is inactive"
        )

    access_token = create_access_token(
        user.id
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": _user_dict(user)
    }


# ============================================================
# GET CURRENT USER
# ============================================================

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        user_id = payload.get("sub")

        if user_id is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid token"
            )

        user = db.query(User).filter(
            User.id == int(user_id)
        ).first()

        if user is None:
            raise HTTPException(
                status_code=401,
                detail="User not found"
            )

        if not user.is_active:
            raise HTTPException(
                status_code=403,
                detail="User account is inactive"
            )

        return user

    except HTTPException:
        raise

    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token"
        )


# ============================================================
# CURRENT USER PROFILE
# ============================================================

@router.get("/me")
def get_me(
    current_user: User = Depends(get_current_user)
):
    return _user_dict(current_user)


class ProfileUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    phone: str | None = Field(None, max_length=50)
    location: str | None = Field(None, max_length=150)
    organization: str | None = Field(None, max_length=150)


@router.put("/profile")
def update_profile(
    payload: ProfileUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.name is not None:
        current_user.name = payload.name.strip()
    if payload.phone is not None:
        current_user.phone = payload.phone.strip()
    if payload.location is not None:
        current_user.location = payload.location.strip()
    if payload.organization is not None:
        current_user.organization = payload.organization.strip()

    db.commit()
    db.refresh(current_user)
    return _user_dict(current_user)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.islower() for c in v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one number")
        return v


@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=400,
            detail="Current password is incorrect"
        )

    current_user.password_hash = password_hash.hash(payload.new_password)
    db.commit()
    return {"message": "Password updated successfully"}


# ============================================================
# LOGOUT
# ============================================================

@router.post("/logout")
def logout(
    current_user: User = Depends(get_current_user)
):
    return {
        "message": "Successfully logged out",
        "user_id": current_user.id
    }