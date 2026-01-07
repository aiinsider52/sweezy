from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, status, BackgroundTasks
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from ..schemas import Token, TokenPair
from ..schemas.user import UserCreate, UserLogin, UserOut
from ..services import AuthService
from ..services.users import UserService, seed_admin_user
from ..services.email import send_password_reset_email
from ..core.security import create_access_token, create_refresh_token, decode_token, get_password_hash
from ..core.password_policy import validate_password_strength
from ..core.database import get_db
from ..core.config import get_settings
from ..core.rate_limit import limiter
from pydantic import BaseModel, EmailStr, Field
from datetime import timedelta


router = APIRouter()


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    token: str = Field(..., min_length=10)
    password: str = Field(..., min_length=8)

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        ok, message = validate_password_strength(v)
        if not ok:
            raise ValueError(message or "Weak password")
        return v


@router.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()) -> Token:
    token = AuthService.authenticate_admin(form_data.username, form_data.password)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    return Token(access_token=token)


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(user_in: UserCreate, db: Session = Depends(get_db)) -> UserOut:
    if UserService.get_by_email(db, user_in.email):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")
    user = UserService.create(db, email=user_in.email, password=user_in.password)
    return UserOut.model_validate(user)


@router.post("/login", response_model=TokenPair)
@limiter.limit("10/minute")
def login_user(
    request: Request,
    payload: UserLogin,
    db: Session = Depends(get_db),
) -> TokenPair:
    user = UserService.authenticate(db, email=payload.email, password=payload.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    access = create_access_token(subject=user.email, is_admin=user.is_superuser, role=getattr(user, "role", None), expires_delta=timedelta(minutes=15))
    refresh = create_refresh_token(subject=user.email, expires_delta=timedelta(days=7))

    return TokenPair(access_token=access, refresh_token=refresh, expires_in=15 * 60)


@router.post("/password/forgot")
@limiter.limit("5/minute")
def forgot_password(
    request: Request,
    payload: PasswordResetRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> dict:
    """
    Issue a short‑lived password reset token and send it via email.

    For security reasons, this endpoint always returns a generic success
    response even if the email does not exist, so that attackers cannot
    enumerate accounts.
    """
    user = UserService.get_by_email(db, payload.email)
    if not user or not user.is_active:
        # Do not leak whether the user exists.
        return {"status": "ok"}

    # Use a refresh‑style token with a short expiry specifically for password reset.
    token = create_refresh_token(subject=user.email, expires_delta=timedelta(hours=1))
    background_tasks.add_task(send_password_reset_email, user.email, token)
    return {"status": "ok"}


@router.post("/password/reset")
def reset_password(payload: PasswordResetConfirm, db: Session = Depends(get_db)) -> dict:
    """
    Validate a password reset token and set a new password.
    """
    try:
        data = decode_token(payload.token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired token")

    email = data.get("sub")
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid token")

    user = UserService.get_by_email(db, email)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid token")

    user.hashed_password = get_password_hash(payload.password)
    db.add(user)
    db.commit()
    return {"status": "ok"}


@router.post("/seed-admin")
def seed_admin(request: Request, db: Session = Depends(get_db)) -> dict:
    settings = get_settings()
    secret = request.headers.get("x-setup-secret")
    allowed = [s for s in [settings.SETUP_SECRET, settings.SECRET_KEY, settings.JWT_SECRET_KEY] if s]
    if not allowed or secret not in allowed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    seed_admin_user(db)
    return {"status": "ok"}

