from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import String, and_, cast, func, or_, select
from sqlalchemy.exc import IntegrityError

from ..dependencies import CurrentUser, DBSession
from ..models.chat import ChatConversation, ChatParticipant
from ..models.marketplace import MarketplaceBlock
from ..models.network import ProfessionalConnection, ProfessionalProfile, ProfessionalProfileReport
from ..models.user import PublicUserProfile, User
from ..services.moderation import ensure_case, ensure_profile_review_case
from ..schemas.network import (
    ConnectionCreate,
    ConnectionDecision,
    NetworkActionResponse,
    ProfessionalConnectionResponse,
    ProfessionalProfilePage,
    ProfessionalProfileResponse,
    ProfessionalProfileUpsert,
    ProfileReportCreate,
)


router = APIRouter()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _blocked(db: DBSession, first_id: str, second_id: str) -> bool:
    return bool(
        db.scalar(
            select(func.count()).select_from(MarketplaceBlock).where(
                or_(
                    and_(MarketplaceBlock.user_id == first_id, MarketplaceBlock.blocked_author_id == second_id),
                    and_(MarketplaceBlock.user_id == second_id, MarketplaceBlock.blocked_author_id == first_id),
                )
            )
        )
    )


def _pair_connection(db: DBSession, first_id: str, second_id: str) -> ProfessionalConnection | None:
    return db.execute(
        select(ProfessionalConnection).where(
            or_(
                and_(ProfessionalConnection.requester_id == first_id, ProfessionalConnection.target_id == second_id),
                and_(ProfessionalConnection.requester_id == second_id, ProfessionalConnection.target_id == first_id),
            )
        )
    ).scalar_one_or_none()


def _profile_response(
    profile: ProfessionalProfile,
    viewer_id: str,
    connection: ProfessionalConnection | None = None,
) -> ProfessionalProfileResponse:
    state = "none"
    if connection:
        if connection.status == "pending":
            state = "incoming" if connection.target_id == viewer_id else "outgoing"
        else:
            state = connection.status
    return ProfessionalProfileResponse.model_validate(profile).model_copy(
        update={
            "connection_state": state,
            "connection_id": connection.id if connection else None,
            "conversation_id": connection.conversation_id if connection else None,
        }
    )


