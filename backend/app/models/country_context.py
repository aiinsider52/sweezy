from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, String, UniqueConstraint, func, text
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class UserCountryContext(Base):
    __tablename__ = "user_country_contexts"
    __table_args__ = (
        UniqueConstraint("user_id", "country_code", name="uq_user_country_context_country"),
        Index("ix_user_country_context_active", "user_id", "is_active"),
        Index(
            "uq_user_country_context_active",
            "user_id",
            unique=True,
            sqlite_where=text("is_active = 1"),
            postgresql_where=text("is_active"),
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False, default="CH", index=True)
    subdivision_code: Mapped[str | None] = mapped_column(String(10), nullable=True, index=True)
    city: Mapped[str | None] = mapped_column(String(120), nullable=True)
    residence_status: Mapped[str | None] = mapped_column(String(40), nullable=True)
    preferred_language: Mapped[str] = mapped_column(String(10), nullable=False, default="uk")
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False, default="CHF")
    timezone: Mapped[str] = mapped_column(String(50), nullable=False, default="Europe/Zurich")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
