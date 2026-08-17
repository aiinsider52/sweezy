from __future__ import annotations

from datetime import datetime, timedelta, timezone
from math import atan2, cos, radians, sin, sqrt

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import String, and_, cast, func, or_, select
from sqlalchemy.exc import IntegrityError

from ..dependencies import CurrentUser, DBSession
from ..models.chat import ChatConversation, ChatParticipant
from ..models.event_listing import EventListing
from ..models.marketplace import MarketplaceBlock
from ..models.social import (
    EventAttendance,
    FriendConnection,
    SocialEventInvite,
    SocialEventMessage,
    SocialProfile,
    SocialProfileReport,
    SocialProfileVisit,
    SocialSwipe,
)
from ..models.user import PublicUserProfile, User
from ..schemas.social import (
    AttendanceResponse,
    AttendanceUpsert,
    FriendConnectionResponse,
    FriendDecision,
    FriendRequestCreate,
    SocialActionResponse,
    SocialEventInviteCreate,
    SocialEventMessageCreate,
    SocialEventMessageResponse,
    SocialEventResponse,
    SocialProfilePage,
    SocialProfileResponse,
    SocialProfileUpsert,
    SocialProfileVisitCreate,
    SocialProfileVisitorResponse,
    SocialReportCreate,
    SocialSwipeCreate,
    SocialSwipeDeckResponse,
    SocialSwipeResponse,
)
from ..services.moderation import ensure_case, ensure_profile_review_case
from ..services.push_notifications import enqueue_account_notification

router = APIRouter()


def _now() -> datetime: return datetime.now(timezone.utc)


def _utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def _premium(user: User) -> bool:
    if (user.subscription_status or "free") not in {"trial", "premium"}: return False
    expires = user.subscription_expire_at
    return expires is None or _utc(expires) > _now()


def _distance_km(first: SocialProfile | None, second: SocialProfile) -> int | None:
    if not first or None in (first.latitude, first.longitude, second.latitude, second.longitude): return None
    lat1, lon1, lat2, lon2 = map(radians, (first.latitude, first.longitude, second.latitude, second.longitude))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    value = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return round(6371 * 2 * atan2(sqrt(value), sqrt(1 - value)))


def _residency_stage(profile: SocialProfile) -> str:
    return "newcomer" if profile.arrival_year and profile.arrival_year >= _now().year - 2 else "established"


def _request_allowance(db: DBSession, user: User) -> tuple[int | None, int]:
    abuse_limit = 30 if _premium(user) else 5
    since = _now() - (timedelta(days=1) if _premium(user) else timedelta(days=7))
    sent = db.scalar(select(func.count()).select_from(FriendConnection).where(
        FriendConnection.requester_id == user.id, FriendConnection.created_at >= since)) or 0
    return (None if _premium(user) else max(0, abuse_limit - sent), abuse_limit)


def _swipe_allowance(db: DBSession, user: User) -> tuple[int | None, int | None, datetime | None]:
    if _premium(user):
        return None, None, None
    limit = 15
    since = _now() - timedelta(days=7)
    likes = db.execute(select(SocialSwipe.created_at).where(
        SocialSwipe.swiper_id == user.id,
        SocialSwipe.decision == "like",
        SocialSwipe.created_at >= since,
    ).order_by(SocialSwipe.created_at.asc())).scalars().all()
    reset_at = _utc(likes[0]) + timedelta(days=7) if likes else _now() + timedelta(days=7)
    return max(0, limit - len(likes)), limit, reset_at


def _blocked_ids(db: DBSession, user_id: str):
    return (
        select(MarketplaceBlock.blocked_author_id).where(MarketplaceBlock.user_id == user_id),
        select(MarketplaceBlock.user_id).where(MarketplaceBlock.blocked_author_id == user_id),
    )


def _pair(db: DBSession, first: str, second: str) -> FriendConnection | None:
    return db.execute(select(FriendConnection).where(FriendConnection.pair_key == ":".join(sorted((first, second))))).scalar_one_or_none()


