from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, Float, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class PlaceSuggestion(Base):
    """A place a user proposes for the map. Nothing is public until an admin approves it."""

    __tablename__ = "place_suggestions"
    __table_args__ = (
        CheckConstraint("status IN ('pending', 'approved', 'rejected')", name="ck_place_suggestion_status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    country_code: Mapped[str] = mapped_column(String(2), nullable=False, default="CH", index=True)
    subdivision_code: Mapped[str | None] = mapped_column(String(10), nullable=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    street: Mapped[str] = mapped_column(String(160), nullable=False)
    postal_code: Mapped[str] = mapped_column(String(12), nullable=False)
    city: Mapped[str] = mapped_column(String(80), nullable=False)
    website: Mapped[str | None] = mapped_column(String(300), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    note: Mapped[str] = mapped_column(String(600), nullable=False)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending", index=True)
    rejection_reason: Mapped[str | None] = mapped_column(String(300), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
