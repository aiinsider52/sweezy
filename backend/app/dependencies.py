from __future__ import annotations

from typing import Annotated, Dict

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .core.database import get_db
from .core.security import decode_token
from .services.users import UserService
from datetime import datetime, timezone


security_scheme = HTTPBearer(auto_error=True)


def get_current_admin(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security_scheme)],
    db: Session = Depends(get_db),
) -> Dict:
    try:
        payload = decode_token(credentials.credentials)
        user_id = payload.get("sub")
        user = UserService.get_by_id(db, user_id) if user_id else None
        if not user or not user.is_active or not user.is_superuser or not payload.get("is_admin"):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
        return payload
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication")


CurrentAdmin = Annotated[Dict, Depends(get_current_admin)]
DBSession = Annotated[Session, Depends(get_db)]


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security_scheme)],
    db: Session = Depends(get_db),
):
    try:
        payload = decode_token(credentials.credentials)
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
        user = UserService.get_by_id(db, user_id)
        if not user or not user.is_active:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid user")
        return user
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication")

CurrentUser = Annotated[object, Depends(get_current_user)]


def require_roles(*roles: str):
    def dependency(
        credentials: Annotated[HTTPAuthorizationCredentials, Depends(security_scheme)],
        db: Session = Depends(get_db),
    ):
        try:
            payload = decode_token(credentials.credentials)
        except Exception as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication") from exc
        user_id = payload.get("sub")
        user = UserService.get_by_id(db, user_id) if user_id else None
        if not user or not user.is_active:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication")
        if not user.is_superuser and user.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient role")
        return user
    return Depends(dependency)


def require_premium():
    def dependency(user=Depends(get_current_user)):
        # Expire trial/premium if past date
        expire_at = getattr(user, "subscription_expire_at", None)
        status = getattr(user, "subscription_status", "free") or "free"
        if status in {"trial", "premium"} and expire_at is not None:
            try:
                if expire_at < datetime.now(timezone.utc):
                    # downgrade
                    user.subscription_status = "free"
                    user.subscription_expire_at = None
                    # We do not have db session here; silently rely on next write to persist, or ignore.
                    status = "free"
            except Exception:
                pass
        if status not in {"trial", "premium"}:
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail="Premium required. Subscribe to continue.",
            )
        return user

    return Depends(dependency)
