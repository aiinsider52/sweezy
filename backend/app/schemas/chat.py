from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ConversationCreate(BaseModel):
    listing_id: str = Field(min_length=36, max_length=36)


class ChatMessageCreate(BaseModel):
    client_message_id: str = Field(min_length=8, max_length=64)
    body: str = Field(min_length=1, max_length=2000)

    @field_validator("body")
    @classmethod
    def normalize_body(cls, value: str) -> str:
        value = "\n".join(line.rstrip() for line in value.strip().splitlines())
        if not value:
            raise ValueError("Message cannot be empty")
        return value


class ChatMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    conversation_id: str
    sender_id: str
    client_message_id: str
    kind: str
    body: str
    created_at: datetime
    delivered_at: datetime | None = None
    read_at: datetime | None = None
    edited_at: datetime | None = None
    deleted_at: datetime | None = None


class ConversationResponse(BaseModel):
    id: str
    listing_id: str | None
    job_id: str | None = None
    network_profile_id: str | None = None
    social_profile_id: str | None = None
    listing_type: str
    listing_title: str
    listing_image_url: str | None
    listing_price: str | None
    listing_status: str
    other_user_id: str
    other_user_name: str
    is_seller: bool
    status: str
    last_message_preview: str | None
    last_message_sender_id: str | None
    last_message_at: datetime | None
    unread_count: int
    muted: bool
    archived: bool
    created_at: datetime


class ConversationPage(BaseModel):
    items: list[ConversationResponse]
    next_cursor: str | None = None


class MessagePage(BaseModel):
    items: list[ChatMessageResponse]
    next_cursor: str | None = None


class ConversationUpdate(BaseModel):
    muted: bool | None = None
    archived: bool | None = None


class ReadReceiptCreate(BaseModel):
    message_id: str = Field(min_length=36, max_length=36)


class ChatReportCreate(BaseModel):
    reason: Literal["fraud", "harassment", "spam", "unsafe", "other"]
    details: str | None = Field(default=None, max_length=500)


class ChatReviewCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=500)


class PushDeviceCreate(BaseModel):
    token: str = Field(min_length=32, max_length=200, pattern=r"^[A-Fa-f0-9]+$")
    environment: Literal["sandbox", "production"] = "production"


class PushDeviceResponse(BaseModel):
    id: str
    enabled: bool


class AdminChatReportResponse(BaseModel):
    id: str
    status: str
    reason: str
    details: str | None
    created_at: datetime
    reporter_id: str
    message: ChatMessageResponse
    context: list[ChatMessageResponse]


class AdminChatReportUpdate(BaseModel):
    status: Literal["resolved", "dismissed"]
