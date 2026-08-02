from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class DiscoveryReviewUpsert(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(min_length=3, max_length=1000)

    @field_validator("comment")
    @classmethod
    def normalize_comment(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 3:
            raise ValueError("Comment is too short")
        return normalized


class DiscoveryReviewReportCreate(BaseModel):
    reason: str = Field(min_length=3, max_length=40)

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, value: str) -> str:
        allowed = {"spam", "abuse", "privacy", "misinformation", "other"}
        normalized = value.strip().lower()
        if normalized not in allowed:
            raise ValueError("Unsupported report reason")
        return normalized


class DiscoveryReviewResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    place_id: str
    rating: int
    comment: str
    author_label: str
    created_at: datetime
    updated_at: datetime
    is_mine: bool = False


class DiscoveryReviewPage(BaseModel):
    average_rating: float
    review_count: int
    items: list[DiscoveryReviewResponse]
    my_review: DiscoveryReviewResponse | None = None


class DiscoveryRatingSummary(BaseModel):
    place_id: str
    average_rating: float
    review_count: int


class DiscoveryReportResponse(BaseModel):
    status: str


class DiscoveryReviewModerationUpdate(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        if value not in {"published", "hidden"}:
            raise ValueError("Unsupported status")
        return value
