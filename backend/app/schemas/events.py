from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class EventCategory(str, Enum):
    community = "community"
    kids = "kids"
    education = "education"
    career = "career"
    legal = "legal"
    health = "health"
    language = "language"
    culture = "culture"
    sports = "sports"
    other = "other"


class EventContactType(str, Enum):
    telegram = "telegram"
    whatsapp = "whatsapp"
    email = "email"
    phone = "phone"


class EventListingCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=120)
    description: str = Field(..., min_length=10, max_length=2000)
    category: EventCategory
    canton: str = Field(..., min_length=2, max_length=10)
    city: str = Field(..., min_length=1, max_length=120)
    venue_name: Optional[str] = Field(None, max_length=150)
    address: Optional[str] = Field(None, max_length=255)
    starts_at: datetime
    ends_at: Optional[datetime] = None
    is_free: bool = True
    price_info: Optional[str] = Field(None, max_length=100)
    contact_type: EventContactType
    contact_value: str = Field(..., min_length=1, max_length=255)
    organizer_name: str = Field(..., min_length=1, max_length=100)


class EventListingUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=3, max_length=120)
    description: Optional[str] = Field(None, min_length=10, max_length=2000)
    venue_name: Optional[str] = Field(None, max_length=150)
    address: Optional[str] = Field(None, max_length=255)
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None
    is_free: Optional[bool] = None
    price_info: Optional[str] = Field(None, max_length=100)


class EventListingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    description: str
    category: str
    canton: str
    city: str
    venue_name: Optional[str] = None
    address: Optional[str] = None
    starts_at: datetime
    ends_at: Optional[datetime] = None
    is_free: bool
    price_info: Optional[str] = None
    contact_type: str
    organizer_name: str
    author_id: Optional[str] = None
    status: str
    rejection_reason: Optional[str] = None
    view_count: int
    is_verified: bool = False
    report_count: int = 0
    last_moderated_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class EventListingDetail(EventListingResponse):
    contact_value: str


class EventListingPage(BaseModel):
    items: list[EventListingResponse]
    total: int
    page: int
    per_page: int
    pages: int


class EventReportCreate(BaseModel):
    reason: str = Field(..., min_length=2, max_length=40)
    details: Optional[str] = Field(None, max_length=500)


class EventSafetyResponse(BaseModel):
    ok: bool = True
    message: str
