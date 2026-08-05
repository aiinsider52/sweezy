from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated, Any, Dict, Literal

from fastapi import APIRouter, Header, HTTPException, Request, status
from pydantic import BaseModel, Field, field_validator

from ..core.config import get_settings
from ..core.rate_limit import limiter
from ..dependencies import DBSession, OptionalCurrentUser
from ..models.analytics import AnalyticsEvent, AnalyticsSession


router = APIRouter()

_SENSITIVE_META_KEYS = {"email", "phone", "name", "token", "password", "address", "message"}


class TelemetryEventIn(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    ts: datetime
    level: Literal["info", "warn", "error"] = "info"
    source: str = Field(min_length=1, max_length=64)
    type: str = Field(min_length=1, max_length=96)
    message: str | None = Field(default=None, max_length=500)
    meta: Dict[str, str] = Field(default_factory=dict)

    @field_validator("source", "type")
    @classmethod
    def validate_identifier(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized or not all(char.isalnum() or char in "._-" for char in normalized):
            raise ValueError("must contain only letters, numbers, dot, underscore, or dash")
        return normalized

    @field_validator("meta")
    @classmethod
    def validate_meta(cls, value: Dict[str, str]) -> Dict[str, str]:
        if len(value) > 20:
            raise ValueError("meta contains too many keys")
        sanitized: Dict[str, str] = {}
        for key, raw_value in value.items():
            clean_key = key.strip().lower()[:64]
            if clean_key in _SENSITIVE_META_KEYS:
                continue
            sanitized[clean_key] = str(raw_value)[:200]
        return sanitized


class TelemetryBatchIn(BaseModel):
    events: list[TelemetryEventIn] = Field(min_length=1)
    session_id: str | None = Field(default=None, min_length=8, max_length=64)
    guest_id: str | None = Field(default=None, min_length=8, max_length=64)
    app_version: str | None = Field(default=None, max_length=32)
    platform: str = Field(default="ios", min_length=1, max_length=24)

    @field_validator("events")
    @classmethod
    def validate_batch_size(cls, value: list[TelemetryEventIn]) -> list[TelemetryEventIn]:
        if len(value) > get_settings().TELEMETRY_MAX_BATCH_SIZE:
            raise ValueError("telemetry batch is too large")
        return value


@router.post("/batch")
@limiter.limit("30/minute")
def ingest_batch(
    request: Request,
    payload: TelemetryBatchIn,
    db: DBSession,
    user: OptionalCurrentUser,
    x_analytics_consent: Annotated[str | None, Header()] = None,
) -> Dict[str, Any]:
    if x_analytics_consent != "granted":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Analytics consent required")

    if user is None and not payload.guest_id:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="guest_id required for guests")

    now = datetime.now(timezone.utc)
    client_session_id = payload.session_id or f"legacy-{payload.events[0].id}"[:64]
    session = db.query(AnalyticsSession).filter(
        AnalyticsSession.client_session_id == client_session_id
    ).one_or_none()
    if session is None:
        session = AnalyticsSession(
            client_session_id=client_session_id,
            user_id=getattr(user, "id", None),
            guest_id=None if user else payload.guest_id,
            app_version=payload.app_version,
            platform=payload.platform,
            started_at=min(event.ts for event in payload.events),
            last_seen_at=max(event.ts for event in payload.events),
            consent_granted=True,
        )
        db.add(session)
        db.flush()
    elif session.user_id and (user is None or session.user_id != getattr(user, "id", None)):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="session belongs to another user")
    elif session.guest_id and user is None and session.guest_id != payload.guest_id:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="session belongs to another guest")
    elif user is not None and session.user_id is None:
        session.user_id = user.id
        session.guest_id = None

    accepted = 0
    for event in payload.events:
        if db.get(AnalyticsEvent, event.id) is not None:
            continue
        db.add(AnalyticsEvent(
            id=event.id,
            session_id=session.id,
            user_id=getattr(user, "id", None),
            guest_id=None if user else payload.guest_id,
            occurred_at=event.ts,
            level=event.level,
            source=event.source,
            event_type=event.type,
            message=event.message,
            properties=event.meta,
            app_version=payload.app_version,
        ))
        accepted += 1
    previous_seen = session.last_seen_at
    if previous_seen.tzinfo is None:
        previous_seen = previous_seen.replace(tzinfo=timezone.utc)
    session.last_seen_at = max(previous_seen, max(event.ts for event in payload.events))
    session.event_count += accepted
    session.app_version = payload.app_version or session.app_version
    db.commit()
    critical_types = {
        item.strip() for item in get_settings().INCIDENT_CRITICAL_TELEMETRY_TYPES.split(",") if item.strip()
    }
    for event in payload.events:
        if event.level == "error" and event.type in critical_types:
            from ..services.incidents import record_incident

            record_incident(
                source=f"telemetry:{event.source}",
                title=f"Critical telemetry: {event.type}",
                severity="critical",
                message=event.message,
                context=event.meta,
                dedupe_key=event.type,
            )
    return {"accepted": accepted}
