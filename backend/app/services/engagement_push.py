"""Pushes that bring people back: matches, likes, events nearby and marketplace activity.

Every push here goes through `enqueue_engagement`, which applies the user's switches, writes the
text in their language, holds delivery until morning during quiet hours and caps how many
promotional pushes one person gets, so the app never becomes the thing they mute.
"""

from __future__ import annotations

import json
from datetime import datetime, time, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session, aliased

from ..core.config import get_settings
from ..core.countries import COUNTRIES
from ..core.database import SessionLocal
from ..core.logging import get_logger
from ..models.chat import NotificationOutbox
from ..models.event_listing import EventListing
from ..models.marketplace import ServiceListing
from ..models.notification import MarketplaceFollow, MarketplaceWatch, NotificationPreference
from ..models.social import EventAttendance, SocialProfile, SocialSwipe

log = get_logger(module="engagement_push")

SUPPORTED_LOCALES = ("uk", "de", "en")
DEFAULT_TIMEZONE = "Europe/Zurich"

# Which switch in Settings governs each kind.
PREFERENCE_FIELD = {
    "friend_match": "social_enabled",
    "likes_digest": "social_enabled",
    "event_nearby": "events_enabled",
    "listing_follow": "marketplace_enabled",
    "listing_views": "marketplace_enabled",
    "price_drop": "marketplace_enabled",
}
# Nice-to-know pushes share a budget; replies to the user's own actions (a match, a price drop on
# something they saved) always go through.
CAPPED_KINDS = ("likes_digest", "event_nearby", "listing_follow", "listing_views")
DAILY_CAP = 1
WEEKLY_CAP = 3
QUIET_START = time(21, 0)
QUIET_END = time(9, 0)
VIEW_MILESTONES = (10, 25, 50, 100, 250, 500, 1000)


def _people_uk(count: int) -> str:
    if count % 10 == 1 and count % 100 != 11:
        return "людина"
    if 2 <= count % 10 <= 4 and not 12 <= count % 100 <= 14:
        return "людини"
    return "людей"


def _render(kind: str, locale: str, p: dict[str, Any]) -> tuple[str, str]:
    count = p.get("count", 0)
    if kind == "friend_match":
        return {
            "uk": (f"Новий збіг · {p['score']}%", f"Ви з {p['name']} обрали одне одного. Чат уже відкритий — напиши першим."),
            "de": (f"Neues Match · {p['score']} %", f"Du und {p['name']} habt euch gegenseitig gewählt. Der Chat ist offen."),
            "en": (f"New match · {p['score']}%", f"You and {p['name']} picked each other. The chat is open — say hi first."),
        }[locale]
    if kind == "likes_digest":
        return {
            "uk": (f"Тебе лайкнули {count} {_people_uk(count)} цього тижня", "Загляни в «Люди» — хтось чекає на твій лайк у відповідь."),
            "de": (f"{count} {'Person mag' if count == 1 else 'Personen mögen'} dich diese Woche", "Schau bei «Menschen» vorbei – jemand wartet auf dein Like."),
            "en": (f"{count} {'person' if count == 1 else 'people'} liked you this week", "Open People — someone is waiting for your like back."),
        }[locale]
    if kind == "event_nearby":
        when = p["when"]
        return {
            "uk": (f"Нова подія поруч: {p['title']}", f"{when} · {p['city']}. Подивись, хто вже йде."),
            "de": (f"Neues Event in deiner Nähe: {p['title']}", f"{when} · {p['city']}. Schau, wer schon dabei ist."),
            "en": (f"New event nearby: {p['title']}", f"{when} · {p['city']}. See who's going."),
        }[locale]
    if kind == "listing_follow":
        more = count - 1
        return {
            "uk": (f"Нове оголошення · {p['region']}", p["title"] + (f" і ще {more}" if more else "")),
            "de": (f"Neues Inserat · {p['region']}", p["title"] + (f" und {more} weitere" if more else "")),
            "en": (f"New listing · {p['region']}", p["title"] + (f" and {more} more" if more else "")),
        }[locale]
    if kind == "listing_views":
        return {
            "uk": (f"Твоє оголошення переглянули {count} разів", f"«{p['title']}» цікавить людей. Відповідай швидко — так продається швидше."),
            "de": (f"Dein Inserat wurde {count}× angesehen", f"«{p['title']}» kommt gut an. Antworte schnell, dann klappt es schneller."),
            "en": (f"Your listing has {count} views", f"“{p['title']}” is getting attention. Quick replies sell faster."),
        }[locale]
    if kind == "price_drop":
        return {
            "uk": ("Ціна знизилась", f"«{p['title']}»: {p['old']} → {p['new']}"),
            "de": ("Preis gesenkt", f"«{p['title']}»: {p['old']} → {p['new']}"),
            "en": ("Price dropped", f"“{p['title']}”: {p['old']} → {p['new']}"),
        }[locale]
    raise ValueError(f"Unknown engagement push kind: {kind}")


