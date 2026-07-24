from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Integer, JSON, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class SwissMoment(Base):
    """Time-sensitive Swiss "moment" (KK switching, tax season, school registration, ...).

    Surfaced on the Home screen ("Aktualno") and used to schedule local reminders and
    cross-link to checklists/calculators in the iOS app. Audience is filtered by the
    `audience_filters` JSON object (canton/permit/min_tenure_months/has_children/life_events).
    """

    __tablename__ = "swiss_moments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    key: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    description_md: Mapped[str] = mapped_column(Text, nullable=False, default="")

    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    recurrence: Mapped[str] = mapped_column(String(16), nullable=False, default="yearly")

    audience_filters: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    cta_kind: Mapped[str] = mapped_column(String(20), nullable=False, default="link")
    cta_payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)

    priority: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
