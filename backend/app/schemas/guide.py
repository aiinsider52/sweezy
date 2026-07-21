from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class GuideBase(BaseModel):
    title: str
    slug: str
    description: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    source_url: Optional[str] = None
    source_title: Optional[str] = None
    verified_at: Optional[datetime] = None
    is_published: bool = True
    status: Optional[str] = None
    version: int = 1


class GuideCreate(GuideBase):
    pass


class GuideUpdate(BaseModel):
    title: Optional[str] = None
    slug: Optional[str] = None
    description: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    source_url: Optional[str] = None
    source_title: Optional[str] = None
    verified_at: Optional[datetime] = None
    is_published: Optional[bool] = None
    status: Optional[str] = None
    version: Optional[int] = None


class GuideOut(GuideBase):
    model_config = ConfigDict(from_attributes=True)
    id: str