def _response(profile: SocialProfile, viewer: SocialProfile | None, connection: FriendConnection | None = None) -> SocialProfileResponse:
    shared = sorted(set(viewer.interests if viewer else []) & set(profile.interests))
    shared_languages = sorted(set(viewer.languages if viewer else []) & set(profile.languages))
    shared_formats = sorted(set(viewer.meetup_formats if viewer else []) & set(profile.meetup_formats))
    distance = _distance_km(viewer, profile)
    reasons = [f"{len(shared)} спільні інтереси"] if shared else []
    if viewer and viewer.canton == profile.canton: reasons.append("один кантон")
    if shared_languages: reasons.append(f"спільна мова: {shared_languages[0]}")
    if shared_formats: reasons.append("схожий формат зустрічей")
    if distance is not None and distance <= 25: reasons.append(f"{distance} км від тебе")
    score = min(98, len(shared) * 15 + (18 if viewer and viewer.canton == profile.canton else 0)
                + (10 if shared_languages else 0) + (8 if shared_formats else 0)
                + (8 if distance is not None and distance <= 25 else 0))
    state = "none"
    if connection:
        state = connection.status if connection.status == "accepted" else ("incoming" if connection.target_id == viewer.user_id else "outgoing")
    return SocialProfileResponse.model_validate(profile).model_copy(update={
        "match_score": score, "match_reasons": reasons[:4], "distance_km": distance,
        "residency_stage": _residency_stage(profile), "shared_interests": shared, "connection_state": state,
        "connection_id": connection.id if connection else None,
        "conversation_id": connection.conversation_id if connection else None,
        "context_event_id": connection.context_event_id if connection else None,
    })


def _connection_response(db: DBSession, item: FriendConnection, viewer_id: str) -> FriendConnectionResponse:
    other_id = item.requester_id if item.target_id == viewer_id else item.target_id
    profile = db.get(SocialProfile, other_id)
    viewer = db.get(SocialProfile, viewer_id)
    if not profile: raise HTTPException(404, "Social profile not found")
    return FriendConnectionResponse(
        id=item.id, direction="incoming" if item.target_id == viewer_id else "outgoing", status=item.status,
        message=item.message, context_event_id=item.context_event_id, conversation_id=item.conversation_id,
        shared_interests=item.shared_interests, other_profile=_response(profile, viewer, item),
        created_at=item.created_at, updated_at=item.updated_at,
    )


def _create_friend_conversation(db: DBSession, item: FriendConnection) -> None:
    if item.conversation_id:
        return
    requester, target = db.get(SocialProfile, item.requester_id), db.get(SocialProfile, item.target_id)
    if not requester or not target:
        raise HTTPException(404, "Social profile not found")
    conversation = ChatConversation(
        social_profile_id=requester.user_id,
        buyer_id=item.requester_id,
        seller_id=item.target_id,
        listing_type="friend",
        listing_title=f"Друзі · {requester.display_name}"[:100],
        listing_image_url=requester.avatar_url,
        listing_price="Спільні інтереси",
        seller_name=target.display_name[:100],
    )
    db.add(conversation)
    db.flush()
    db.add_all([
        ChatParticipant(conversation_id=conversation.id, user_id=item.requester_id),
        ChatParticipant(conversation_id=conversation.id, user_id=item.target_id),
    ])
    item.conversation_id = conversation.id


