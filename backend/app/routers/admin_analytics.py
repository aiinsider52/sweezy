from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Query
from sqlalchemy import func

from ..dependencies import CurrentAdmin, DBSession
from ..models.analytics import AnalyticsEvent, AnalyticsSession


router = APIRouter()


def _window(days: int) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=max(1, min(days, 365)))


def _actor(event: AnalyticsEvent) -> str:
    return f"u:{event.user_id}" if event.user_id else f"g:{event.guest_id}"


def _events(db: DBSession, days: int) -> list[AnalyticsEvent]:
    return db.query(AnalyticsEvent).filter(AnalyticsEvent.occurred_at >= _window(days)).all()


@router.get("/overview")
def overview(
    _: CurrentAdmin,
    db: DBSession,
    days: int = Query(30, ge=1, le=365),
    app_version: str | None = Query(None, max_length=64),
) -> dict[str, Any]:
    since = _window(days)
    event_query = db.query(AnalyticsEvent).filter(AnalyticsEvent.occurred_at >= since)
    session_query = db.query(AnalyticsSession).filter(AnalyticsSession.last_seen_at >= since)
    if app_version:
        event_query = event_query.filter(AnalyticsEvent.app_version == app_version)
        session_query = session_query.filter(AnalyticsSession.app_version == app_version)
    events = event_query.all()
    sessions = session_query.count()
    active_users = len({_actor(event) for event in events})
    errors = sum(event.level == "error" for event in events)
    events_by_day = Counter(event.occurred_at.date() for event in events)
    action_counts = Counter(event.event_type for event in events)
    versions = sorted({event.app_version for event in events if event.app_version})
    return {
        "since": since.isoformat(),
        "events": len(events),
        "sessions": sessions,
        "active_users": active_users,
        "errors": errors,
        "kpis": [
            {"key": "events", "label": "Events", "value": len(events)},
            {"key": "sessions", "label": "Sessions", "value": sessions},
            {"key": "active_users", "label": "Active users", "value": active_users},
            {"key": "errors", "label": "Errors", "value": errors},
        ],
        "trends": [
            {
                "date": (since.date() + timedelta(days=offset)).isoformat(),
                "events": events_by_day.get(since.date() + timedelta(days=offset), 0),
            }
            for offset in range((datetime.now(timezone.utc).date() - since.date()).days + 1)
        ],
        "top": [
            {"name": action.replace("_", " ").title(), "count": count}
            for action, count in action_counts.most_common(10)
        ],
        "funnels": [],
        "versions": versions,
    }


@router.get("/realtime")
def realtime(_: CurrentAdmin, db: DBSession, minutes: int = Query(30, ge=1, le=1440)) -> dict[str, Any]:
    since = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    events = db.query(AnalyticsEvent).filter(AnalyticsEvent.occurred_at >= since).all()
    return {
        "since": since.isoformat(),
        "events": len(events),
        "active_users": len({_actor(event) for event in events}),
        "active_sessions": len({event.session_id for event in events}),
    }


@router.get("/active-users")
def active_users(_: CurrentAdmin, db: DBSession) -> dict[str, int]:
    now = datetime.now(timezone.utc)

    def count(days: int) -> int:
        rows = db.query(AnalyticsEvent).filter(AnalyticsEvent.occurred_at >= now - timedelta(days=days)).all()
        return len({_actor(row) for row in rows})

    return {"dau": count(1), "wau": count(7), "mau": count(30)}


@router.get("/retention")
def retention(_: CurrentAdmin, db: DBSession, days: int = Query(30, ge=2, le=90)) -> dict[str, Any]:
    events = sorted(_events(db, days), key=lambda event: event.occurred_at)
    actor_days: dict[str, set[date]] = defaultdict(set)
    for event in events:
        actor_days[_actor(event)].add(event.occurred_at.date())
    cohorts: dict[date, dict[str, Any]] = {}
    for actor, seen_days in actor_days.items():
        first = min(seen_days)
        cohort = cohorts.setdefault(first, {"size": 0, "returns": Counter()})
        cohort["size"] += 1
        for seen in seen_days:
            cohort["returns"][(seen - first).days] += 1
    return {
        "cohorts": [
            {
                "date": cohort_date.isoformat(),
                "size": values["size"],
                "retention": {
                    str(day): round(count / values["size"], 4)
                    for day, count in sorted(values["returns"].items())
                    if day > 0
                },
            }
            for cohort_date, values in sorted(cohorts.items())
        ]
    }


@router.get("/top-actions")
def top_actions(_: CurrentAdmin, db: DBSession, days: int = 30, limit: int = Query(20, ge=1, le=100)) -> dict[str, Any]:
    counts = Counter(event.event_type for event in _events(db, days))
    return {"actions": [{"action": action, "count": count} for action, count in counts.most_common(limit)]}


@router.get("/funnels")
def funnels(
    _: CurrentAdmin,
    db: DBSession,
    steps: list[str] = Query(..., min_length=2, max_length=10),
    days: int = 30,
) -> dict[str, Any]:
    by_actor: dict[str, list[AnalyticsEvent]] = defaultdict(list)
    for event in sorted(_events(db, days), key=lambda item: item.occurred_at):
        by_actor[_actor(event)].append(event)
    counts = [0] * len(steps)
    for actor_events in by_actor.values():
        position = 0
        for event in actor_events:
            if position < len(steps) and event.event_type == steps[position]:
                counts[position] += 1
                position += 1
    return {
        "steps": [
            {
                "action": step,
                "users": counts[index],
                "conversion": round(counts[index] / counts[0], 4) if counts[0] else 0,
            }
            for index, step in enumerate(steps)
        ]
    }


@router.get("/app-versions")
def app_versions(_: CurrentAdmin, db: DBSession, days: int = 30) -> dict[str, Any]:
    rows = (
        db.query(AnalyticsEvent.app_version, func.count(AnalyticsEvent.id))
        .filter(AnalyticsEvent.occurred_at >= _window(days))
        .group_by(AnalyticsEvent.app_version)
        .order_by(func.count(AnalyticsEvent.id).desc())
        .all()
    )
    return {"versions": [{"version": version or "unknown", "events": count} for version, count in rows]}


@router.get("/errors")
def errors(_: CurrentAdmin, db: DBSession, days: int = 30, limit: int = Query(50, ge=1, le=200)) -> dict[str, Any]:
    rows = (
        db.query(AnalyticsEvent)
        .filter(AnalyticsEvent.occurred_at >= _window(days), AnalyticsEvent.level == "error")
        .order_by(AnalyticsEvent.occurred_at.desc())
        .limit(limit)
        .all()
    )
    return {
        "errors": [
            {
                "id": row.id,
                "occurred_at": row.occurred_at.isoformat(),
                "source": row.source,
                "type": row.event_type,
                "message": row.message,
                "app_version": row.app_version,
                "properties": row.properties,
            }
            for row in rows
        ]
    }
