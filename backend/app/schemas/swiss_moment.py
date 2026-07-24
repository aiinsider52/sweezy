from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class MomentRecurrence(str, Enum):
    once = "once"
    yearly = "yearly"
    quarterly = "quarterly"


class MomentCtaKind(str, Enum):
    link = "link"
    checklist = "checklist"
    calculator = "calculator"
    deeplink = "deeplink"


class AudienceFilters(BaseModel):
    """All fields are optional. An empty filter matches every user."""

    cantons: list[str] = Field(default_factory=list)
    permits: list[str] = Field(default_factory=list)
    min_tenure_months: Optional[int] = None
    max_tenure_months: Optional[int] = None
    has_children: Optional[bool] = None
    life_events: list[str] = Field(default_factory=list)


class SwissMomentBase(BaseModel):
    key: str = Field(..., min_length=2, max_length=64)
    title: str = Field(..., min_length=2, max_length=160)
    description_md: str = ""
    starts_at: datetime
    ends_at: datetime
    recurrence: MomentRecurrence = MomentRecurrence.yearly
    audience_filters: AudienceFilters = Field(default_factory=AudienceFilters)
    cta_kind: MomentCtaKind = MomentCtaKind.link
    cta_payload: dict[str, Any] = Field(default_factory=dict)
    priority: int = 0
    is_active: bool = True


class SwissMomentCreate(SwissMomentBase):
    pass


class SwissMomentUpdate(BaseModel):
    title: Optional[str] = None
    description_md: Optional[str] = None
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None
    recurrence: Optional[MomentRecurrence] = None
    audience_filters: Optional[AudienceFilters] = None
    cta_kind: Optional[MomentCtaKind] = None
    cta_payload: Optional[dict[str, Any]] = None
    priority: Optional[int] = None
    is_active: Optional[bool] = None


class SwissMomentResponse(SwissMomentBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    updated_at: datetime
