from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import uuid4

import jwt
from jwt.exceptions import InvalidTokenError
from passlib.context import CryptContext

from .config import get_settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def _create_typed_token(
    subject: str,
    *,
    token_type: str,
    expires_delta: timedelta,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "iat": now,
        "nbf": now,
        "exp": now + expires_delta,
        "jti": str(uuid4()),
    }
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_access_token(
    subject: str,
    *,
    is_admin: bool = False,
    role: str | None = None,
    expires_delta: timedelta | None = None,
) -> str:
    settings = get_settings()
    claims: dict[str, Any] = {"is_admin": is_admin}
    if role:
        claims["role"] = role
    return _create_typed_token(
        subject,
        token_type="access",
        expires_delta=expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        extra_claims=claims,
    )


def decode_token(token: str, *, expected_type: str | None = "access") -> dict[str, Any]:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
            audience=settings.JWT_AUDIENCE,
            issuer=settings.JWT_ISSUER,
            options={"require": ["exp", "sub", "iat", "nbf", "iss", "aud"]},
        )
        if expected_type is not None and payload.get("type") != expected_type:
            raise ValueError("Invalid token type")
        return payload
    except (InvalidTokenError, ValueError) as exc:
        raise ValueError("Invalid token") from exc


def create_refresh_token(subject: str, *, expires_delta: timedelta | None = None) -> str:
    settings = get_settings()
    return _create_typed_token(
        subject,
        token_type="refresh",
        expires_delta=expires_delta or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )


def create_oauth_link_token(subject: str, *, claims: dict[str, Any], expires_delta: timedelta) -> str:
    return _create_typed_token(
        subject,
        token_type="oauth_link",
        expires_delta=expires_delta,
        extra_claims=claims,
    )