@router.get("/profiles", response_model=SocialProfilePage)
def profiles(db: DBSession, user: CurrentUser, q: str | None = Query(None, max_length=100), canton: str | None = None,
             interest: str | None = None, language: str | None = None, age_band: str | None = None,
             residency: str | None = None, max_distance_km: int | None = Query(None, ge=1, le=250),
             nearby: bool = False, event_id: str | None = None, page: int = Query(1, ge=1),
             per_page: int = Query(20, ge=1, le=50)):
    own = db.get(SocialProfile, user.id)
    premium = _premium(user)
    advanced_requested = any((language, age_band, residency, max_distance_km, nearby))
    if advanced_requested and not premium:
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "advanced_friend_search"})
    blocked, blocked_by = _blocked_ids(db, user.id)
    conditions = [SocialProfile.user_id != user.id, SocialProfile.is_visible.is_(True), SocialProfile.open_to_friends.is_(True),
                  SocialProfile.moderation_status == "approved", User.is_active.is_(True),
                  SocialProfile.user_id.not_in(blocked), SocialProfile.user_id.not_in(blocked_by)]
    if q:
        pattern = f"%{q.strip()}%"
        conditions.append(or_(SocialProfile.display_name.ilike(pattern), SocialProfile.city.ilike(pattern), SocialProfile.bio.ilike(pattern), cast(SocialProfile.interests, String).ilike(pattern)))
    if canton: conditions.append(SocialProfile.canton == canton.strip().upper())
    if interest: conditions.append(cast(SocialProfile.interests, String).ilike(f'%"{interest}"%'))
    if language: conditions.append(cast(SocialProfile.languages, String).ilike(f'%"{language.strip().upper()}"%'))
    if age_band: conditions.append(SocialProfile.age_band == age_band)
    if residency == "newcomer": conditions.append(SocialProfile.arrival_year >= _now().year - 2)
    elif residency == "established": conditions.append(or_(SocialProfile.arrival_year.is_(None), SocialProfile.arrival_year < _now().year - 2))
    base = select(SocialProfile).join(User, User.id == SocialProfile.user_id).where(*conditions)
    if event_id:
        if not db.execute(select(EventAttendance).where(EventAttendance.event_id == event_id, EventAttendance.user_id == user.id)).scalar_one_or_none():
            raise HTTPException(403, "Join event before viewing attendees")
        base = base.join(EventAttendance, EventAttendance.user_id == SocialProfile.user_id).where(
            EventAttendance.event_id == event_id, EventAttendance.visible_to_attendees.is_(True))
    rows = db.execute(base).scalars().all()
    ids = [p.user_id for p in rows]
    connections = db.execute(select(FriendConnection).where(or_(
        and_(FriendConnection.requester_id == user.id, FriendConnection.target_id.in_(ids)),
        and_(FriendConnection.target_id == user.id, FriendConnection.requester_id.in_(ids))
    ))).scalars().all() if ids else []
    by_other = {(c.target_id if c.requester_id == user.id else c.requester_id): c for c in connections}
    items = [_response(p, own, by_other.get(p.user_id)) for p in rows]
    if max_distance_km is not None: items = [item for item in items if item.distance_km is not None and item.distance_km <= max_distance_km]
    if nearby: items = [item for item in items if item.distance_km is not None and item.distance_km <= 25]
    boosted = {p.user_id: bool(p.boosted_until and _utc(p.boosted_until) > _now()) for p in rows}
    items.sort(key=lambda p: (boosted.get(p.user_id, False), p.match_score, p.is_verified, p.updated_at), reverse=True)
    total = len(items); start = (page - 1) * per_page
    visible_limit = None if premium else 12
    visible = items if visible_limit is None else items[:visible_limit]
    requests_remaining, _ = _request_allowance(db, user)
    return SocialProfilePage(items=visible[start:start + per_page], total=total, page=page, per_page=per_page,
        pages=max(1, (len(visible) + per_page - 1) // per_page), is_limited=visible_limit is not None and total > visible_limit,
        visible_limit=visible_limit, advanced_filters_available=premium, requests_remaining=requests_remaining)


@router.get("/profile/me", response_model=SocialProfileResponse)
def my_profile(db: DBSession, user: CurrentUser):
    profile = db.get(SocialProfile, user.id)
    if not profile: raise HTTPException(404, "Social profile not created")
    return _response(profile, profile)


@router.get("/swipes/discovery", response_model=SocialSwipeDeckResponse)
def swipe_discovery(
    db: DBSession,
    user: CurrentUser,
    canton: str | None = None,
    interest: str | None = None,
    language: str | None = None,
    nearby: bool = False,
    limit: int = Query(20, ge=1, le=40),
):
    own = db.get(SocialProfile, user.id)
    if not own:
        raise HTTPException(409, "Create your friend profile first")
    if own.moderation_status != "approved" or not own.is_visible or not own.open_to_friends:
        raise HTTPException(409, "Your social profile must be approved and visible")
    premium = _premium(user)
    if (language or nearby) and not premium:
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "advanced_friend_search"})

    blocked, blocked_by = _blocked_ids(db, user.id)
    swiped = select(SocialSwipe.target_id).where(SocialSwipe.swiper_id == user.id)
    requested = select(FriendConnection.target_id).where(FriendConnection.requester_id == user.id)
    received = select(FriendConnection.requester_id).where(FriendConnection.target_id == user.id)
    conditions = [
        SocialProfile.user_id != user.id,
        SocialProfile.is_visible.is_(True),
        SocialProfile.open_to_friends.is_(True),
        SocialProfile.moderation_status == "approved",
        User.is_active.is_(True),
        SocialProfile.user_id.not_in(blocked),
        SocialProfile.user_id.not_in(blocked_by),
        SocialProfile.user_id.not_in(swiped),
        SocialProfile.user_id.not_in(requested),
        SocialProfile.user_id.not_in(received),
    ]
    if canton:
        conditions.append(SocialProfile.canton == canton.strip().upper())
    if interest:
        conditions.append(cast(SocialProfile.interests, String).ilike(f'%"{interest}"%'))
    if language:
        conditions.append(cast(SocialProfile.languages, String).ilike(f'%"{language.strip().upper()}"%'))

    rows = db.execute(select(SocialProfile).join(User, User.id == SocialProfile.user_id).where(*conditions)).scalars().all()
    items = [_response(profile, own) for profile in rows]
    if nearby:
        items = [item for item in items if item.distance_km is not None and item.distance_km <= 25]
    boosted = {profile.user_id: bool(profile.boosted_until and _utc(profile.boosted_until) > _now()) for profile in rows}
    items.sort(key=lambda item: (boosted.get(item.user_id, False), item.match_score, item.is_verified, item.updated_at), reverse=True)
    remaining, weekly_limit, reset_at = _swipe_allowance(db, user)
    return SocialSwipeDeckResponse(
        items=items[:limit],
        likes_remaining=remaining,
        weekly_limit=weekly_limit,
        is_premium=premium,
        reset_at=reset_at,
    )


