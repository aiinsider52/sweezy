from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
from threading import Lock
from typing import Annotated, Any, Dict, List, Literal, Optional

from fastapi import APIRouter, Header, HTTPException, Request, status
from pydantic import BaseModel, Field, field_validator

from ..core.config import get_settings
from ..core.rate_limit import limiter
from ..dependencies import CurrentAdmin, CurrentUser


router = APIRouter()

LOG_DIR = Path("backend/logs")
LOG_DIR.mkdir(parents=True, exist_ok=True)
_LOG_LOCK = Lock()
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

    @field_validator("events")
    @classmethod
    def validate_batch_size(cls, value: list[TelemetryEventIn]) -> list[TelemetryEventIn]:
        if len(value) > get_settings().TELEMETRY_MAX_BATCH_SIZE:
            raise ValueError("telemetry batch is too large")
        return value


def _log_file_path(dt: Optional[datetime] = None) -> Path:
    day = (dt or datetime.now(timezone.utc)).strftime("%Y-%m-%d")
    return LOG_DIR / f"telemetry-{day}.jsonl"


@router.post("/batch")
@limiter.limit("30/minute")
def ingest_batch(
    request: Request,
    payload: TelemetryBatchIn,
    user: CurrentUser,
    x_analytics_consent: Annotated[str | None, Header()] = None,
) -> Dict[str, Any]:
    if x_analytics_consent != "granted":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Analytics consent required")

    path = _log_file_path()
    lines = []
    for event in payload.events:
        record = event.model_dump(mode="json")
        record["user_id"] = user.id
        lines.append(json.dumps(record, ensure_ascii=False, separators=(",", ":")))

    with _LOG_LOCK:
        with path.open("a", encoding="utf-8") as file_handle:
            file_handle.write("\n".join(lines) + "\n")
    return {"accepted": len(lines)}


@router.get("/admin")
def list_telemetry(
    _: CurrentAdmin,
    limit: int = 200,
    level: Optional[str] = None,
    source: Optional[str] = None,
) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    now = datetime.now(timezone.utc)
    files = [path for path in [_log_file_path(now), _log_file_path(now - timedelta(days=1))] if path.exists()]
    for path in files:
        try:
            with path.open("r", encoding="utf-8") as file_handle:
                for line in file_handle:
                    try:
                        obj = json.loads(line.strip() or "{}")
                        if level and str(obj.get("level")) != level:
                            continue
                        if source and str(obj.get("source")) != source:
                            continue
                        out.append(obj)
                    except (json.JSONDecodeError, TypeError):
                        continue
        except OSError:
            continue
    out.sort(key=lambda item: item.get("ts") or "", reverse=True)
    return out[: max(1, min(1000, limit))]