def _connection_response(
    db: DBSession,
    connection: ProfessionalConnection,
    viewer_id: str,
) -> ProfessionalConnectionResponse:
    incoming = connection.target_id == viewer_id
    other_id = connection.requester_id if incoming else connection.target_id
    profile = db.get(ProfessionalProfile, other_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Professional profile not found")
    return ProfessionalConnectionResponse(
        id=connection.id,
        direction="incoming" if incoming else "outgoing",
        status=connection.status,
        message=connection.message,
        conversation_id=connection.conversation_id,
        other_profile=_profile_response(profile, viewer_id, connection),
        created_at=connection.created_at,
        updated_at=connection.updated_at,
    )


@router.get("/profiles", response_model=ProfessionalProfilePage)
def list_profiles(
    db: DBSession,
    user: CurrentUser,
    q: str | None = Query(default=None, max_length=100),
    canton: str | None = Query(default=None, max_length=10),
    role: str | None = Query(default=None, max_length=30),
    industry: str | None = Query(default=None, max_length=60),
    goal: str | None = Query(default=None, max_length=30),
    page: int = Query(default=1, ge=1),
    per_page: int = Query(default=20, ge=1, le=50),
) -> ProfessionalProfilePage:
    blocked_ids = select(MarketplaceBlock.blocked_author_id).where(MarketplaceBlock.user_id == user.id)
    blocked_by_ids = select(MarketplaceBlock.user_id).where(MarketplaceBlock.blocked_author_id == user.id)
    conditions = [
        ProfessionalProfile.is_visible.is_(True),
        ProfessionalProfile.moderation_status == "approved",
        ProfessionalProfile.user_id != user.id,
        User.is_active.is_(True),
        ProfessionalProfile.user_id.not_in(blocked_ids),
        ProfessionalProfile.user_id.not_in(blocked_by_ids),
    ]
    if q:
        pattern = f"%{q.strip()}%"
        conditions.append(
            or_(
                ProfessionalProfile.display_name.ilike(pattern),
                ProfessionalProfile.headline.ilike(pattern),
                ProfessionalProfile.company_name.ilike(pattern),
                ProfessionalProfile.industry.ilike(pattern),
                ProfessionalProfile.city.ilike(pattern),
                cast(ProfessionalProfile.skills, String).ilike(pattern),
            )
        )
    if canton:
        conditions.append(ProfessionalProfile.canton == canton.strip().upper())
    if role:
        conditions.append(ProfessionalProfile.role == role)
    if industry:
        conditions.append(ProfessionalProfile.industry.ilike(industry.strip()))
    if goal:
        conditions.append(cast(ProfessionalProfile.goals, String).ilike(f'%"{goal}"%'))

    base = select(ProfessionalProfile).join(User, User.id == ProfessionalProfile.user_id).where(*conditions)
    total = db.scalar(select(func.count()).select_from(base.subquery())) or 0
    rows = db.execute(
        base.order_by(
            ProfessionalProfile.is_featured.desc(),
            ProfessionalProfile.is_verified.desc(),
            ProfessionalProfile.updated_at.desc(),
        ).offset((page - 1) * per_page).limit(per_page)
    ).scalars().all()

    ids = [row.user_id for row in rows]
    connections = []
    if ids:
        connections = db.execute(
            select(ProfessionalConnection).where(
                or_(
                    and_(ProfessionalConnection.requester_id == user.id, ProfessionalConnection.target_id.in_(ids)),
                    and_(ProfessionalConnection.target_id == user.id, ProfessionalConnection.requester_id.in_(ids)),
                )
            )
        ).scalars().all()
    by_other = {
        (item.target_id if item.requester_id == user.id else item.requester_id): item
        for item in connections
    }
    return ProfessionalProfilePage(
        items=[_profile_response(row, user.id, by_other.get(row.user_id)) for row in rows],
        total=total,
        page=page,
        per_page=per_page,
        pages=max(1, (total + per_page - 1) // per_page),
    )


@router.get("/profile/me", response_model=ProfessionalProfileResponse)
def my_profile(db: DBSession, user: CurrentUser) -> ProfessionalProfileResponse:
    profile = db.get(ProfessionalProfile, user.id)
    if not profile:
        raise HTTPException(status_code=404, detail="Professional profile not created")
    return _profile_response(profile, user.id)


@router.put("/profile/me", response_model=ProfessionalProfileResponse)
def upsert_profile(
    payload: ProfessionalProfileUpsert,
    db: DBSession,
    user: CurrentUser,
) -> ProfessionalProfileResponse:
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before publishing a professional profile")
    profile = db.get(ProfessionalProfile, user.id)
    values = payload.model_dump()
    values.update(
        moderation_status="pending",
        moderation_reason=None,
        moderated_at=None,
        moderated_by=None,
    )
    if profile is None:
        profile = ProfessionalProfile(user_id=user.id, **values)
    else:
        for key, value in values.items():
            setattr(profile, key, value)
    db.add(profile)

    public = db.get(PublicUserProfile, user.id)
    if public is None:
        public = PublicUserProfile(user_id=user.id, display_name=payload.display_name, is_verified=user.email_verified)
    else:
        public.display_name = payload.display_name
        if payload.avatar_url:
            public.avatar_url = payload.avatar_url
    db.add(public)
    db.flush()
    ensure_profile_review_case(db, kind="professional", user_id=user.id, context={"display_name": profile.display_name, "headline": profile.headline, "company_name": profile.company_name, "canton": profile.canton, "city": profile.city, "bio": profile.bio, "avatar_url": profile.avatar_url})
    db.commit()
    db.refresh(profile)
    return _profile_response(profile, user.id)


@router.get("/profiles/{profile_user_id}", response_model=ProfessionalProfileResponse)
def profile_detail(profile_user_id: str, db: DBSession, user: CurrentUser) -> ProfessionalProfileResponse:
    profile = db.get(ProfessionalProfile, profile_user_id)
    target = db.get(User, profile_user_id)
    if (
        not profile
        or not target
        or not target.is_active
        or (not profile.is_visible and profile_user_id != user.id)
        or (profile.moderation_status != "approved" and profile_user_id != user.id)
        or _blocked(db, user.id, profile_user_id)
    ):
        raise HTTPException(status_code=404, detail="Professional profile not found")
    return _profile_response(profile, user.id, _pair_connection(db, user.id, profile_user_id))


@router.post(
    "/profiles/{profile_user_id}/connect",
    response_model=ProfessionalConnectionResponse,
    status_code=status.HTTP_201_CREATED,
)
def request_connection(
    profile_user_id: str,
    payload: ConnectionCreate,
    db: DBSession,
    user: CurrentUser,
) -> ProfessionalConnectionResponse:
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before connecting")
    if profile_user_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot connect with yourself")
    own_profile = db.get(ProfessionalProfile, user.id)
    target = db.get(ProfessionalProfile, profile_user_id)
    if not own_profile:
        raise HTTPException(status_code=409, detail="Create your professional profile first")
    if not target or target.moderation_status != "approved" or not target.is_visible or not target.open_to_connections or _blocked(db, user.id, profile_user_id):
        raise HTTPException(status_code=404, detail="Professional profile unavailable")

    existing = _pair_connection(db, user.id, profile_user_id)
    if existing:
        if existing.status == "declined" and existing.requester_id == user.id:
            existing.status = "pending"
            existing.message = payload.message.strip() if payload.message else None
            existing.responded_at = None
            db.add(existing)
            db.commit()
            db.refresh(existing)
            return _connection_response(db, existing, user.id)
        raise HTTPException(status_code=409, detail="Connection already exists")

    sent_today = db.scalar(
        select(func.count()).select_from(ProfessionalConnection).where(
            ProfessionalConnection.requester_id == user.id,
            ProfessionalConnection.created_at >= _now() - timedelta(days=1),
        )
    ) or 0
    if sent_today >= 20:
        raise HTTPException(status_code=429, detail="Daily connection request limit reached")

    connection = ProfessionalConnection(
        pair_key=":".join(sorted((user.id, profile_user_id))),
        requester_id=user.id,
        target_id=profile_user_id,
        message=payload.message.strip() if payload.message else None,
    )
    db.add(connection)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Connection already exists") from None
    db.refresh(connection)
    return _connection_response(db, connection, user.id)


@router.get("/connections", response_model=list[ProfessionalConnectionResponse])
def list_connections(
    db: DBSession,
    user: CurrentUser,
    box: str = Query(default="all", pattern="^(all|incoming|outgoing|accepted)$"),
) -> list[ProfessionalConnectionResponse]:
    if box == "incoming":
        condition = and_(ProfessionalConnection.target_id == user.id, ProfessionalConnection.status == "pending")
    elif box == "outgoing":
        condition = and_(ProfessionalConnection.requester_id == user.id, ProfessionalConnection.status == "pending")
    elif box == "accepted":
        condition = and_(
            or_(ProfessionalConnection.requester_id == user.id, ProfessionalConnection.target_id == user.id),
            ProfessionalConnection.status == "accepted",
        )
    else:
        condition = or_(ProfessionalConnection.requester_id == user.id, ProfessionalConnection.target_id == user.id)
    rows = db.execute(
        select(ProfessionalConnection).where(condition).order_by(ProfessionalConnection.updated_at.desc()).limit(200)
    ).scalars().all()
    return [_connection_response(db, row, user.id) for row in rows if not _blocked(db, row.requester_id, row.target_id)]


@router.patch("/connections/{connection_id}", response_model=ProfessionalConnectionResponse)
def respond_to_connection(
    connection_id: str,
    payload: ConnectionDecision,
    db: DBSession,
    user: CurrentUser,
) -> ProfessionalConnectionResponse:
    connection = db.get(ProfessionalConnection, connection_id)
    if not connection or connection.target_id != user.id or connection.status != "pending":
        raise HTTPException(status_code=404, detail="Pending connection request not found")
    if payload.status == "accepted" and _blocked(db, connection.requester_id, connection.target_id):
        raise HTTPException(status_code=403, detail="Connection unavailable")

    connection.status = payload.status
    connection.responded_at = _now()
    if payload.status == "accepted":
        requester = db.get(ProfessionalProfile, connection.requester_id)
        target = db.get(ProfessionalProfile, connection.target_id)
        if not requester or not target:
            raise HTTPException(status_code=409, detail="Both professional profiles are required")
        conversation = db.execute(
            select(ChatConversation).where(
                ChatConversation.network_profile_id == requester.user_id,
                ChatConversation.buyer_id == connection.requester_id,
                ChatConversation.seller_id == connection.target_id,
            )
        ).scalar_one_or_none()
        if conversation is None:
            conversation = ChatConversation(
                listing_id=None,
                job_id=None,
                network_profile_id=requester.user_id,
                buyer_id=connection.requester_id,
                seller_id=connection.target_id,
                listing_type="network",
                listing_title=f"Знайомство · {requester.display_name}"[:100],
                listing_image_url=requester.avatar_url,
                listing_price=requester.headline[:100],
                seller_name=target.display_name[:100],
            )
            db.add(conversation)
            try:
                db.flush()
                db.add_all(
                    [
                        ChatParticipant(conversation_id=conversation.id, user_id=connection.requester_id),
                        ChatParticipant(conversation_id=conversation.id, user_id=connection.target_id),
                    ]
                )
            except IntegrityError:
                db.rollback()
                conversation = db.execute(
                    select(ChatConversation).where(
                        ChatConversation.network_profile_id == requester.user_id,
                        ChatConversation.buyer_id == connection.requester_id,
                        ChatConversation.seller_id == connection.target_id,
                    )
                ).scalar_one()
                connection = db.get(ProfessionalConnection, connection_id)
                connection.status = "accepted"
                connection.responded_at = _now()
        connection.conversation_id = conversation.id
    db.add(connection)
    db.commit()
    db.refresh(connection)
    return _connection_response(db, connection, user.id)


@router.delete("/connections/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_pending_connection(connection_id: str, db: DBSession, user: CurrentUser) -> None:
    connection = db.get(ProfessionalConnection, connection_id)
    if not connection or connection.requester_id != user.id or connection.status != "pending":
        raise HTTPException(status_code=404, detail="Outgoing connection request not found")
    db.delete(connection)
    db.commit()


@router.post("/profiles/{profile_user_id}/report", response_model=NetworkActionResponse)
def report_profile(
    profile_user_id: str,
    payload: ProfileReportCreate,
    db: DBSession,
    user: CurrentUser,
) -> NetworkActionResponse:
    if profile_user_id == user.id or not db.get(ProfessionalProfile, profile_user_id):
        raise HTTPException(status_code=404, detail="Professional profile not found")
    existing = db.execute(
        select(ProfessionalProfileReport).where(
            ProfessionalProfileReport.profile_user_id == profile_user_id,
            ProfessionalProfileReport.reporter_id == user.id,
        )
    ).scalar_one_or_none()
    if not existing:
        existing = ProfessionalProfileReport(
                profile_user_id=profile_user_id,
                reporter_id=user.id,
                reason=payload.reason,
                details=payload.details.strip() if payload.details else None,
            )
        db.add(existing)
        db.flush()
        ensure_case(db, source_type="professional_profile", source_id=profile_user_id, subject_user_id=profile_user_id, reporter_id=user.id, reason=payload.reason, details=payload.details, context={"legacy_report_id": existing.id})
        db.commit()
    return NetworkActionResponse(message="Report received for moderation")


@router.post("/profiles/{profile_user_id}/block", response_model=NetworkActionResponse)
def block_profile(profile_user_id: str, db: DBSession, user: CurrentUser) -> NetworkActionResponse:
    if profile_user_id == user.id or not db.get(ProfessionalProfile, profile_user_id):
        raise HTTPException(status_code=404, detail="Professional profile not found")
    existing = db.execute(
        select(MarketplaceBlock).where(
            MarketplaceBlock.user_id == user.id,
            MarketplaceBlock.blocked_author_id == profile_user_id,
        )
    ).scalar_one_or_none()
    if not existing:
        db.add(MarketplaceBlock(user_id=user.id, blocked_author_id=profile_user_id))
        db.commit()
    return NetworkActionResponse(message="Profile blocked")