@router.post("/swipes/{target_id}", response_model=SocialSwipeResponse)
def swipe(target_id: str, payload: SocialSwipeCreate, db: DBSession, user: CurrentUser):
    if not user.email_verified:
        raise HTTPException(403, "Verify your email before connecting")
    own, target = db.get(SocialProfile, user.id), db.get(SocialProfile, target_id)
    if not own:
        raise HTTPException(409, "Create your friend profile first")
    if own.moderation_status != "approved":
        raise HTTPException(409, "Your social profile must be approved first")
    if target_id == user.id:
        raise HTTPException(400, "Cannot swipe your own profile")
    if not target or target.moderation_status != "approved" or not target.is_visible or not target.open_to_friends:
        raise HTTPException(404, "Profile unavailable")
    if db.scalar(select(func.count()).select_from(MarketplaceBlock).where(or_(
        and_(MarketplaceBlock.user_id == user.id, MarketplaceBlock.blocked_author_id == target_id),
        and_(MarketplaceBlock.user_id == target_id, MarketplaceBlock.blocked_author_id == user.id),
    ))):
        raise HTTPException(404, "Profile unavailable")

    # Serialize decisions for one pair. Without this lock, two simultaneous likes can both
    # miss the reciprocal row and leave a mutual choice without a match.
    db.execute(
        select(User.id)
        .where(User.id.in_(sorted((user.id, target_id))))
        .order_by(User.id)
        .with_for_update()
    ).all()

    existing_swipe = db.execute(select(SocialSwipe).where(
        SocialSwipe.swiper_id == user.id,
        SocialSwipe.target_id == target_id,
    )).scalar_one_or_none()
    existing_connection = _pair(db, user.id, target_id)
    if existing_swipe:
        if existing_swipe.decision != payload.decision:
            raise HTTPException(409, "Swipe decision already recorded")
        is_match = bool(existing_connection and existing_connection.status == "accepted")
        remaining, _, _ = _swipe_allowance(db, user)
        return SocialSwipeResponse(
            target_id=target_id,
            decision=payload.decision,
            is_match=is_match,
            connection_id=existing_connection.id if is_match else None,
            conversation_id=existing_connection.conversation_id if is_match else None,
            likes_remaining=remaining,
        )

    if payload.decision == "like":
        remaining, limit, _ = _swipe_allowance(db, user)
        if remaining == 0:
            raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "friend_swipes", "free_limit": limit})
        daily_likes = db.scalar(select(func.count()).select_from(SocialSwipe).where(
            SocialSwipe.swiper_id == user.id,
            SocialSwipe.decision == "like",
            SocialSwipe.created_at >= _now() - timedelta(days=1),
        )) or 0
        if daily_likes >= 100:
            raise HTTPException(429, "Daily safety limit reached")

    row = SocialSwipe(swiper_id=user.id, target_id=target_id, decision=payload.decision)
    db.add(row)
    is_match = False
    connection = existing_connection
    if payload.decision == "pass":
        if connection and connection.target_id == user.id and connection.status == "pending":
            connection.status = "declined"
            connection.responded_at = _now()
            db.add(connection)
    else:
        reciprocal = db.execute(select(SocialSwipe).where(
            SocialSwipe.swiper_id == target_id,
            SocialSwipe.target_id == user.id,
            SocialSwipe.decision == "like",
        )).scalar_one_or_none()
        if connection and connection.status == "accepted":
            is_match = True
        elif connection and connection.target_id == user.id and connection.status == "pending":
            connection.status = "accepted"
            connection.responded_at = _now()
            _create_friend_conversation(db, connection)
            is_match = True
        elif reciprocal and connection is None:
            connection = FriendConnection(
                pair_key=":".join(sorted((user.id, target_id))),
                requester_id=target_id,
                target_id=user.id,
                shared_interests=sorted(set(own.interests) & set(target.interests)),
                status="accepted",
                responded_at=_now(),
            )
            db.add(connection)
            db.flush()
            _create_friend_conversation(db, connection)
            is_match = True
    if is_match and connection:
        pair_key = ":".join(sorted((user.id, target_id)))
        enqueue_account_notification(
            db,
            event_key=f"friend_match:{pair_key}",
            recipient_id=target_id,
            event_type="friend_match",
            title="Новий взаємний збіг",
            body=f"Ви з {own.display_name} обрали одне одного. Чат уже відкритий.",
            data={"conversation_id": connection.conversation_id, "profile_id": user.id},
        )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Swipe already recorded") from None
    remaining, _, _ = _swipe_allowance(db, user)
    return SocialSwipeResponse(
        target_id=target_id,
        decision=payload.decision,
        is_match=is_match,
        connection_id=connection.id if is_match and connection else None,
        conversation_id=connection.conversation_id if is_match and connection else None,
        likes_remaining=remaining,
    )


