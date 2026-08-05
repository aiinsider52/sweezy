from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..core.rate_limit import limiter
from ..dependencies import CurrentAdmin, DBSession
from ..models.incident import Incident
from ..services.incidents import record_incident

router = APIRouter()


def _serialize(item: Incident) -> dict:
    return {
        "id": item.id,
        "fingerprint": item.fingerprint,
        "source": item.source,
        "severity": item.severity,
        "title": item.title,
        "message": item.message,
        "context": item.context,
        "status": item.status,
        "occurrence_count": item.occurrence_count,
        "first_seen_at": item.first_seen_at,
        "last_seen_at": item.last_seen_at,
        "notified_at": item.notified_at,
        "resolved_at": item.resolved_at,
        "resolved_by": item.resolved_by,
    }


@router.get("/incidents")
def list_incidents(
    _: CurrentAdmin,
    db: DBSession,
    status: Literal["open", "resolved"] | None = None,
    severity: str | None = None,
    limit: int = Query(default=100, ge=1, le=500),
) -> list[dict]:
    query = db.query(Incident)
    if status:
        query = query.filter(Incident.status == status)
    if severity:
        query = query.filter(Incident.severity == severity)
    return [_serialize(item) for item in query.order_by(Incident.last_seen_at.desc()).limit(limit).all()]


class IncidentStatusUpdate(BaseModel):
    status: Literal["open", "resolved"]


@router.patch("/incidents/{incident_id}")
def update_incident(
    incident_id: str,
    payload: IncidentStatusUpdate,
    admin: CurrentAdmin,
    db: DBSession,
) -> dict:
    incident = db.query(Incident).filter(Incident.id == incident_id).one_or_none()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    incident.status = payload.status
    if payload.status == "resolved":
        incident.resolved_at = datetime.now(timezone.utc)
        incident.resolved_by = str(admin.get("sub") or "admin")
    else:
        incident.resolved_at = None
        incident.resolved_by = None
    db.commit()
    db.refresh(incident)
    return _serialize(incident)


@router.post("/incidents/test-alert")
@limiter.limit("2/hour")
def test_incident_alert(request: Request, admin: CurrentAdmin) -> dict:
    incident = record_incident(
        source="admin",
        title="Protected incident test alert",
        severity="warning",
        message="Manual alert requested by an authenticated administrator.",
        context={"admin_id": admin.get("sub")},
        dedupe_key=f"test-alert:{admin.get('sub')}",
        force_notify=True,
    )
    if not incident:
        raise HTTPException(status_code=503, detail="Incident reporting unavailable")
    return {"ok": True, "incident_id": incident.id}
