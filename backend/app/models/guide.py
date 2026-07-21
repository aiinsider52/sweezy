from __future__ import annotations

from datetime import datetime
from typing import Optional
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class Guide(Base):
    __tablename__ = "guides"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    description: Mapped[Optional[str]] = mapped_column(String(500))
    content: Mapped[Optional[str]] = mapped_column(Text)
    category: Mapped[Optional[str]] = mapped_column(String(100))
    image_url: Mapped[Optional[str]] = mapped_column(String(500))
    source_url: Mapped[Optional[str]] = mapped_column(String(1000))
    source_title: Mapped[Optional[str]] = mapped_column(String(255))
    verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    is_published: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="published", nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