@router.delete("/swipes/{target_id}", status_code=204)
def undo_pass(target_id: str, db: DBSession, user: CurrentUser):
    row = db.execute(select(SocialSwipe).where(
        SocialSwipe.swiper_id == user.id,
        SocialSwipe.target_id == target_id,
    )).scalar_one_or_none()
    if not row or row.decision != "pass":
        raise HTTPException(404, "Pass not found")
    if _utc(row.created_at) < _now() - timedelta(minutes=10):
        raise HTTPException(409, "Undo window expired")
    db.delete(row)
    db.commit()


@router.put("/profile/me", response_model=SocialProfileResponse)
def save_profile(payload: SocialProfileUpsert, db: DBSession, user: CurrentUser):
    if not user.email_verified: raise HTTPException(403, "Verify your email before publishing")
    if not payload.guidelines_accepted: raise HTTPException(422, "Community guidelines must be accepted")
    values = payload.model_dump(exclude={"guidelines_accepted"})
    values.update(guidelines_accepted=True, is_verified=user.email_verified,
                  moderation_status="pending", moderation_reason=None,
                  moderated_at=None, moderated_by=None)
    profile = db.get(SocialProfile, user.id)
    if profile is None: profile = SocialProfile(user_id=user.id, **values)
    else:
        for key, value in values.items(): setattr(profile, key, value)
    db.add(profile)
    public = db.get(PublicUserProfile, user.id)
    if public is None: db.add(PublicUserProfile(user_id=user.id, display_name=payload.display_name, is_verified=user.email_verified))
    else: public.display_name = payload.display_name
    db.flush()
    ensure_profile_review_case(db, kind="social", user_id=user.id, context={"display_name": profile.display_name, "canton": profile.canton, "city": profile.city, "bio": profile.bio, "avatar_url": profile.avatar_url})
    db.commit(); db.refresh(profile)
    return _response(profile, profile)


@router.post("/profile/me/boost", response_model=SocialProfileResponse)
def boost_profile(db: DBSession, user: CurrentUser):
    if not _premium(user):
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "profile_boost"})
    profile = db.get(SocialProfile, user.id)
    if not profile: raise HTTPException(409, "Create your friend profile first")
    profile.boosted_until = _now() + timedelta(days=7)
    db.add(profile); db.commit(); db.refresh(profile)
    return _response(profile, profile)


