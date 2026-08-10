from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

Interest = Literal["hiking", "sports", "books", "music", "art", "food", "travel", "languages", "technology", "business", "family", "photography", "gaming", "wellness", "volunteering"]
MeetupFormat = Literal["coffee", "walk", "activity", "event", "online", "family"]


class SocialProfileUpsert(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    display_name: str = Field(min_length=2, max_length=100)
    canton: str = Field(min_length=2, max_length=2)
    city: str = Field(min_length=2, max_length=80)
    bio: str = Field(min_length=30, max_length=600)
    interests: list[Interest] = Field(min_length=2, max_length=10)
    languages: list[str] = Field(min_length=1, max_length=6)
    meetup_formats: list[MeetupFormat] = Field(min_length=1, max_length=5)
    avatar_url: str | None = Field(default=None, max_length=1000)
    is_visible: bool = True
    open_to_friends: bool = True
    guidelines_accepted: bool

    @field_validator("canton")
    @classmethod
    def canton_code(cls, value: str) -> str:
        value = value.upper()
        if not value.isalpha(): raise ValueError("Invalid canton")
        return value

    @field_validator("languages")
    @classmethod
    def clean_languages(cls, values: list[str]) -> list[str]:
        return list(dict.fromkeys(v.strip().upper()[:10] for v in values if v.strip()))

    @field_validator("avatar_url")
    @classmethod
    def secure_avatar(cls, value: str | None) -> str | None:
        if not value or not value.strip(): return None
        if not value.strip().startswith("https://"): raise ValueError("Avatar URL must use HTTPS")
        return value.strip()


class SocialProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user_id: str
    display_name: str
    canton: str
    city: str
    bio: str
    interests: list[str]
    languages: list[str]
    meetup_formats: list[str]
    avatar_url: str | None
    is_visible: bool
    open_to_friends: bool
    is_verified: bool
    match_score: int = 0
    shared_interests: list[str] = []
    connection_state: str = "none"
    connection_id: str | None = None
    conversation_id: str | None = None
    context_event_id: str | None = None
    created_at: datetime
    updated_at: datetime


class SocialProfilePage(BaseModel):
    items: list[SocialProfileResponse]
    total: int
    page: int
    per_page: int
    pages: int


class FriendRequestCreate(BaseModel):
    message: str | None = Field(default=None, max_length=500)
    event_id: str | None = Field(default=None, max_length=36)


class FriendDecision(BaseModel):
    status: Literal["accepted", "declined"]


class FriendConnectionResponse(BaseModel):
    id: str
    direction: Literal["incoming", "outgoing"]
    status: str
    message: str | None
    context_event_id: str | None
    conversation_id: str | None
    shared_interests: list[str]
    other_profile: SocialProfileResponse
    created_at: datetime
    updated_at: datetime


class AttendanceUpsert(BaseModel):
    status: Literal["interested", "going"]
    visible_to_attendees: bool = True


class AttendanceResponse(BaseModel):
    event_id: str
    status: str
    visible_to_attendees: bool


class SocialEventResponse(BaseModel):
    event_id: str
    title: str
    category: str
    canton: str
    city: str
    starts_at: datetime
    is_free: bool
    attendee_count: int
    my_status: str | None = None


class SocialReportCreate(BaseModel):
    reason: Literal["fake", "spam", "harassment", "unsafe", "other"]
    details: str | None = Field(default=None, max_length=500)


class SocialActionResponse(BaseModel):
    ok: bool = True
    message: str
