from __future__ import annotations

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class NewsBase(BaseModel):
    title: str = Field(..., max_length=300)
    summary: str = ""
    content: Optional[str] = None
    # Allow non-ASCII paths and relative URLs to pass through (validated client-side)
    url: str
    source: str = "Sweezy"
    language: str = "uk"
    status: str = Field(default="published", description="draft|published|archived")
    published_at: datetime
    # Can be absolute (http...) or relative (/media/...)
    image_url: Optional[str] = None
    import_source: str = "manual"
    import_reference_id: Optional[str] = None


class NewsCreate(NewsBase):
    pass


class NewsUpdate(BaseModel):
    title: Optional[str] = None
    summary: Optional[str] = None
    content: Optional[str] = None
    url: Optional[str] = None
    source: Optional[str] = None
    language: Optional[str] = None
    status: Optional[str] = None
    published_at: Optional[datetime] = None
    image_url: Optional[str] = None
    import_source: Optional[str] = None
    import_reference_id: Optional[str] = None


class NewsOut(NewsBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    updated_at: datetime