@router.post("/profiles/{target_id}/visit", response_model=SocialActionResponse)
def record_profile_visit(target_id: str, payload: SocialProfileVisitCreate, db: DBSession, user: CurrentUser):
    if target_id == user.id:
        return SocialActionResponse(message="Own profile visit ignored")
    target = db.get(SocialProfile, target_id)
    if not target or target.moderation_status != "approved" or not target.is_visible:
        raise HTTPException(404, "Profile unavailable")
    blocked, blocked_by = _blocked_ids(db, user.id)
    unavailable = db.scalar(select(func.count()).select_from(SocialProfile).where(
        SocialProfile.user_id == target_id,
        or_(SocialProfile.user_id.in_(blocked), SocialProfile.user_id.in_(blocked_by)),
    )) or 0
    if unavailable:
        raise HTTPException(404, "Profile unavailable")
    if payload.invisible:
        if not _premium(user):
            raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "invisible_browsing"})
        return SocialActionResponse(message="Invisible visit")
    item = db.execute(select(SocialProfileVisit).where(
        SocialProfileVisit.profile_user_id == target_id,
        SocialProfileVisit.visitor_id == user.id,
    )).scalar_one_or_none()
    if item is None:
        item = SocialProfileVisit(profile_user_id=target_id, visitor_id=user.id)
    else:
        item.visit_count += 1
        item.last_visited_at = _now()
    db.add(item); db.commit()
    return SocialActionResponse(message="Visit recorded")


@router.get("/profile/me/visitors", response_model=list[SocialProfileVisitorResponse])
def profile_visitors(db: DBSession, user: CurrentUser):
    if not _premium(user):
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "profile_visitors"})
    own = db.get(SocialProfile, user.id)
    if not own:
        raise HTTPException(409, "Create your friend profile first")
    rows = db.execute(select(SocialProfileVisit, SocialProfile).join(
        SocialProfile, SocialProfile.user_id == SocialProfileVisit.visitor_id
    ).where(
        SocialProfileVisit.profile_user_id == user.id,
        SocialProfile.moderation_status == "approved",
    ).order_by(SocialProfileVisit.last_visited_at.desc()).limit(100)).all()
    return [SocialProfileVisitorResponse(
        profile=_response(profile, own, _pair(db, user.id, profile.user_id)),
        visit_count=visit.visit_count,
        last_visited_at=visit.last_visited_at,
    ) for visit, profile in rows]


@router.post("/profiles/{target_id}/connect", response_model=FriendConnectionResponse, status_code=201)
def connect(target_id: str, payload: FriendRequestCreate, db: DBSession, user: CurrentUser):
    own, target = db.get(SocialProfile, user.id), db.get(SocialProfile, target_id)
    if not user.email_verified: raise HTTPException(403, "Verify your email before connecting")
    if target_id == user.id: raise HTTPException(400, "Cannot connect with yourself")
    if not own: raise HTTPException(409, "Create your friend profile first")
    if not target or not target.is_visible or not target.open_to_friends: raise HTTPException(404, "Profile unavailable")
    if db.scalar(select(func.count()).select_from(MarketplaceBlock).where(or_(and_(MarketplaceBlock.user_id == user.id, MarketplaceBlock.blocked_author_id == target_id), and_(MarketplaceBlock.user_id == target_id, MarketplaceBlock.blocked_author_id == user.id)))): raise HTTPException(404, "Profile unavailable")
    if _pair(db, user.id, target_id): raise HTTPException(409, "Friend connection already exists")
    remaining, limit = _request_allowance(db, user)
    if remaining == 0: raise HTTPException(402, detail={"code": "plus_required", "feature": "friend_requests", "free_limit": limit})
    daily = db.scalar(select(func.count()).select_from(FriendConnection).where(
        FriendConnection.requester_id == user.id, FriendConnection.created_at >= _now() - timedelta(days=1))) or 0
    if daily >= 30: raise HTTPException(429, "Daily safety limit reached")
    if payload.event_id:
        event = db.get(EventListing, payload.event_id)
        if not event or event.status != "approved": raise HTTPException(404, "Event not found")
    item = FriendConnection(pair_key=":".join(sorted((user.id, target_id))), requester_id=user.id, target_id=target_id,
                            context_event_id=payload.event_id, message=payload.message.strip() if payload.message else None,
                            shared_interests=sorted(set(own.interests) & set(target.interests)))
    db.add(item)
    try: db.commit()
    except IntegrityError:
        db.rollback(); raise HTTPException(409, "Friend connection already exists") from None
    db.refresh(item); return _connection_response(db, item, user.id)


@router.get("/connections", response_model=list[FriendConnectionResponse])
def connections(db: DBSession, user: CurrentUser):
    rows = db.execute(select(FriendConnection).where(or_(FriendConnection.requester_id == user.id, FriendConnection.target_id == user.id)).order_by(FriendConnection.updated_at.desc())).scalars().all()
    return [_connection_response(db, row, user.id) for row in rows]


