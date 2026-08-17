from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


BusinessStatus = Literal["draft", "pending", "approved", "rejected", "suspended"]
LeadStatus = Literal["new", "replied", "qualifying", "quoted", "booked", "completed", "cancelled", "lost"]
BookingStatus = Literal["requested", "confirmed", "completed", "cancelled", "no_show"]


class BusinessProfileUpdate(BaseModel):
    display_name: str = Field(min_length=2, max_length=120)
    legal_name: str | None = Field(default=None, max_length=180)
    description: str = Field(default="", max_length=4000)
    category: str = Field(default="other", min_length=2, max_length=40)
    canton: str = Field(min_length=2, max_length=10)
    city: str = Field(min_length=2, max_length=100)
    address: str | None = Field(default=None, max_length=240)
    service_area: list[str] = Field(default_factory=list, max_length=26)
    languages: list[str] = Field(default_factory=list, max_length=12)
    logo_url: str | None = Field(default=None, max_length=1000)
    cover_url: str | None = Field(default=None, max_length=1000)
    phone: str | None = Field(default=None, max_length=40)
    email: str | None = Field(default=None, max_length=255)
    website: str | None = Field(default=None, max_length=500)
    uid_number: str | None = Field(default=None, max_length=40)
    delivery_modes: list[str] = Field(default_factory=list, max_length=4)
    cancellation_policy: str | None = Field(default=None, max_length=3000)
    payment_link: str | None = Field(default=None, max_length=1000)

    @field_validator("service_area", "languages", "delivery_modes")
    @classmethod
    def clean_list(cls, values: list[str]) -> list[str]:
        return list(dict.fromkeys(item.strip()[:40] for item in values if item.strip()))

    @field_validator("logo_url", "cover_url", "website", "payment_link")
    @classmethod
    def secure_url(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        normalized = value.strip()
        if normalized.startswith("https://"):
            return normalized
        if normalized.startswith(("http://localhost", "http://127.0.0.1")):
            return normalized
        raise ValueError("URL must use HTTPS")


class BusinessProfileResponse(BusinessProfileUpdate):
    model_config = ConfigDict(from_attributes=True)

    user_id: str
    status: BusinessStatus
    rejection_reason: str | None
    is_verified: bool
    submitted_at: datetime | None
    reviewed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class BusinessAISettingsUpdate(BaseModel):
    ai_enabled: bool = True
    ai_auto_reply: bool = False
    ai_tone: Literal["friendly_professional", "concise", "warm", "formal"] = "friendly_professional"
    ai_business_facts: str = Field(default="", max_length=8000)
    ai_instructions: str = Field(default="", max_length=5000)
    ai_greeting: str | None = Field(default=None, max_length=500)
    ai_faq: list[dict[str, str]] = Field(default_factory=list, max_length=30)
    ai_handoff_topics: list[str] = Field(default_factory=list, max_length=20)
    ai_allowed_languages: list[str] = Field(default_factory=list, max_length=12)

    @field_validator("ai_faq")
    @classmethod
    def clean_faq(cls, values: list[dict[str, str]]) -> list[dict[str, str]]:
        result: list[dict[str, str]] = []
        for item in values:
            question = str(item.get("question", "")).strip()[:300]
            answer = str(item.get("answer", "")).strip()[:1200]
            if question and answer:
                result.append({"question": question, "answer": answer})
        return result


class BusinessAISettingsResponse(BusinessAISettingsUpdate):
    pass


class BusinessServiceCreate(BaseModel):
    listing_id: str | None = Field(default=None, min_length=36, max_length=36)
    title: str = Field(min_length=2, max_length=120)
    description: str = Field(default="", max_length=4000)
    category: str = Field(default="other", max_length=40)
    duration_minutes: int = Field(default=60, ge=15, le=1440)
    price_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    price_to_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    currency: str = Field(default="CHF", min_length=3, max_length=3)
    delivery_mode: Literal["onsite", "remote", "mobile"] = "onsite"
    buffer_minutes: int = Field(default=0, ge=0, le=240)
    is_active: bool = True

    @model_validator(mode="after")
    def valid_range(self):
        if self.price_cents is not None and self.price_to_cents is not None and self.price_to_cents < self.price_cents:
            raise ValueError("price_to_cents must be greater than price_cents")
        return self


class BusinessServiceUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=4000)
    category: str | None = Field(default=None, max_length=40)
    duration_minutes: int | None = Field(default=None, ge=15, le=1440)
    price_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    price_to_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    delivery_mode: Literal["onsite", "remote", "mobile"] | None = None
    buffer_minutes: int | None = Field(default=None, ge=0, le=240)
    is_active: bool | None = None


