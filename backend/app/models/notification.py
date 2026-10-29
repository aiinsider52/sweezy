from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class NotificationPreference(Base):
    """Per-user switches for engagement pushes, plus the language and timezone they are written for."""

    __tablename__ = "notification_preferences"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    locale: Mapped[str] = mapped_column(String(5), default="uk", nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), default="Europe/Zurich", nullable=False)
    social_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    events_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    marketplace_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Bookkeeping for the periodic jobs, so each digest goes out once per window.
    likes_digest_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    events_checked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class MarketplaceWatch(Base):
    """A saved listing the user wants to hear about when its price drops."""

    __tablename__ = "marketplace_watches"
    __table_args__ = (UniqueConstraint("user_id", "listing_id", name="uq_marketplace_watch_user_listing"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    listing_id: Mapped[str] = mapped_column(ForeignKey("service_listings.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class MarketplaceFollow(Base):
    """New approved listings in a region (optionally one category) are announced to followers."""

    __tablename__ = "marketplace_follows"
    __table_args__ = (
        UniqueConstraint("user_id", "country_code", "subdivision_code", "category", name="uq_marketplace_follow"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    subdivision_code: Mapped[str] = mapped_column(String(10), nullable=False)
    # Empty string means "any category"; NULL would defeat the unique constraint.
    category: Mapped[str] = mapped_column(String(30), default="", nullable=False)
    last_notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

