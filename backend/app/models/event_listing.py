from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class EventListing(Base):
    __tablename__ = "event_listings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(String(2000), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    canton: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    city: Mapped[str] = mapped_column(String(120), nullable=False)
    venue_name: Mapped[str | None] = mapped_column(String(150), nullable=True)
    address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_free: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_private: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, index=True)
    price_info: Mapped[str | None] = mapped_column(String(100), nullable=True)
    contact_type: Mapped[str] = mapped_column(String(20), nullable=False)
    contact_value: Mapped[str] = mapped_column(String(255), nullable=False)
    organizer_name: Mapped[str] = mapped_column(String(100), nullable=False)
    author_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending", index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    report_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_moderated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class EventReport(Base):
    __tablename__ = "event_reports"
    __table_args__ = (UniqueConstraint("event_id", "reporter_id", name="uq_event_report_event_user"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    event_id: Mapped[str] = mapped_column(ForeignKey("event_listings.id", ondelete="CASCADE"), index=True)
    reporter_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reason: Mapped[str] = mapped_column(String(40), nullable=False)
    details: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="open", nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
