from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from ..core.countries import normalize_country_code, normalize_subdivision_code


NetworkRole = Literal["founder", "freelancer", "specialist", "investor", "mentor"]
ConnectionGoal = Literal["clients", "partners", "cofounder", "hiring", "investing", "mentoring", "events"]


class ProfessionalProfileUpsert(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    display_name: str = Field(min_length=2, max_length=100)
    headline: str = Field(min_length=3, max_length=140)
    company_name: str | None = Field(default=None, max_length=120)
    role: NetworkRole
    industry: str = Field(min_length=2, max_length=60)
    canton: str | None = Field(default=None, min_length=1, max_length=10)
    country_code: str = Field(default="CH", min_length=2, max_length=2)
    subdivision_code: str | None = Field(default=None, min_length=1, max_length=10)
    city: str = Field(min_length=2, max_length=80)
    bio: str = Field(min_length=30, max_length=800)
    skills: list[str] = Field(default_factory=list, max_length=12)
    languages: list[str] = Field(default_factory=list, min_length=1, max_length=6)
    goals: list[ConnectionGoal] = Field(default_factory=list, min_length=1, max_length=5)
    avatar_url: str | None = Field(default=None, max_length=1000)
    website_url: str | None = Field(default=None, max_length=1000)
    is_visible: bool = True
    open_to_connections: bool = True

    @model_validator(mode="after")
    def normalize_scope(self):
        self.country_code = normalize_country_code(self.country_code)
        self.subdivision_code = normalize_subdivision_code(
            self.country_code, self.subdivision_code or self.canton
        )
        if self.subdivision_code is None:
            raise ValueError("subdivision_code is required")
        self.canton = self.subdivision_code
        return self

    @field_validator("skills", "languages")
    @classmethod
    def normalize_lists(cls, values: list[str]) -> list[str]:
        result: list[str] = []
        seen: set[str] = set()
        for raw in values:
            value = raw.strip()[:50]
            key = value.casefold()
            if value and key not in seen:
                seen.add(key)
                result.append(value)
        return result

    @field_validator("avatar_url", "website_url")
    @classmethod
    def validate_public_urls(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        value = value.strip()
        if not value.startswith("https://"):
            raise ValueError("Public URLs must use HTTPS")
        return value


class ProfessionalProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: str
    display_name: str
    headline: str
    company_name: str | None
    role: str
    industry: str
    canton: str
    country_code: str = "CH"
    subdivision_code: str
    city: str
    bio: str
    skills: list[str]
    languages: list[str]
    goals: list[str]
    avatar_url: str | None
    website_url: str | None
    is_visible: bool
    is_verified: bool
    is_featured: bool
    open_to_connections: bool
    moderation_status: str
    moderation_reason: str | None = None
    connection_state: str = "none"
    connection_id: str | None = None
    conversation_id: str | None = None
    created_at: datetime
    updated_at: datetime


class ProfessionalProfilePage(BaseModel):
    items: list[ProfessionalProfileResponse]
    total: int
    page: int
    per_page: int
    pages: int


class ConnectionCreate(BaseModel):
    message: str | None = Field(default=None, max_length=500)


class ConnectionDecision(BaseModel):
    status: Literal["accepted", "declined"]


class ProfessionalConnectionResponse(BaseModel):
    id: str
    direction: Literal["incoming", "outgoing"]
    status: str
    message: str | None
    conversation_id: str | None
    other_profile: ProfessionalProfileResponse
    created_at: datetime
    updated_at: datetime


class ProfileReportCreate(BaseModel):
    reason: Literal["fake", "spam", "harassment", "unsafe", "other"]
    details: str | None = Field(default=None, max_length=500)


class NetworkActionResponse(BaseModel):
    ok: bool = True
    message: str
