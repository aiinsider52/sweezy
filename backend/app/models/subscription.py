from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, String, DateTime, Integer, UniqueConstraint, func, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..core.database import Base


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    stripe_customer_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    stripe_subscription_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    provider: Mapped[str] = mapped_column(String(24), default="stripe", nullable=False, index=True)
    product_id: Mapped[str | None] = mapped_column(String(160), nullable=True)
    original_transaction_id: Mapped[str | None] = mapped_column(String(160), nullable=True, unique=True, index=True)
    latest_transaction_id: Mapped[str | None] = mapped_column(String(160), nullable=True, unique=True, index=True)
    app_account_token: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    environment: Mapped[str | None] = mapped_column(String(24), nullable=True)
    auto_renew_enabled: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    revocation_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    plan: Mapped[str | None] = mapped_column(String(32), nullable=True)  # monthly|yearly
    status: Mapped[str] = mapped_column(String(24), default="free")  # free|trial|active|canceled
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User", backref="subscription_rel", lazy="joined")


class SubscriptionEvent(Base):
    __tablename__ = "subscription_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"), index=True)
    provider: Mapped[str] = mapped_column(String(24), default="stripe", nullable=False)
    external_event_id: Mapped[str | None] = mapped_column(String(160), nullable=True, unique=True, index=True)
    type: Mapped[str] = mapped_column(String(80))
    payload: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class PremiumUsage(Base):
    __tablename__ = "premium_usage"
    __table_args__ = (UniqueConstraint("user_id", "feature", name="uq_premium_usage_user_feature"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    feature: Mapped[str] = mapped_column(String(80), nullable=False)
    free_uses: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

