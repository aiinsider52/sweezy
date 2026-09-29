from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

PLACE_SUGGESTION_CATEGORIES = {
    "community",
    "religious",
    "school",
    "language",
    "legal_aid",
    "social",
    "health",
    "food",
    "other",
}


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = " ".join(value.split())
    return normalized or None


class PlaceSuggestionCreate(BaseModel):
    name: str = Field(min_length=3, max_length=160)
    category: str
    street: str = Field(min_length=2, max_length=160)
    postal_code: str = Field(min_length=3, max_length=12)
    city: str = Field(min_length=2, max_length=80)
    country_code: str = Field(default="CH", min_length=2, max_length=2)
    subdivision_code: str | None = Field(default=None, max_length=10)
    website: str | None = Field(default=None, max_length=300)
    phone: str | None = Field(default=None, max_length=40)
    note: str = Field(min_length=10, max_length=600)

    @field_validator("name", "street", "postal_code", "city", "note")
    @classmethod
    def normalize_required(cls, value: str) -> str:
        cleaned = _clean(value)
        if not cleaned:
            raise ValueError("Field is empty")
        return cleaned

    @field_validator("website", "phone", "subdivision_code")
    @classmethod
    def normalize_optional(cls, value: str | None) -> str | None:
        return _clean(value)

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in PLACE_SUGGESTION_CATEGORIES:
            raise ValueError("Unsupported category")
        return normalized

    @field_validator("country_code")
    @classmethod
    def validate_country(cls, value: str) -> str:
        normalized = value.strip().upper()
        if normalized not in {"CH", "DE", "AT"}:
            raise ValueError("Unsupported country")
        return normalized

    @field_validator("website")
    @classmethod
    def validate_website(cls, value: str | None) -> str | None:
        if value and not value.lower().startswith(("http://", "https://")):
            return f"https://{value}"
        return value


class PlaceSuggestionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    category: str
    street: str
    postal_code: str
    city: str
    country_code: str
    subdivision_code: str | None = None
    website: str | None = None
    phone: str | None = None
    note: str
    status: str
    rejection_reason: str | None = None
    created_at: datetime


class CommunityPlaceResponse(BaseModel):
    """Public shape of an approved suggestion: no author, no internal notes."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    category: str
    street: str
    postal_code: str
    city: str
    country_code: str
    subdivision_code: str | None = None
    website: str | None = None
    phone: str | None = None
    latitude: float
    longitude: float
    reviewed_at: datetime | None = None


class PlaceSuggestionModeration(BaseModel):
    status: str
    rejection_reason: str | None = Field(default=None, max_length=300)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    name: str | None = Field(default=None, max_length=160)
    subdivision_code: str | None = Field(default=None, max_length=10)

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"approved", "rejected", "pending"}:
            raise ValueError("Unsupported status")
        return normalized
