from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..core.config import get_settings
from ..core.database import get_db
from ..core.rate_limit import limiter
from ..core.security import (
    create_access_token,
    create_oauth_link_token,
    create_refresh_token,
    decode_token,
    get_password_hash,
)
from ..dependencies import get_current_user
from ..models.user import User
from ..schemas import Token, TokenPair
from ..schemas.auth import (
    AppleOAuthRequest,
    AuthStatus,
    EmailCodeConfirm,
    EmailCodeRequest,
    GoogleOAuthRequest,
    PasswordResetConfirm,
    SocialAuthResponse,
    SocialLinkConfirmRequest,
)
from ..schemas.user import UserCreate, UserLogin, UserOut
from ..services import AuthService
from ..services.auth_email_codes import AuthEmailCodeService
from ..services.email import EmailDeliveryError, send_password_reset_code_email, send_verification_code_email
from ..services.oauth_id_tokens import OAuthIDTokenService, OAuthIdentityError, VerifiedOAuthIdentity
from ..services.users import UserService, seed_admin_user


router = APIRouter()
OTP_TTL_MINUTES = 15


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=10)


def _send_verification_email(email: str, code: str) -> None:
    try:
        send_verification_code_email(email, code, OTP_TTL_MINUTES)
    except EmailDeliveryError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Verification email is temporarily unavailable",
        ) from exc


def _issue_token_pair(user: User) -> TokenPair:
    settings = get_settings()
    access_minutes = settings.ACCESS_TOKEN_EXPIRE_MINUTES
    access = create_access_token(
        subject=user.id,
        is_admin=user.is_superuser,
        role=getattr(user, "role", None),
        expires_delta=timedelta(minutes=access_minutes),
    )
    refresh = create_refresh_token(subject=user.id)
    return TokenPair(
        access_token=access,
        refresh_token=refresh,
        expires_in=access_minutes * 60,
        user_id=user.id,
        email=user.email,
    )


def _social_auth_response(user: User, *, name: str | None = None) -> SocialAuthResponse:
    tokens = _issue_token_pair(user)
    return SocialAuthResponse(
        status="authenticated",
        user_id=user.id,
        email=user.email,
        name=name,
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        token_type=tokens.token_type,
        expires_in=tokens.expires_in,
    )


def _issue_oauth_link_token(*, provider: str, identity: VerifiedOAuthIdentity, name: str | None = None) -> str:
    return create_oauth_link_token(
        (identity.email or "").lower(),
        claims={
        "provider": provider,
        "provider_sub": identity.subject,
        "name": name,
        },
        expires_delta=timedelta(minutes=15),
    )


def _complete_oauth_sign_in(
    *,
    db: Session,
    provider: str,
    identity: VerifiedOAuthIdentity,
    requested_name: str | None = None,
) -> SocialAuthResponse:
    provider_user = UserService.get_by_provider(db, provider, identity.subject)
    resolved_name = (requested_name or identity.name or "").strip() or None
    if provider_user:
        if not provider_user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is inactive")
        return _social_auth_response(provider_user, name=resolved_name)

    normalized_email = (identity.email or "").strip().lower()
    if not normalized_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No verified email was provided by the sign-in provider",
        )

    existing_user = UserService.get_by_email(db, normalized_email)
    if existing_user:
        if not existing_user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is inactive")

        if existing_user.password_login_enabled:
            return SocialAuthResponse(
                status="link_required",
                email=normalized_email,
                provider=provider,
                name=resolved_name,
                message="Account already exists. Confirm your password to link this sign-in method.",
                link_token=_issue_oauth_link_token(provider=provider, identity=identity, name=resolved_name),
            )

        try:
            linked_user = UserService.link_provider(db, user=existing_user, provider=provider, provider_sub=identity.subject)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
        return _social_auth_response(linked_user, name=resolved_name)

    created_user = UserService.create_social(
        db,
        email=normalized_email,
        provider=provider,
        provider_sub=identity.subject,
        email_verified=identity.email_verified or True,
    )
    return _social_auth_response(created_user, name=resolved_name)


def _decode_oauth_link_token(link_token: str) -> dict:
    try:
        payload = decode_token(link_token, expected_type="oauth_link")
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid link token") from exc

    if payload.get("type") != "oauth_link":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid link token")
    if payload.get("provider") not in {"apple", "google"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid link token")
    if not payload.get("provider_sub") or not payload.get("sub"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid link token")
    return payload


@router.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)) -> Token:
    token = AuthService.authenticate_admin(db, form_data.username, form_data.password)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    return Token(access_token=token)