def _zone(name: str | None) -> ZoneInfo:
    try:
        return ZoneInfo(name or DEFAULT_TIMEZONE)
    except (ZoneInfoNotFoundError, ValueError):
        return ZoneInfo(DEFAULT_TIMEZONE)


def is_valid_timezone(name: str) -> bool:
    try:
        ZoneInfo(name)
        return True
    except (ZoneInfoNotFoundError, ValueError):
        return False


def deliver_at(tz_name: str | None, now: datetime) -> datetime:
    """Now, unless it is the middle of the night where the user is; then 09:00 their time."""
    local = now.astimezone(_zone(tz_name))
    if QUIET_END <= local.time() < QUIET_START:
        return now
    day = local.date() if local.time() < QUIET_END else local.date() + timedelta(days=1)
    return datetime.combine(day, QUIET_END, tzinfo=local.tzinfo).astimezone(timezone.utc)


def local_now(prefs: NotificationPreference | None, now: datetime) -> datetime:
    return now.astimezone(_zone(prefs.timezone if prefs else None))


def preferences_for(db: Session, user_id: str, country_code: str | None = None) -> NotificationPreference:
    """The stored row, or a fresh one with sensible defaults for the user's country."""
    prefs = db.get(NotificationPreference, user_id)
    if prefs is None:
        country = COUNTRIES.get((country_code or "CH").upper())  # type: ignore[call-overload]
        prefs = NotificationPreference(
            user_id=user_id,
            locale="uk",
            timezone=country.timezone if country else DEFAULT_TIMEZONE,
            social_enabled=True,
            events_enabled=True,
            marketplace_enabled=True,
        )
        db.add(prefs)
        db.flush()
    return prefs


def _over_cap(db: Session, user_id: str, now: datetime) -> bool:
    def sent_since(since: datetime) -> int:
        return db.scalar(
            select(func.count(NotificationOutbox.id)).where(
                NotificationOutbox.recipient_id == user_id,
                NotificationOutbox.event_type.in_(CAPPED_KINDS),
                NotificationOutbox.created_at >= since,
            )
        ) or 0

    return sent_since(now - timedelta(hours=24)) >= DAILY_CAP or sent_since(now - timedelta(days=7)) >= WEEKLY_CAP


def enqueue_engagement(
    db: Session,
    *,
    user_id: str,
    kind: str,
    event_key: str,
    params: dict[str, Any],
    data: dict[str, Any] | None = None,
    now: datetime | None = None,
) -> bool:
    """Queue one push. Returns False when it was filtered out (switched off, capped or a duplicate)."""
    if not get_settings().PUSH_NOTIFICATIONS_ENABLED:
        return False
    now = now or datetime.now(timezone.utc)
    prefs = db.get(NotificationPreference, user_id)
    if prefs is not None and not getattr(prefs, PREFERENCE_FIELD[kind]):
        return False
    if db.scalar(select(NotificationOutbox.id).where(NotificationOutbox.event_key == event_key[:120])):
        return False
    if kind in CAPPED_KINDS and _over_cap(db, user_id, now):
        return False
    locale = prefs.locale if prefs and prefs.locale in SUPPORTED_LOCALES else "uk"
    title, body = _render(kind, locale, params)
    payload = {
        "aps": {"alert": {"title": title[:80], "body": body[:180]}, "sound": "default"},
        "type": kind,
        **(data or {}),
    }
    db.add(
        NotificationOutbox(
            event_key=event_key[:120],
            recipient_id=user_id,
            event_type=kind,
            payload_json=json.dumps(payload, ensure_ascii=False),
            created_at=now,
            next_attempt_at=deliver_at(prefs.timezone if prefs else None, now),
        )
    )
    db.flush()
    return True


