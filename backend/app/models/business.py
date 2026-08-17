from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, JSON, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class BusinessProfile(Base):
    __tablename__ = "business_profiles"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    legal_name: Mapped[str | None] = mapped_column(String(180), nullable=True)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    category: Mapped[str] = mapped_column(String(40), default="other", nullable=False, index=True)
    canton: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    address: Mapped[str | None] = mapped_column(String(240), nullable=True)
    service_area: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    languages: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    cover_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    website: Mapped[str | None] = mapped_column(String(500), nullable=True)
    uid_number: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    delivery_modes: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    cancellation_policy: Mapped[str | None] = mapped_column(Text, nullable=True)
    payment_link: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    timezone: Mapped[str] = mapped_column(String(50), default="Europe/Zurich", nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="draft", nullable=False, index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_by: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    ai_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    ai_auto_reply: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ai_tone: Mapped[str] = mapped_column(String(30), default="friendly_professional", nullable=False)
    ai_business_facts: Mapped[str] = mapped_column(Text, default="", nullable=False)
    ai_instructions: Mapped[str] = mapped_column(Text, default="", nullable=False)
    ai_greeting: Mapped[str | None] = mapped_column(String(500), nullable=True)
    ai_faq: Mapped[list[dict]] = mapped_column(JSON, default=list, nullable=False)
    ai_handoff_topics: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    ai_allowed_languages: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class BusinessService(Base):
    __tablename__ = "business_services"
    __table_args__ = (Index("ix_business_services_owner_active", "business_user_id", "is_active"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    listing_id: Mapped[str | None] = mapped_column(ForeignKey("service_listings.id", ondelete="SET NULL"), nullable=True, unique=True)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    category: Mapped[str] = mapped_column(String(40), default="other", nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=60, nullable=False)
    price_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    price_to_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    currency: Mapped[str] = mapped_column(String(3), default="CHF", nullable=False)
    delivery_mode: Mapped[str] = mapped_column(String(20), default="onsite", nullable=False)
    buffer_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class BusinessAvailabilityRule(Base):
    __tablename__ = "business_availability_rules"
    __table_args__ = (
        UniqueConstraint("business_user_id", "weekday", "start_time", "end_time", name="uq_business_availability_window"),
        Index("ix_business_availability_owner_day", "business_user_id", "weekday"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    weekday: Mapped[int] = mapped_column(Integer, nullable=False)
    start_time: Mapped[str] = mapped_column(String(5), nullable=False)
    end_time: Mapped[str] = mapped_column(String(5), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class BusinessLead(Base):
    __tablename__ = "business_leads"
    __table_args__ = (
        UniqueConstraint("business_user_id", "conversation_id", name="uq_business_lead_conversation"),
        Index("ix_business_leads_pipeline", "business_user_id", "status", "updated_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    conversation_id: Mapped[str | None] = mapped_column(ForeignKey("chat_conversations.id", ondelete="SET NULL"), nullable=True)
    customer_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    service_id: Mapped[str | None] = mapped_column(ForeignKey("business_services.id", ondelete="SET NULL"), nullable=True)
    customer_name: Mapped[str] = mapped_column(String(120), nullable=False)
    customer_language: Mapped[str | None] = mapped_column(String(10), nullable=True)
    contact_value: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(30), default="new", nullable=False, index=True)
    source: Mapped[str] = mapped_column(String(30), default="marketplace", nullable=False)
    budget_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    desired_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notes: Mapped[str] = mapped_column(Text, default="", nullable=False)
    next_action: Mapped[str | None] = mapped_column(String(240), nullable=True)
    next_action_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    assignee_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class BusinessClient(Base):
    __tablename__ = "business_clients"
    __table_args__ = (
        UniqueConstraint("business_user_id", "customer_user_id", name="uq_business_client_user"),
        Index("ix_business_clients_owner_activity", "business_user_id", "last_activity_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    customer_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    language: Mapped[str | None] = mapped_column(String(10), nullable=True)
    notes: Mapped[str] = mapped_column(Text, default="", nullable=False)
    tags: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    booking_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_spend_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_activity_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class BusinessBooking(Base):
    __tablename__ = "business_bookings"
    __table_args__ = (Index("ix_business_bookings_calendar", "business_user_id", "starts_at", "status"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    client_id: Mapped[str | None] = mapped_column(ForeignKey("business_clients.id", ondelete="SET NULL"), nullable=True)
    lead_id: Mapped[str | None] = mapped_column(ForeignKey("business_leads.id", ondelete="SET NULL"), nullable=True)
    service_id: Mapped[str | None] = mapped_column(ForeignKey("business_services.id", ondelete="SET NULL"), nullable=True)
    customer_name: Mapped[str] = mapped_column(String(120), nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="requested", nullable=False, index=True)
    location: Mapped[str | None] = mapped_column(String(240), nullable=True)
    notes: Mapped[str] = mapped_column(Text, default="", nullable=False)
    price_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    currency: Mapped[str] = mapped_column(String(3), default="CHF", nullable=False)
    reminder_minutes: Mapped[int] = mapped_column(Integer, default=1440, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class BusinessQuickReply(Base):
    __tablename__ = "business_quick_replies"
    __table_args__ = (Index("ix_business_quick_replies_owner_order", "business_user_id", "sort_order"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(80), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    language: Mapped[str] = mapped_column(String(10), default="de", nullable=False)
    category: Mapped[str] = mapped_column(String(30), default="general", nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class BusinessTeamMember(Base):
    __tablename__ = "business_team_members"
    __table_args__ = (UniqueConstraint("business_user_id", "email", name="uq_business_team_email"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    member_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    role: Mapped[str] = mapped_column(String(20), default="staff", nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class BusinessDocument(Base):
    __tablename__ = "business_documents"
    __table_args__ = (Index("ix_business_documents_owner_created", "business_user_id", "created_at"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    business_user_id: Mapped[str] = mapped_column(ForeignKey("business_profiles.user_id", ondelete="CASCADE"), index=True)
    client_id: Mapped[str | None] = mapped_column(ForeignKey("business_clients.id", ondelete="SET NULL"), nullable=True)
    lead_id: Mapped[str | None] = mapped_column(ForeignKey("business_leads.id", ondelete="SET NULL"), nullable=True)
    document_type: Mapped[str] = mapped_column(String(20), default="quote", nullable=False)
    number: Mapped[str] = mapped_column(String(40), nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="draft", nullable=False)
    line_items: Mapped[list[dict]] = mapped_column(JSON, default=list, nullable=False)
    notes: Mapped[str] = mapped_column(Text, default="", nullable=False)
    total_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="CHF", nullable=False)
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
