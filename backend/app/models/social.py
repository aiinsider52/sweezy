from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, JSON, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class SocialProfile(Base):
    __tablename__ = "social_profiles"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    canton: Mapped[str] = mapped_column(String(2), nullable=False, index=True)
    city: Mapped[str] = mapped_column(String(80), nullable=False)
    bio: Mapped[str] = mapped_column(String(600), nullable=False)
    interests: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    languages: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    meetup_formats: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    is_visible: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    open_to_friends: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    guidelines_accepted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class FriendConnection(Base):
    __tablename__ = "friend_connections"
    __table_args__ = (
        UniqueConstraint("pair_key", name="uq_friend_connection_pair"),
        Index("ix_friend_connections_target_status", "target_id", "status", "created_at"),
        Index("ix_friend_connections_requester_status", "requester_id", "status", "created_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    pair_key: Mapped[str] = mapped_column(String(73), nullable=False)
    requester_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    context_event_id: Mapped[str | None] = mapped_column(ForeignKey("event_listings.id", ondelete="SET NULL"), nullable=True)
    message: Mapped[str | None] = mapped_column(String(500), nullable=True)
    shared_interests: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False, index=True)
    conversation_id: Mapped[str | None] = mapped_column(ForeignKey("chat_conversations.id", ondelete="SET NULL"), nullable=True, index=True)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class EventAttendance(Base):
    __tablename__ = "event_attendance"
    __table_args__ = (UniqueConstraint("event_id", "user_id", name="uq_event_attendance_user"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    event_id: Mapped[str] = mapped_column(ForeignKey("event_listings.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("social_profiles.user_id", ondelete="CASCADE"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    visible_to_attendees: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class SocialProfileReport(Base):
    __tablename__ = "social_profile_reports"
    __table_args__ = (UniqueConstraint("profile_user_id", "reporter_id", name="uq_social_profile_reporter"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    profile_user_id: Mapped[str] = mapped_column(ForeignKey("social_profiles.user_id", ondelete="CASCADE"), nullable=False, index=True)
    reporter_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    reason: Mapped[str] = mapped_column(String(40), nullable=False)
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="open", nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