@router.patch("/connections/{connection_id}", response_model=FriendConnectionResponse)
def decide(connection_id: str, payload: FriendDecision, db: DBSession, user: CurrentUser):
    item = db.get(FriendConnection, connection_id)
    if not item or item.target_id != user.id or item.status != "pending": raise HTTPException(404, "Pending request not found")
    item.status = payload.status; item.responded_at = _now()
    if payload.status == "accepted":
        _create_friend_conversation(db, item)
    db.add(item); db.commit(); db.refresh(item)
    return _connection_response(db, item, user.id)


@router.delete("/connections/{connection_id}", status_code=204)
def cancel(connection_id: str, db: DBSession, user: CurrentUser):
    item = db.get(FriendConnection, connection_id)
    if not item or item.requester_id != user.id or item.status != "pending": raise HTTPException(404, "Pending request not found")
    db.delete(item); db.commit()


@router.get("/events", response_model=list[SocialEventResponse])
def social_events(db: DBSession, user: CurrentUser, canton: str | None = None):
    invited = select(SocialEventInvite.event_id).where(SocialEventInvite.invitee_id == user.id)
    stmt = select(EventListing).where(EventListing.status == "approved", EventListing.starts_at >= _now(),
        or_(EventListing.is_private.is_(False), EventListing.author_id == user.id, EventListing.id.in_(invited)))
    if canton: stmt = stmt.where(EventListing.canton == canton.upper())
    events = db.execute(stmt.order_by(EventListing.starts_at).limit(30)).scalars().all()
    attendance = {a.event_id: a for a in db.execute(select(EventAttendance).where(EventAttendance.user_id == user.id)).scalars().all()}
    counts = dict(db.execute(select(EventAttendance.event_id, func.count()).where(EventAttendance.visible_to_attendees.is_(True)).group_by(EventAttendance.event_id)).all())
    profile = db.get(SocialProfile, user.id)
    return [SocialEventResponse(event_id=e.id, title=e.title, category=e.category, canton=e.canton, city=e.city,
        starts_at=e.starts_at, is_free=e.is_free, attendee_count=counts.get(e.id, 0),
        my_status=attendance[e.id].status if e.id in attendance else None, is_private=e.is_private,
        is_recommended=bool(profile and (e.canton == profile.canton or e.category in profile.interests)),
        recommendation_reason=("Твій кантон" if profile and e.canton == profile.canton else
            ("Збігається з інтересами" if profile and e.category in profile.interests else None)),
        group_chat_available=e.id in attendance and attendance[e.id].status == "going",
        can_invite=e.id in attendance) for e in events]


@router.put("/events/{event_id}/attendance", response_model=AttendanceResponse)
def attend(event_id: str, payload: AttendanceUpsert, db: DBSession, user: CurrentUser):
    if not db.get(SocialProfile, user.id): raise HTTPException(409, "Create your friend profile first")
    event = db.get(EventListing, event_id)
    if not event or event.status != "approved" or _utc(event.starts_at) < _now(): raise HTTPException(404, "Upcoming event not found")
    item = db.execute(select(EventAttendance).where(EventAttendance.event_id == event_id, EventAttendance.user_id == user.id)).scalar_one_or_none()
    if item is None: item = EventAttendance(event_id=event_id, user_id=user.id, status=payload.status, visible_to_attendees=payload.visible_to_attendees)
    else: item.status, item.visible_to_attendees = payload.status, payload.visible_to_attendees
    db.add(item); db.commit()
    return AttendanceResponse(event_id=event_id, status=item.status, visible_to_attendees=item.visible_to_attendees)


@router.delete("/events/{event_id}/attendance", status_code=204)
def leave_event(event_id: str, db: DBSession, user: CurrentUser):
    item = db.execute(select(EventAttendance).where(EventAttendance.event_id == event_id, EventAttendance.user_id == user.id)).scalar_one_or_none()
    if item: db.delete(item); db.commit()


def _require_event_attendee(db: DBSession, event_id: str, user_id: str) -> EventAttendance:
    item = db.execute(select(EventAttendance).where(EventAttendance.event_id == event_id,
        EventAttendance.user_id == user_id, EventAttendance.status == "going")).scalar_one_or_none()
    if not item: raise HTTPException(403, "Mark yourself as going to use event chat")
    return item


