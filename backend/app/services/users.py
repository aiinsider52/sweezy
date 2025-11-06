from __future__ import annotations

from sqlalchemy.orm import Session

from ..core.security import get_password_hash, verify_password
from ..core.config import get_settings
from ..models.user import User


class UserService:
    @staticmethod
    def get_by_email(db: Session, email: str) -> User | None:
        return db.query(User).filter(User.email == email.lower()).one_or_none()

    @staticmethod
    def create(db: Session, *, email: str, password: str, is_superuser: bool = False) -> User:
        user = User(
            email=email.lower(),
            hashed_password=get_password_hash(password),
            is_superuser=is_superuser,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def authenticate(db: Session, *, email: str, password: str) -> User | None:
        user = UserService.get_by_email(db, email)
        if not user or not verify_password(password, user.hashed_password):
            return None
        if not user.is_active:
            return None
        return user


def seed_admin_user(db: Session) -> None:
    settings = get_settings()
    admin_email = settings.ADMIN_EMAIL
    admin_password = settings.ADMIN_PASSWORD
    if not admin_email or not admin_password:
        return
    user = UserService.get_by_email(db, admin_email)
    if user is None:
        UserService.create(db, email=admin_email, password=admin_password, is_superuser=True)
        return
    # Ensure superuser flag and sync password from env if it has changed
    updated = False
    if not user.is_superuser:
        user.is_superuser = True
        updated = True
    if not verify_password(admin_password, user.hashed_password):
        user.hashed_password = get_password_hash(admin_password)
        updated = True
    if updated:
        db.add(user)
        db.commit()


