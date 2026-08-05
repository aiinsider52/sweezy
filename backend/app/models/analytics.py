from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, JSON, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class PaywallEvent(Base):
    __tablename__ = "paywall_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)  # view|cta_click|purchase_start|dismiss
    context: Mapped[str | None] = mapped_column(String(255), nullable=True)  # e.g., favorites_limit, ai_locked
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class AnalyticsSession(Base):
    __tablename__ = "analytics_sessions"
    __table_args__ = (
        UniqueConstraint("client_session_id", name="uq_analytics_sessions_client_session"),
        Index("ix_analytics_sessions_last_seen", "last_seen_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    client_session_id: Mapped[str] = mapped_column(String(64), nullable=False)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    guest_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    platform: Mapped[str] = mapped_column(String(24), nullable=False, default="ios")
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    event_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    consent_granted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class AnalyticsEvent(Base):
    __tablename__ = "analytics_events"
    __table_args__ = (
        Index("ix_analytics_events_occurred_type", "occurred_at", "event_type"),
        Index("ix_analytics_events_actor_time", "user_id", "guest_id", "occurred_at"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    session_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("analytics_sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    guest_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    level: Mapped[str] = mapped_column(String(10), nullable=False, default="info")
    source: Mapped[str] = mapped_column(String(64), nullable=False)
    event_type: Mapped[str] = mapped_column(String(96), nullable=False, index=True)
    message: Mapped[str | None] = mapped_column(String(500), nullable=True)
    properties: Mapped[dict[str, str]] = mapped_column(JSON, nullable=False, default=dict)
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

