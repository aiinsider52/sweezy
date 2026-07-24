from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class ChecklistBase(BaseModel):
    title: str
    description: Optional[str] = None
    items: List[str] = []
    is_published: bool = True
    status: Optional[str] = None
    source_url: Optional[str] = None
    source_title: Optional[str] = None
    verified_at: Optional[datetime] = None


class ChecklistCreate(ChecklistBase):
    pass


class ChecklistUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    items: Optional[List[str]] = None
    is_published: Optional[bool] = None
    status: Optional[str] = None
    source_url: Optional[str] = None
    source_title: Optional[str] = None
    verified_at: Optional[datetime] = None


class ChecklistOut(ChecklistBase):
    model_config = ConfigDict(from_attributes=True)
    id: str
