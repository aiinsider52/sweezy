from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..core.config import get_settings
from ..core.database import get_db
from ..core.rate_limit import limiter
from ..core.security import create_access_token, create_refresh_token, decode_token, get_password_hash
from ..dependencies import get_current_user
from ..models.user import User
from ..schemas import Token, TokenPair
from ..schemas.auth import AuthStatus, EmailCodeConfirm, EmailCodeRequest, PasswordResetConfirm
from ..schemas.user import UserCreate, UserLogin
from ..services import AuthService
from ..services.auth_email_codes import AuthEmailCodeService
from ..services.email import send_password_reset_code_email, send_verification_code_email
from ..services.users import UserService, seed_admin_user


router = APIRouter()
OTP_TTL_MINUTES = 15


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=10)


def _issue_token_pair(user: User) -> TokenPair:
    settings = get_settings()
    access_minutes = settings.ACCESS_TOKEN_EXPIRE_MINUTES
    access = create_access_token(
        subject=user.email,
        is_admin=user.is_superuser,
        role=getattr(user, "role", None),
        expires_delta=timedelta(minutes=access_minutes),
    )
    refresh = create_refresh_token(subject=user.email, expires_delta=timedelta(days=7))
    return TokenPair(access_token=access, refresh_token=refresh, expires_in=access_minutes * 60)


@router.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()) -> Token:
    token = AuthService.authenticate_admin(form_data.username, form_data.password)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    return Token(access_token=token)


@router.post("/register", response_model=AuthStatus, status_code=status.HTTP_201_CREATED)
def register(
    user_in: UserCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> AuthStatus:
    existing_user = UserService.get_by_email(db, user_in.email)
    if existing_user:
        if existing_user.email_verified:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")
        code = AuthEmailCodeService.issue_code(
            db,
            user=existing_user,
            purpose=AuthEmailCodeService.VERIFY_EMAIL,
            ttl_minutes=OTP_TTL_MINUTES,
        )
        background_tasks.add_task(send_verification_code_email, existing_user.email, code, OTP_TTL_MINUTES)
        return AuthStatus(status="verification_required", email=existing_user.email, message="Verification code sent")

    user = UserService.create(db, email=user_in.email, password=user_in.password, email_verified=False)
    code = AuthEmailCodeService.issue_code(
        db,
        user=user,
        purpose=AuthEmailCodeService.VERIFY_EMAIL,
        ttl_minutes=OTP_TTL_MINUTES,
    )
    background_tasks.add_task(send_verification_code_email, user.email, code, OTP_TTL_MINUTES)
    return AuthStatus(status="verification_required", email=user.email, message="Verification code sent")


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
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "EMAIL_NOT_VERIFIED", "message": "Email not verified"},
        )
    return _issue_token_pair(user)


@router.post("/refresh", response_model=TokenPair)
def refresh_access_token(payload: RefreshTokenRequest, db: Session = Depends(get_db)) -> TokenPair:
    try:
        token_data = decode_token(payload.refresh_token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    if token_data.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    email = token_data.get("sub")
    if not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user = UserService.get_by_email(db, email)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid user")

    return _issue_token_pair(user)


@router.post("/verify-email/request", response_model=AuthStatus)
@limiter.limit("3/15minute")
def request_email_verification(
    request: Request,
    payload: EmailCodeRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> AuthStatus:
    user = UserService.get_by_email(db, payload.email)
    if not user or not user.is_active:
        return AuthStatus(status="ok")
    if user.email_verified:
        return AuthStatus(status="already_verified", email=user.email)

    code = AuthEmailCodeService.issue_code(
        db,
        user=user,
        purpose=AuthEmailCodeService.VERIFY_EMAIL,
        ttl_minutes=OTP_TTL_MINUTES,
    )
    background_tasks.add_task(send_verification_code_email, user.email, code, OTP_TTL_MINUTES)
    return AuthStatus(status="verification_required", email=user.email, message="Verification code sent")


@router.post("/verify-email/confirm", response_model=TokenPair)
@limiter.limit("5/15minute")
def confirm_email_verification(
    request: Request,
    payload: EmailCodeConfirm,
    db: Session = Depends(get_db),
) -> TokenPair:
    result = AuthEmailCodeService.validate_code(
        db,
        email=payload.email,
        purpose=AuthEmailCodeService.VERIFY_EMAIL,
        code=payload.code,
    )
    if not result.ok or not result.user or not result.user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired code")

    if not result.user.email_verified:
        result.user.email_verified = True
        result.user.email_verified_at = datetime.now(timezone.utc)
        db.add(result.user)
        db.commit()
        db.refresh(result.user)
    return _issue_token_pair(result.user)


@router.post("/password/forgot", response_model=AuthStatus)
@limiter.limit("5/minute")
def forgot_password(
    request: Request,
    payload: EmailCodeRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> AuthStatus:
    """
    Issue a short-lived password reset code and send it via email.

    For security reasons, this endpoint always returns a generic success
    response even if the email does not exist, so that attackers cannot
    enumerate accounts.
    """
    user = UserService.get_by_email(db, payload.email)
    if not user or not user.is_active or not user.email_verified:
        return AuthStatus(status="ok")

    code = AuthEmailCodeService.issue_code(
        db,
        user=user,
        purpose=AuthEmailCodeService.RESET_PASSWORD,
        ttl_minutes=OTP_TTL_MINUTES,
    )
    background_tasks.add_task(send_password_reset_code_email, user.email, code, OTP_TTL_MINUTES)
    return AuthStatus(status="ok")


@router.post("/password/reset", response_model=AuthStatus)
@limiter.limit("5/15minute")
def reset_password(
    request: Request,
    payload: PasswordResetConfirm,
    db: Session = Depends(get_db),
) -> AuthStatus:
    """
    Validate a password reset code and set a new password.
    """
    result = AuthEmailCodeService.validate_code(
        db,
        email=payload.email,
        purpose=AuthEmailCodeService.RESET_PASSWORD,
        code=payload.code,
    )
    if not result.ok or not result.user or not result.user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired code")

    user = result.user
    user.hashed_password = get_password_hash(payload.password)
    db.add(user)
    db.commit()
    return AuthStatus(status="ok")


@router.post("/seed-admin")
def seed_admin(request: Request, db: Session = Depends(get_db)) -> dict:
    settings = get_settings()
    secret = request.headers.get("x-setup-secret")
    allowed = [s for s in [settings.SETUP_SECRET, settings.SECRET_KEY, settings.JWT_SECRET_KEY] if s]
    if not allowed or secret not in allowed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    seed_admin_user(db)
    return {"status": "ok"}


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    """
    Permanently delete the current user's account (App Store account deletion compliance).
    """
    UserService.delete_account(db, user=current_user)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