# ── Triggers called from request handlers ───────────────────────────────────


def format_price(minor: int, currency: str) -> str:
    amount = minor / 100
    text = f"{amount:,.0f}" if minor % 100 == 0 else f"{amount:,.2f}"
    return f"{text.replace(',', ' ')} {currency}"


def effective_price_minor(listing: ServiceListing) -> int | None:
    if listing.is_free:
        return 0
    if listing.price_minor is not None:
        return listing.price_minor
    if listing.price_chf is not None:
        return listing.price_chf * 100
    return None


def notify_price_drop(db: Session, listing: ServiceListing, old_minor: int | None) -> int:
    new_minor = effective_price_minor(listing)
    if listing.status != "approved" or old_minor is None or new_minor is None or new_minor >= old_minor:
        return 0
    watchers = db.execute(
        select(MarketplaceWatch.user_id).where(
            MarketplaceWatch.listing_id == listing.id,
            MarketplaceWatch.user_id != (listing.author_id or ""),
        )
    ).scalars().all()
    sent = 0
    for user_id in watchers:
        sent += enqueue_engagement(
            db,
            user_id=user_id,
            kind="price_drop",
            event_key=f"price_drop:{listing.id}:{new_minor}:{user_id}",
            params={
                "title": listing.title[:60],
                "old": format_price(old_minor, listing.currency_code),
                "new": format_price(new_minor, listing.currency_code),
            },
            data={"listing_id": listing.id},
        )
    return sent


def notify_listing_views(db: Session, listing: ServiceListing) -> bool:
    if not listing.author_id or listing.view_count not in VIEW_MILESTONES:
        return False
    return enqueue_engagement(
        db,
        user_id=listing.author_id,
        kind="listing_views",
        event_key=f"listing_views:{listing.id}:{listing.view_count}",
        params={"title": listing.title[:60], "count": listing.view_count},
        data={"listing_id": listing.id},
    )


# ── Periodic jobs ────────────────────────────────────────────────────────────


def _likes_digest(db: Session, now: datetime) -> int:
    incoming = aliased(SocialSwipe)
    answer = aliased(SocialSwipe)
    rows = db.execute(
        select(incoming.target_id, func.count(incoming.id))
        .outerjoin(answer, and_(answer.swiper_id == incoming.target_id, answer.target_id == incoming.swiper_id))
        .where(incoming.decision == "like", incoming.created_at >= now - timedelta(days=7), answer.id.is_(None))
        .group_by(incoming.target_id)
    ).all()
    sent = 0
    for user_id, count in rows:
        profile = db.get(SocialProfile, user_id)
        prefs = preferences_for(db, user_id, profile.country_code if profile else None)
        local = local_now(prefs, now)
        due = prefs.likes_digest_sent_at is None or now - _utc(prefs.likes_digest_sent_at) >= timedelta(days=6, hours=12)
        # Sunday evening, when people plan their week.
        if not due or local.weekday() != 6 or not 18 <= local.hour < 21:
            continue
        year, week, _ = local.isocalendar()
        if enqueue_engagement(
            db,
            user_id=user_id,
            kind="likes_digest",
            event_key=f"likes_digest:{user_id}:{year}-{week}",
            params={"count": int(count)},
            now=now,
        ):
            sent += 1
        prefs.likes_digest_sent_at = now
    return sent


