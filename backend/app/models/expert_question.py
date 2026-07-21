from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class ExpertQuestion(Base):
    """A user-submitted question to a verified expert (`ServiceListing.is_expert=True`).

    Lifecycle:
      pending  → user just asked
      answered → admin/expert posted a public answer
      rejected → moderator removed the question
    Public feed shows only `answered` rows under the expert profile.
    """

    __tablename__ = "expert_questions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    listing_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("service_listings.id", ondelete="CASCADE"), nullable=False, index=True
    )
    asked_by: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    asker_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    asker_language: Mapped[str | None] = mapped_column(String(10), nullable=True)

    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    answer_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    answered_by: Mapped[str | None] = mapped_column(String(36), nullable=True)

    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending", index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
