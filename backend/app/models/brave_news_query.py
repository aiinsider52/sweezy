from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class BraveNewsQuery(Base):
    __tablename__ = "brave_news_queries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    query: Mapped[str] = mapped_column(String(300), nullable=False)
    language: Mapped[str] = mapped_column(String(8), nullable=False, default="uk")
    country: Mapped[Optional[str]] = mapped_column(String(8), nullable=True)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="published")
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    max_results: Mapped[int] = mapped_column(Integer, nullable=False, default=8)
    freshness_days: Mapped[int] = mapped_column(Integer, nullable=False, default=7)
    last_imported_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), nullable=False, default=datetime.utcnow)
