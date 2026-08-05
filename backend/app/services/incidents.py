from __future__ import annotations

import hashlib
import re
from datetime import datetime, timedelta, timezone
from typing import Any

from ..core.config import get_settings
from ..core.database import db_session
from ..core.logging import get_logger
from ..models.incident import Incident
from .telegram import send_telegram_message

logger = get_logger(component="incident_service")
_SECRET_KEYS = re.compile(r"(authorization|cookie|password|secret|token|api.?key|email)", re.I)
_BEARER = re.compile(r"(?i)bearer\s+[a-z0-9._~+/=-]+")
_EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}")


def redact(value: Any, *, key: str = "") -> Any:
    if _SECRET_KEYS.search(key):
        return "[REDACTED]"
    if isinstance(value, dict):
        return {str(k)[:64]: redact(v, key=str(k)) for k, v in list(value.items())[:30]}
    if isinstance(value, (list, tuple)):
        return [redact(v) for v in value[:20]]
    text = _EMAIL.sub("[REDACTED_EMAIL]", _BEARER.sub("Bearer [REDACTED]", str(value)))
    return text[:1000]


def fingerprint_for(source: str, title: str, dedupe_key: str | None = None) -> str:
    stable = f"{source.strip().lower()}|{(dedupe_key or title).strip().lower()}"
    return hashlib.sha256(stable.encode("utf-8")).hexdigest()


def record_incident(
    *,
    source: str,
    title: str,
    severity: str = "error",
    message: str | None = None,
    context: dict[str, Any] | None = None,
    dedupe_key: str | None = None,
    force_notify: bool = False,
) -> Incident | None:
    """Persist and optionally notify; incident reporting must never break callers."""
    settings = get_settings()
    if not settings.INCIDENTS_ENABLED:
        return None
    now = datetime.now(timezone.utc)
    fingerprint = fingerprint_for(source, title, dedupe_key)
    clean_context = redact(context or {})
    clean_message = redact(message or "") or None
    try:
        with db_session() as db:
            incident = db.query(Incident).filter(Incident.fingerprint == fingerprint).one_or_none()
            if incident:
                incident.occurrence_count += 1
                incident.last_seen_at = now
                incident.message = clean_message
                incident.context = clean_context
                if incident.status == "resolved":
                    incident.status = "open"
                    incident.resolved_at = None
                    incident.resolved_by = None
            else:
                incident = Incident(
                    fingerprint=fingerprint,
                    source=source[:64],
                    severity=severity[:16],
                    title=title[:200],
                    message=clean_message,
                    context=clean_context,
                )
                db.add(incident)
                db.flush()
            notify_after = now - timedelta(seconds=settings.INCIDENT_ALERT_DEDUPE_SECONDS)
            notified_at = incident.notified_at
            if notified_at is not None and notified_at.tzinfo is None:
                notified_at = notified_at.replace(tzinfo=timezone.utc)
            should_notify = force_notify or notified_at is None or notified_at <= notify_after
            if should_notify:
                incident.notified_at = now
            db.flush()
            db.expunge(incident)
        if should_notify:
            send_telegram_message(
                f"🚨 [{severity.upper()}] {title}\nSource: {source}\n"
                f"{clean_message or 'No details'}\nOccurrences: {incident.occurrence_count}"
            )
        return incident
    except Exception as exc:
        logger.warning("incident_record_failed", source=source, error_type=type(exc).__name__)
        return None