@router.post("/register", response_model=AuthStatus, status_code=status.HTTP_201_CREATED)
def register(
    user_in: UserCreate,
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
        _send_verification_email(existing_user.email, code)
        return AuthStatus(status="verification_required", email=existing_user.email, message="Verification code sent")

    user = UserService.create(db, email=user_in.email, password=user_in.password, email_verified=False)
    code = AuthEmailCodeService.issue_code(
        db,
        user=user,
        purpose=AuthEmailCodeService.VERIFY_EMAIL,
        ttl_minutes=OTP_TTL_MINUTES,
    )
    _send_verification_email(user.email, code)
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


@router.post("/oauth/apple", response_model=SocialAuthResponse)
@limiter.limit("10/minute")
def oauth_apple_sign_in(
    request: Request,
    payload: AppleOAuthRequest,
    db: Session = Depends(get_db),
) -> SocialAuthResponse:
    try:
        identity = OAuthIDTokenService.verify_apple_id_token(payload.id_token, raw_nonce=payload.nonce)
    except OAuthIdentityError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    return _complete_oauth_sign_in(
        db=db,
        provider="apple",
        identity=identity,
        requested_name=payload.full_name,
    )


@router.post("/oauth/google", response_model=SocialAuthResponse)
@limiter.limit("10/minute")
def oauth_google_sign_in(
    request: Request,
    payload: GoogleOAuthRequest,
    db: Session = Depends(get_db),
) -> SocialAuthResponse:
    try:
        identity = OAuthIDTokenService.verify_google_id_token(payload.id_token)
    except OAuthIdentityError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    return _complete_oauth_sign_in(
        db=db,
        provider="google",
        identity=identity,
        requested_name=payload.full_name,
    )


@router.post("/oauth/link/confirm", response_model=SocialAuthResponse)
@limiter.limit("10/15minute")
def confirm_social_link(
    request: Request,
    payload: SocialLinkConfirmRequest,
    db: Session = Depends(get_db),
) -> SocialAuthResponse:
    link_payload = _decode_oauth_link_token(payload.link_token)
    token_email = str(link_payload.get("sub") or "").strip().lower()
    provider = str(link_payload.get("provider") or "").strip()
    provider_sub = str(link_payload.get("provider_sub") or "").strip()
    requested_name = str(link_payload.get("name") or "").strip() or None

    if payload.email.lower() != token_email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email does not match link request")

    user = UserService.authenticate(db, email=payload.email, password=payload.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    try:
        linked_user = UserService.link_provider(db, user=user, provider=provider, provider_sub=provider_sub)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc

    return _social_auth_response(linked_user, name=requested_name)


@router.post("/refresh", response_model=TokenPair)
def refresh_access_token(payload: RefreshTokenRequest, db: Session = Depends(get_db)) -> TokenPair:
    try:
        token_data = decode_token(payload.refresh_token, expected_type="refresh")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    if token_data.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user_id = token_data.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user = UserService.get_by_id(db, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid user")

    return _issue_token_pair(user)


@router.post("/verify-email/request", response_model=AuthStatus)
@limiter.limit("3/15minute")
def request_email_verification(
    request: Request,
    payload: EmailCodeRequest,
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
    _send_verification_email(user.email, code)
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
    db: Session = Depends(get_db),
) -> AuthStatus:
    """
    Issue a short-lived password reset code and send it via email.

    For security reasons, this endpoint always returns a generic success
    response even if the email does not exist, so that attackers cannot
    enumerate accounts.
    """
    user = UserService.get_by_email(db, payload.email)
    if not user or not user.is_active or not user.email_verified or not user.password_login_enabled:
        return AuthStatus(status="ok")

    code = AuthEmailCodeService.issue_code(
        db,
        user=user,
        purpose=AuthEmailCodeService.RESET_PASSWORD,
        ttl_minutes=OTP_TTL_MINUTES,
    )
    try:
        send_password_reset_code_email(user.email, code, OTP_TTL_MINUTES)
    except EmailDeliveryError:
        # Keep response indistinguishable from unknown-account flow.
        pass
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


@router.get("/me", response_model=UserOut)
def get_my_account(current_user: User = Depends(get_current_user)) -> User:
    return current_user
