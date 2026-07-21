from __future__ import annotations

from datetime import timedelta

from sqlalchemy.orm import Session

from ..core.config import get_settings
from ..core.security import create_access_token


class AuthService:
    @staticmethod
    def authenticate_admin(db: Session, email: str, password: str) -> str | None:
        from .users import UserService

        user = UserService.authenticate(db, email=email, password=password)
        if not user or not user.is_superuser:
            return None

        token = create_access_token(
            subject=user.id,
            is_admin=True,
            role=user.role,
            expires_delta=timedelta(minutes=get_settings().ACCESS_TOKEN_EXPIRE_MINUTES),
        )
        return token
