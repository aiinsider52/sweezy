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


# --- Growth: acquisition → activation → payment, split by install source -----------------------

ACTIVATION_EVENTS = {
    "letter_explained",
    "guide_read",
    "checklist_step_completed",
    "retention_roadmap_task_completed",
    "retention_job_search_performed",
    "retention_marketplace_contact_tapped",
    "retention_deadline_reminder_scheduled",
}
GROWTH_STEPS = (
    ("installs", {"install_attributed"}),
    ("onboarded", {"onboarding_completed"}),
    ("registered", {"account_registered", "account_signed_in"}),
    ("activated", ACTIVATION_EVENTS),
    ("paywall", {"paywall_viewed"}),
    ("paid", {"plus_purchased"}),
)


def _install(event: AnalyticsEvent) -> str | None:
    """Telemetry stamps every event with the install id, so guest and signed-in events join up."""
    return (event.properties or {}).get("install_id")


def _source_label(properties: dict[str, str]) -> str:
    if properties.get("source") != "apple_search_ads":
        return "organic"
    campaign = properties.get("campaign_id")
    return f"apple_search_ads:{campaign}" if campaign else "apple_search_ads"


@router.get("/growth")
def growth(_: CurrentAdmin, db: DBSession, days: int = Query(30, ge=1, le=180)) -> dict[str, Any]:
    events = sorted(_events(db, days), key=lambda item: item.occurred_at)
    first_seen: dict[str, datetime] = {}
    source_of: dict[str, str] = {}
    keyword_of: dict[str, str] = {}
    reached: dict[str, set[str]] = defaultdict(set)
    active_days: dict[str, set[date]] = defaultdict(set)

    for event in events:
        install = _install(event)
        if not install:
            continue
        occurred = event.occurred_at if event.occurred_at.tzinfo else event.occurred_at.replace(tzinfo=timezone.utc)
        first_seen.setdefault(install, occurred)
        active_days[install].add(occurred.date())
        if event.event_type == "install_attributed":
            source_of[install] = _source_label(event.properties or {})
            if keyword := (event.properties or {}).get("keyword_id"):
                keyword_of[install] = keyword
        for step, types in GROWTH_STEPS:
            if event.event_type in types:
                reached[install].add(step)

    by_source: dict[str, list[str]] = defaultdict(list)
    for install in first_seen:
        # Installs that predate attribution (or declined consent before it ran) count as unknown.
        by_source[source_of.get(install, "unknown")].append(install)

    def retained(installs: list[str], offset: int) -> float | None:
        eligible = [i for i in installs if first_seen[i].date() + timedelta(days=offset) <= datetime.now(timezone.utc).date()]
        if not eligible:
            return None
        kept = sum((first_seen[i].date() + timedelta(days=offset)) in active_days[i] for i in eligible)
        return round(kept / len(eligible), 4)

    sources = []
    for source, installs in sorted(by_source.items(), key=lambda item: -len(item[1])):
        counts = {step: sum(step in reached[i] for i in installs) for step, _ in GROWTH_STEPS}
        counts["installs"] = len(installs)
        sources.append({
            "source": source,
            "funnel": [
                {"step": step, "users": counts[step], "rate": round(counts[step] / len(installs), 4)}
                for step, _ in GROWTH_STEPS
            ],
            "retention": {"d1": retained(installs, 1), "d7": retained(installs, 7), "d30": retained(installs, 30)},
        })

    keywords = Counter(keyword_of.values())
    return {
        "since": _window(days).isoformat(),
        "installs": len(first_seen),
        "sources": sources,
        "top_keywords": [{"keyword_id": key, "installs": count} for key, count in keywords.most_common(20)],
    }