@router.post("/events/{event_id}/invite", response_model=SocialActionResponse, status_code=201)
def invite_friend(event_id: str, payload: SocialEventInviteCreate, db: DBSession, user: CurrentUser):
    _require_event_attendee(db, event_id, user.id)
    connection = _pair(db, user.id, payload.friend_user_id)
    if not connection or connection.status != "accepted": raise HTTPException(404, "Friend not found")
    event = db.get(EventListing, event_id)
    if not event or event.status != "approved": raise HTTPException(404, "Event not found")
    existing = db.execute(select(SocialEventInvite).where(SocialEventInvite.event_id == event_id,
        SocialEventInvite.invitee_id == payload.friend_user_id)).scalar_one_or_none()
    if not existing:
        db.add(SocialEventInvite(event_id=event_id, inviter_id=user.id, invitee_id=payload.friend_user_id))
        db.commit()
    return SocialActionResponse(message="Friend invited")


@router.get("/events/{event_id}/messages", response_model=list[SocialEventMessageResponse])
def event_messages(event_id: str, db: DBSession, user: CurrentUser):
    _require_event_attendee(db, event_id, user.id)
    rows = db.execute(select(SocialEventMessage).where(SocialEventMessage.event_id == event_id)
        .order_by(SocialEventMessage.created_at.asc()).limit(200)).scalars().all()
    profiles = {p.user_id: p.display_name for p in db.execute(select(SocialProfile).where(
        SocialProfile.user_id.in_([row.sender_id for row in rows]))).scalars().all()} if rows else {}
    return [SocialEventMessageResponse(id=row.id, event_id=row.event_id, sender_id=row.sender_id,
        sender_name=profiles.get(row.sender_id, "Sweezy user"), body=row.body, created_at=row.created_at) for row in rows]


@router.post("/events/{event_id}/messages", response_model=SocialEventMessageResponse, status_code=201)
def send_event_message(event_id: str, payload: SocialEventMessageCreate, db: DBSession, user: CurrentUser):
    _require_event_attendee(db, event_id, user.id)
    recent = db.scalar(select(func.count()).select_from(SocialEventMessage).where(
        SocialEventMessage.sender_id == user.id, SocialEventMessage.created_at >= _now() - timedelta(minutes=1))) or 0
    if recent >= 10: raise HTTPException(429, "Too many messages")
    body = payload.body.strip()
    if any(token in body.lower() for token in ("http://", "crypto", "send money", "escort")):
        raise HTTPException(422, "Message blocked by safety filter")
    row = SocialEventMessage(event_id=event_id, sender_id=user.id, body=body)
    db.add(row); db.commit(); db.refresh(row)
    profile = db.get(SocialProfile, user.id)
    return SocialEventMessageResponse(id=row.id, event_id=row.event_id, sender_id=row.sender_id,
        sender_name=profile.display_name if profile else "Sweezy user", body=row.body, created_at=row.created_at)


@router.post("/profiles/{target_id}/report", response_model=SocialActionResponse)
def report(target_id: str, payload: SocialReportCreate, db: DBSession, user: CurrentUser):
    if target_id == user.id or not db.get(SocialProfile, target_id): raise HTTPException(404, "Profile not found")
    existing = db.execute(select(SocialProfileReport).where(SocialProfileReport.profile_user_id == target_id, SocialProfileReport.reporter_id == user.id)).scalar_one_or_none()
    if not existing:
        existing = SocialProfileReport(profile_user_id=target_id, reporter_id=user.id, reason=payload.reason, details=payload.details)
        db.add(existing); db.flush()
        ensure_case(db, source_type="social_profile", source_id=target_id, subject_user_id=target_id, reporter_id=user.id, reason=payload.reason, details=payload.details, context={"legacy_report_id": existing.id})
        db.commit()
    return SocialActionResponse(message="Report received")


@router.post("/profiles/{target_id}/block", response_model=SocialActionResponse)
def block(target_id: str, db: DBSession, user: CurrentUser):
    if target_id == user.id: raise HTTPException(400, "Cannot block yourself")
    existing = db.execute(select(MarketplaceBlock).where(MarketplaceBlock.user_id == user.id, MarketplaceBlock.blocked_author_id == target_id)).scalar_one_or_none()
    if not existing: db.add(MarketplaceBlock(user_id=user.id, blocked_author_id=target_id)); db.commit()
    return SocialActionResponse(message="Profile blocked")
