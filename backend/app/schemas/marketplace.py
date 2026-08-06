from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator


class ListingType(str, Enum):
    service = "service"
    item = "item"


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


class ItemCategory(str, Enum):
    furniture = "furniture"
    electronics = "electronics"
    kids = "kids"
    clothing = "clothing"
    home = "home"
    sports = "sports"
    books = "books"
    free = "free"
    other = "other"


class ItemCondition(str, Enum):
    new = "new"
    like_new = "like_new"
    used = "used"


class ContactType(str, Enum):
    telegram = "telegram"
    whatsapp = "whatsapp"
    email = "email"
    phone = "phone"


_VALID_CATEGORIES: dict[ListingType, set[str]] = {
    ListingType.service: {c.value for c in ServiceCategory},
    ListingType.item: {c.value for c in ItemCategory},
}


class ServiceListingCreate(BaseModel):
    listing_type: ListingType = ListingType.service
    title: str = Field(..., min_length=3, max_length=100)
    description: str = Field(..., min_length=10, max_length=1000)
    category: str = Field(..., min_length=2, max_length=30)
    canton: str = Field(..., min_length=2, max_length=10)
    price_info: Optional[str] = Field(None, max_length=100)
    price_chf: Optional[int] = Field(None, ge=0, le=1_000_000)
    is_free: bool = False
    condition: Optional[ItemCondition] = None
    negotiable: bool = False
    contact_type: ContactType
    contact_value: str = Field(..., min_length=1, max_length=255)
    author_name: str = Field(..., min_length=1, max_length=100)
    image_urls: list[str] = Field(default_factory=list, max_length=6)

    @model_validator(mode="after")
    def _validate_by_type(self) -> "ServiceListingCreate":
        if self.category not in _VALID_CATEGORIES[self.listing_type]:
            raise ValueError(f"Invalid category '{self.category}' for listing type '{self.listing_type.value}'")
        if self.listing_type == ListingType.item:
            if not self.is_free and self.price_chf is None:
                raise ValueError("Item listings require price_chf or is_free=true")
            if self.is_free:
                self.price_chf = None
        return self


class ServiceListingUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=3, max_length=100)
    description: Optional[str] = Field(None, min_length=10, max_length=1000)
    price_info: Optional[str] = Field(None, max_length=100)
    price_chf: Optional[int] = Field(None, ge=0, le=1_000_000)
    is_free: Optional[bool] = None
    condition: Optional[ItemCondition] = None
    negotiable: Optional[bool] = None
    image_urls: Optional[list[str]] = Field(None, max_length=6)


class ServiceListingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    listing_type: str = "service"
    title: str
    description: str
    category: str
    canton: str
    price_info: Optional[str] = None
    price_chf: Optional[int] = None
    is_free: bool = False
    condition: Optional[str] = None
    negotiable: bool = False
    contact_type: str
    image_urls: list[str] = Field(default_factory=list)
    author_id: Optional[str] = None
    author_name: str
    status: str
    rejection_reason: Optional[str] = None
    is_verified: bool = False
    is_featured: bool = False
    trust_level: str = "community"
    partner_label: Optional[str] = None
    is_expert: bool = False
    expert_specialty: Optional[str] = None
    expert_languages: list[str] = Field(default_factory=list)
    response_time_hours: Optional[int] = None
    expert_bio: Optional[str] = None
    view_count: int
    report_count: int = 0
    last_moderated_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class ServiceListingDetail(ServiceListingResponse):
    contact_value: str


class AdminServiceListingDetail(ServiceListingDetail):
    ai_score: Optional[int] = None
    ai_score_reason: Optional[str] = None
    moderation_notes: Optional[str] = None


class ServiceListingPage(BaseModel):
    items: list[ServiceListingResponse]
    total: int
    page: int
    per_page: int
    pages: int


class MarketplaceReportCreate(BaseModel):
    reason: str = Field(..., min_length=2, max_length=40)
    details: Optional[str] = Field(None, max_length=500)


class MarketplaceSafetyResponse(BaseModel):
    ok: bool = True
    message: str


class PublicProfileListing(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    listing_type: str
    title: str
    category: str
    canton: str
    price_info: Optional[str] = None
    price_chf: Optional[int] = None
    is_free: bool = False
    image_urls: list[str] = Field(default_factory=list)
    is_verified: bool = False


class PublicUserProfileResponse(BaseModel):
    user_id: str
    display_name: str
    initials: str
    avatar_url: Optional[str] = None
    registered_month: str
    is_verified: bool
    trust_badges: list[str] = Field(default_factory=list)
    average_rating: Optional[float] = None
    review_count: int = 0
    active_listings: list[PublicProfileListing] = Field(default_factory=list)
    viewer_has_blocked: bool = False
