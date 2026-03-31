from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import secrets

from sqlalchemy.orm import Session

from ..core.config import get_settings
from ..models.auth_email_code import AuthEmailCode
from ..models.user import User


@dataclass
class EmailCodeValidationResult:
    ok: bool
    user: User | None = None
    reason: str | None = None


class AuthEmailCodeService:
    VERIFY_EMAIL = "verify_email"
    RESET_PASSWORD = "reset_password"
    CODE_LENGTH = 6
    MAX_ATTEMPTS = 5

    @classmethod
    def issue_code(
        cls,
        db: Session,
        *,
        user: User,
        purpose: str,
        ttl_minutes: int = 15,
    ) -> str:
        email = user.email.lower()
        cls.invalidate_active_codes(db, email=email, purpose=purpose)
        code = cls.generate_code()
        record = AuthEmailCode(
            user_id=user.id,
            email=email,
            purpose=purpose,
            code_hash=cls.hash_code(code),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=ttl_minutes),
        )
        db.add(record)
        db.commit()
        return code

    @classmethod
    def validate_code(
        cls,
        db: Session,
        *,
        email: str,
        purpose: str,
        code: str,
    ) -> EmailCodeValidationResult:
        normalized_email = email.lower().strip()
        record = (
            db.query(AuthEmailCode)
            .filter(
                AuthEmailCode.email == normalized_email,
                AuthEmailCode.purpose == purpose,
                AuthEmailCode.used_at.is_(None),
            )
            .order_by(AuthEmailCode.created_at.desc())
            .first()
        )
        if record is None:
            return EmailCodeValidationResult(ok=False, reason="CODE_NOT_FOUND")
        expires_at = record.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at <= datetime.now(timezone.utc):
            record.used_at = datetime.now(timezone.utc)
            db.add(record)
            db.commit()
            return EmailCodeValidationResult(ok=False, reason="CODE_EXPIRED")
        if record.attempt_count >= cls.MAX_ATTEMPTS:
            record.used_at = datetime.now(timezone.utc)
            db.add(record)
            db.commit()
            return EmailCodeValidationResult(ok=False, reason="TOO_MANY_ATTEMPTS")
        if not secrets.compare_digest(record.code_hash, cls.hash_code(code)):
            record.attempt_count += 1
            if record.attempt_count >= cls.MAX_ATTEMPTS:
                record.used_at = datetime.now(timezone.utc)
            db.add(record)
            db.commit()
            return EmailCodeValidationResult(ok=False, reason="INVALID_CODE")

        user = db.query(User).filter(User.id == record.user_id).one_or_none()
        if user is None or user.email.lower() != normalized_email:
            return EmailCodeValidationResult(ok=False, reason="INVALID_USER")

        record.used_at = datetime.now(timezone.utc)
        db.add(record)
        db.commit()
        return EmailCodeValidationResult(ok=True, user=user)

    @classmethod
    def invalidate_active_codes(cls, db: Session, *, email: str, purpose: str) -> None:
        now = datetime.now(timezone.utc)
        active_codes = (
            db.query(AuthEmailCode)
            .filter(
                AuthEmailCode.email == email.lower().strip(),
                AuthEmailCode.purpose == purpose,
                AuthEmailCode.used_at.is_(None),
            )
            .all()
        )
        if not active_codes:
            return
        for record in active_codes:
            record.used_at = now
            db.add(record)
        db.commit()

    @classmethod
    def generate_code(cls) -> str:
        return f"{secrets.randbelow(10**cls.CODE_LENGTH):0{cls.CODE_LENGTH}d}"

    @classmethod
    def hash_code(cls, code: str) -> str:
        settings = get_settings()
        secret = settings.JWT_SECRET_KEY or "change-me-in-production"
        return hashlib.sha256(f"{secret}:{code}".encode("utf-8")).hexdigest()