def _events_nearby(db: Session, now: datetime) -> int:
    sent = 0
    profiles = db.execute(select(SocialProfile).where(SocialProfile.is_visible.is_(True))).scalars().all()
    for profile in profiles:
        prefs = preferences_for(db, profile.user_id, profile.country_code)
        local = local_now(prefs, now)
        checked = _utc(prefs.events_checked_at) if prefs.events_checked_at else None
        if not 10 <= local.hour < 13 or (checked and now - checked < timedelta(hours=20)):
            continue
        attending = select(EventAttendance.event_id).where(EventAttendance.user_id == profile.user_id)
        event = db.execute(
            select(EventListing)
            .where(
                EventListing.status == "approved",
                EventListing.is_private.is_(False),
                EventListing.country_code == profile.country_code,
                EventListing.subdivision_code == profile.subdivision_code,
                EventListing.starts_at > now + timedelta(hours=3),
                EventListing.starts_at < now + timedelta(days=7),
                EventListing.created_at > (checked or now - timedelta(days=3)),
                func.coalesce(EventListing.author_id, "") != profile.user_id,
                EventListing.id.not_in(attending),
            )
            .order_by(EventListing.starts_at)
            .limit(1)
        ).scalar_one_or_none()
        prefs.events_checked_at = now
        if event is None:
            continue
        starts = _utc(event.starts_at).astimezone(local.tzinfo)
        if enqueue_engagement(
            db,
            user_id=profile.user_id,
            kind="event_nearby",
            event_key=f"event_nearby:{profile.user_id}:{event.id}",
            params={"title": event.title[:50], "city": event.city, "when": starts.strftime("%d.%m, %H:%M")},
            data={"event_id": event.id},
            now=now,
        ):
            sent += 1
    return sent


def _marketplace_follows(db: Session, now: datetime) -> int:
    sent = 0
    published_at = func.coalesce(ServiceListing.last_moderated_at, ServiceListing.created_at)
    for follow in db.execute(select(MarketplaceFollow)).scalars().all():
        since = _utc(follow.last_notified_at or follow.created_at)
        query = select(ServiceListing).where(
            ServiceListing.status == "approved",
            ServiceListing.country_code == follow.country_code,
            ServiceListing.subdivision_code == follow.subdivision_code,
            published_at > since,
            func.coalesce(ServiceListing.author_id, "") != follow.user_id,
        )
        if follow.category:
            query = query.where(ServiceListing.category == follow.category)
        listings = db.execute(query.order_by(published_at.desc()).limit(20)).scalars().all()
        if not listings:
            continue
        prefs = db.get(NotificationPreference, follow.user_id)
        if prefs is not None and not prefs.marketplace_enabled:
            follow.last_notified_at = now
            continue
        country = COUNTRIES.get(follow.country_code)  # type: ignore[call-overload]
        region = country.subdivisions.get(follow.subdivision_code, follow.subdivision_code) if country else follow.subdivision_code
        newest = listings[0]
        if enqueue_engagement(
            db,
            user_id=follow.user_id,
            kind="listing_follow",
            event_key=f"listing_follow:{follow.id}:{newest.id}",
            params={"title": newest.title[:70], "count": len(listings), "region": region},
            data={"listing_id": newest.id},
            now=now,
        ):
            sent += 1
            follow.last_notified_at = now
        # When capped, leave the marker alone: tomorrow's push then says "and N more".
    return sent


def _utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def run_engagement_jobs(now: datetime | None = None) -> dict[str, int]:
    now = now or datetime.now(timezone.utc)
    results: dict[str, int] = {}
    for name, job in (("likes_digest", _likes_digest), ("events_nearby", _events_nearby), ("marketplace_follows", _marketplace_follows)):
        with SessionLocal() as db:
            try:
                results[name] = job(db, now)
                db.commit()
            except Exception as exc:
                db.rollback()
                log.error("engagement_job_failed", job=name, error=str(exc))
    return results
