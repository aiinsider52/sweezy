from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, ForeignKey, JSON, DateTime, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class ServiceListing(Base):
    __tablename__ = "service_listings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    # "service" (default) or "item" — goods listings share this table to reuse
    # moderation, trust signals, photos and the admin pipeline.
    listing_type: Mapped[str] = mapped_column(String(20), nullable=False, default="service", index=True)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(String(1000), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    canton: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    price_info: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # Goods-specific fields (null for services)
    price_chf: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_free: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    condition: Mapped[str | None] = mapped_column(String(20), nullable=True)
    negotiable: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    contact_type: Mapped[str] = mapped_column(String(20), nullable=False)
    contact_value: Mapped[str] = mapped_column(String(255), nullable=False)
    image_urls: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    author_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    author_name: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending", index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ai_score_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    featured_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    trust_level: Mapped[str] = mapped_column(String(30), default="community", nullable=False, index=True)
    partner_label: Mapped[str | None] = mapped_column(String(80), nullable=True)
    moderation_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_expert: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    expert_specialty: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    expert_languages: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    response_time_hours: Mapped[int | None] = mapped_column(Integer, nullable=True)
    expert_bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    report_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_moderated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class MarketplaceReport(Base):
    __tablename__ = "marketplace_reports"
    __table_args__ = (UniqueConstraint("listing_id", "reporter_id", name="uq_marketplace_report_listing_user"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    listing_id: Mapped[str] = mapped_column(ForeignKey("service_listings.id", ondelete="CASCADE"), index=True)
    reporter_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reason: Mapped[str] = mapped_column(String(40), nullable=False)
    details: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="open", nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class MarketplaceBlock(Base):
    __tablename__ = "marketplace_blocks"
    __table_args__ = (UniqueConstraint("user_id", "blocked_author_id", name="uq_marketplace_block_user_author"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    blocked_author_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