class BusinessServiceResponse(BusinessServiceCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    business_user_id: str
    created_at: datetime
    updated_at: datetime


class AvailabilityRuleCreate(BaseModel):
    weekday: int = Field(ge=0, le=6)
    start_time: str = Field(pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d$")
    end_time: str = Field(pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d$")
    is_active: bool = True

    @model_validator(mode="after")
    def valid_window(self):
        if self.end_time <= self.start_time:
            raise ValueError("end_time must be after start_time")
        return self


class AvailabilityRuleResponse(AvailabilityRuleCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str


class BusinessLeadCreate(BaseModel):
    conversation_id: str | None = Field(default=None, min_length=36, max_length=36)
    customer_user_id: str | None = Field(default=None, min_length=36, max_length=36)
    service_id: str | None = Field(default=None, min_length=36, max_length=36)
    customer_name: str = Field(min_length=1, max_length=120)
    customer_language: str | None = Field(default=None, max_length=10)
    contact_value: str | None = Field(default=None, max_length=255)
    status: LeadStatus = "new"
    source: str = Field(default="manual", max_length=30)
    budget_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    desired_at: datetime | None = None
    notes: str = Field(default="", max_length=5000)
    next_action: str | None = Field(default=None, max_length=240)
    next_action_at: datetime | None = None
    assignee_name: str | None = Field(default=None, max_length=120)


class BusinessLeadUpdate(BaseModel):
    status: LeadStatus | None = None
    customer_language: str | None = Field(default=None, max_length=10)
    contact_value: str | None = Field(default=None, max_length=255)
    service_id: str | None = Field(default=None, min_length=36, max_length=36)
    budget_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    desired_at: datetime | None = None
    notes: str | None = Field(default=None, max_length=5000)
    next_action: str | None = Field(default=None, max_length=240)
    next_action_at: datetime | None = None
    assignee_name: str | None = Field(default=None, max_length=120)


class BusinessLeadResponse(BusinessLeadCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    business_user_id: str
    created_at: datetime
    updated_at: datetime


class BusinessClientCreate(BaseModel):
    customer_user_id: str | None = Field(default=None, min_length=36, max_length=36)
    display_name: str = Field(min_length=1, max_length=120)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=40)
    language: str | None = Field(default=None, max_length=10)
    notes: str = Field(default="", max_length=5000)
    tags: list[str] = Field(default_factory=list, max_length=20)


class BusinessClientUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=120)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=40)
    language: str | None = Field(default=None, max_length=10)
    notes: str | None = Field(default=None, max_length=5000)
    tags: list[str] | None = Field(default=None, max_length=20)


class BusinessClientResponse(BusinessClientCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    business_user_id: str
    booking_count: int
    completed_count: int
    total_spend_cents: int
    last_activity_at: datetime | None
    created_at: datetime
    updated_at: datetime


class BusinessBookingCreate(BaseModel):
    client_id: str | None = Field(default=None, min_length=36, max_length=36)
    lead_id: str | None = Field(default=None, min_length=36, max_length=36)
    service_id: str | None = Field(default=None, min_length=36, max_length=36)
    customer_name: str = Field(min_length=1, max_length=120)
    starts_at: datetime
    ends_at: datetime
    status: BookingStatus = "requested"
    location: str | None = Field(default=None, max_length=240)
    notes: str = Field(default="", max_length=5000)
    price_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    currency: str = Field(default="CHF", min_length=3, max_length=3)
    reminder_minutes: int = Field(default=1440, ge=0, le=43200)

    @model_validator(mode="after")
    def valid_dates(self):
        if self.ends_at <= self.starts_at:
            raise ValueError("ends_at must be after starts_at")
        return self


class BusinessBookingUpdate(BaseModel):
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    status: BookingStatus | None = None
    location: str | None = Field(default=None, max_length=240)
    notes: str | None = Field(default=None, max_length=5000)
    price_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    reminder_minutes: int | None = Field(default=None, ge=0, le=43200)


class BusinessBookingResponse(BusinessBookingCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    business_user_id: str
    created_at: datetime
    updated_at: datetime


class QuickReplyCreate(BaseModel):
    title: str = Field(min_length=1, max_length=80)
    body: str = Field(min_length=1, max_length=2000)
    language: str = Field(default="de", max_length=10)
    category: str = Field(default="general", max_length=30)
    sort_order: int = Field(default=0, ge=0, le=999)
    is_active: bool = True


class QuickReplyResponse(QuickReplyCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    created_at: datetime


class TeamMemberCreate(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    display_name: str = Field(min_length=1, max_length=120)
    role: Literal["manager", "staff", "viewer"] = "staff"


class TeamMemberResponse(TeamMemberCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    member_user_id: str | None
    status: str
    created_at: datetime


class BusinessWorkspaceResponse(BaseModel):
    owner_user_id: str
    display_name: str
    role: Literal["owner", "manager", "staff", "viewer"]
    profile_status: BusinessStatus
    is_verified: bool


class BusinessDocumentCreate(BaseModel):
    client_id: str | None = Field(default=None, min_length=36, max_length=36)
    lead_id: str | None = Field(default=None, min_length=36, max_length=36)
    document_type: Literal["quote", "confirmation", "invoice"] = "quote"
    title: str = Field(min_length=2, max_length=160)
    status: Literal["draft", "sent", "accepted", "paid", "cancelled"] = "draft"
    line_items: list[dict] = Field(default_factory=list, max_length=50)
    notes: str = Field(default="", max_length=5000)
    currency: str = Field(default="CHF", min_length=3, max_length=3)
    due_at: datetime | None = None


class BusinessDocumentResponse(BusinessDocumentCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    business_user_id: str
    number: str
    total_cents: int
    created_at: datetime
    updated_at: datetime


class PublicBusinessProfileResponse(BaseModel):
    user_id: str
    display_name: str
    description: str
    category: str
    canton: str
    city: str
    service_area: list[str]
    languages: list[str]
    logo_url: str | None
    cover_url: str | None
    website: str | None
    delivery_modes: list[str]
    cancellation_policy: str | None
    is_verified: bool
    services: list[BusinessServiceResponse] = Field(default_factory=list)
    average_rating: float | None = None
    review_count: int = 0


class PublicBookingSlot(BaseModel):
    starts_at: datetime
    ends_at: datetime


class PublicBookingCreate(BaseModel):
    service_id: str = Field(min_length=36, max_length=36)
    starts_at: datetime
    notes: str = Field(default="", max_length=2000)

    @field_validator("starts_at")
    @classmethod
    def timezone_required(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            raise ValueError("starts_at must include timezone")
        return value


class CustomerBookingResponse(BusinessBookingResponse):
    business_name: str
    service_title: str | None = None


class AIReceptionistMessage(BaseModel):
    role: Literal["customer", "business"]
    content: str = Field(min_length=1, max_length=3000)


class AIReceptionistDraftRequest(BaseModel):
    conversation_id: str | None = Field(default=None, min_length=36, max_length=36)
    customer_name: str | None = Field(default=None, max_length=120)
    customer_language: str | None = Field(default=None, max_length=10)
    messages: list[AIReceptionistMessage] = Field(min_length=1, max_length=20)


class AIReceptionistDraftResponse(BaseModel):
    reply: str
    detected_language: str
    lead_summary: str
    suggested_status: LeadStatus
    missing_information: list[str] = Field(default_factory=list)
    should_handoff: bool
    handoff_reason: str | None = None
    generated_by_ai: bool


class BusinessDashboardResponse(BaseModel):
    profile: BusinessProfileResponse
    total_listings: int
    active_listings: int
    total_views: int
    inquiries: int
    open_leads: int
    bookings_today: int
    upcoming_bookings: int
    clients_total: int
    average_rating: float | None
    review_count: int
    response_rate_percent: int
    conversion_percent: int
    publication_limit: int = 20
    leads: list[BusinessLeadResponse] = Field(default_factory=list)
    bookings: list[BusinessBookingResponse] = Field(default_factory=list)
    clients: list[BusinessClientResponse] = Field(default_factory=list)
    quick_replies: list[QuickReplyResponse] = Field(default_factory=list)


class AdminBusinessProfileResponse(BusinessProfileResponse):
    owner_email: str
    subscription_status: str
    subscription_expire_at: datetime | None
    ai_enabled: bool
    ai_auto_reply: bool
    services_count: int = 0
    leads_count: int = 0
    bookings_count: int = 0
    clients_count: int = 0
    documents_count: int = 0
    team_members_count: int = 0


class AdminBusinessReview(BaseModel):
    decision: Literal["approve", "reject", "suspend"]
    comment: str | None = Field(default=None, max_length=2000)
