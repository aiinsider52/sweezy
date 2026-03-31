from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ServiceCategory(str, Enum):
    translation = "translation"
    documents = "documents"
    tutoring = "tutoring"
    it = "it"
    beauty = "beauty"
    cleaning = "cleaning"
    accounting = "accounting"
    legal = "legal"
    childcare = "childcare"
    moving = "moving"
    repair = "repair"
    other = "other"


class ContactType(str, Enum):
    telegram = "telegram"
    whatsapp = "whatsapp"
    email = "email"
    phone = "phone"


class ServiceListingCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    description: str = Field(..., min_length=10, max_length=1000)
    category: ServiceCategory
    canton: str = Field(..., min_length=2, max_length=10)
    price_info: Optional[str] = Field(None, max_length=100)
    contact_type: ContactType
    contact_value: str = Field(..., min_length=1, max_length=255)
    author_name: str = Field(..., min_length=1, max_length=100)
    image_urls: list[str] = Field(default_factory=list, max_length=6)


class ServiceListingUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=3, max_length=100)
    description: Optional[str] = Field(None, min_length=10, max_length=1000)
    price_info: Optional[str] = Field(None, max_length=100)
    image_urls: Optional[list[str]] = Field(None, max_length=6)


class ServiceListingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    description: str
    category: str
    canton: str
    price_info: Optional[str] = None
    contact_type: str
    image_urls: list[str] = Field(default_factory=list)
    author_id: Optional[str] = None
    author_name: str
    status: str
    rejection_reason: Optional[str] = None
    view_count: int
    created_at: datetime
    updated_at: datetime


class ServiceListingDetail(ServiceListingResponse):
    contact_value: str


class AdminServiceListingDetail(ServiceListingDetail):
    ai_score: Optional[int] = None
    ai_score_reason: Optional[str] = None


class ServiceListingPage(BaseModel):
    items: list[ServiceListingResponse]
    total: int
    page: int
    per_page: int
    pages: int
