from __future__ import annotations

import math
import re
from datetime import datetime, timedelta, timezone

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy import and_, exists, func, or_, select
from sqlalchemy.exc import IntegrityError

from ..core.chat_metrics import (
    CHAT_CONVERSATIONS_CREATED,
    CHAT_DEALS_CLOSED,
    CHAT_MESSAGES_SENT,
    CHAT_REVIEWS_CREATED,
    CHAT_SAFETY_ACTIONS,
)
from ..core.config import get_settings
from ..core.database import SessionLocal
from ..core.security import decode_token
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.chat import (
    ChatConversation,
    ChatMessage,
    ChatMessageReport,
    ChatParticipant,
    MarketplaceReview,
    PushDevice,
)
from ..models.job import Job
from ..models.marketplace import MarketplaceBlock, ServiceListing
from ..models.user import User
from ..schemas.chat import (
    AdminChatReportResponse,
    AdminChatReportUpdate,
    ChatMessageCreate,
    ChatMessageResponse,
    ChatReportCreate,
    ChatReviewCreate,
    ConversationCreate,
    ConversationPage,
    ConversationResponse,
    ConversationUpdate,
    MessagePage,
    PushDeviceCreate,
    PushDeviceResponse,
    ReadReceiptCreate,
)
from ..schemas.marketplace import MarketplaceSafetyResponse
from ..services.chat_realtime import chat_realtime
from ..services.push_notifications import enqueue_chat_push
from ..services.users import UserService


def _require_chat_enabled() -> None:
    if not get_settings().CHAT_ENABLED:
        raise HTTPException(status_code=503, detail="Chat is temporarily unavailable")


router = APIRouter(dependencies=[Depends(_require_chat_enabled)])
admin_router = APIRouter()
devices_router = APIRouter(dependencies=[Depends(_require_chat_enabled)])

_URL_PATTERN = re.compile(r"(?:https?://|www\.)", re.IGNORECASE)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def _participant_ids(conversation: ChatConversation) -> tuple[str, str]:
    return conversation.buyer_id, conversation.seller_id


def _other_user_id(conversation: ChatConversation, user_id: str) -> str:
    return conversation.seller_id if user_id == conversation.buyer_id else conversation.buyer_id


def _ensure_participant(db: DBSession, conversation_id: str, user_id: str) -> tuple[ChatConversation, ChatParticipant]:
    conversation = db.get(ChatConversation, conversation_id)
    if not conversation or user_id not in _participant_ids(conversation):
        raise HTTPException(status_code=404, detail="Conversation not found")
    participant = db.execute(
        select(ChatParticipant).where(
            ChatParticipant.conversation_id == conversation.id,
            ChatParticipant.user_id == user_id,
            ChatParticipant.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not participant:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conversation, participant


def _is_blocked(db, first_id: str, second_id: str) -> bool:
    return (
        db.scalar(
            select(func.count())
            .select_from(MarketplaceBlock)
            .where(
                or_(
                    and_(MarketplaceBlock.user_id == first_id, MarketplaceBlock.blocked_author_id == second_id),
                    and_(MarketplaceBlock.user_id == second_id, MarketplaceBlock.blocked_author_id == first_id),
                )
            )
        )
        or 0
    ) > 0


def _ensure_not_blocked(db, conversation: ChatConversation) -> None:
    if _is_blocked(db, conversation.buyer_id, conversation.seller_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Conversation unavailable")


def _display_name(user: User | None) -> str:
    if not user:
        return "Sweezy user"
    return user.email.split("@", 1)[0][:100]


def _conversation_response(db, conversation: ChatConversation, user_id: str) -> ConversationResponse:
    participant = db.execute(
        select(ChatParticipant).where(
            ChatParticipant.conversation_id == conversation.id,
            ChatParticipant.user_id == user_id,
        )
    ).scalar_one()
    other_id = _other_user_id(conversation, user_id)
    other_user = db.get(User, other_id)
    other_name = conversation.seller_name if other_id == conversation.seller_id else _display_name(other_user)
    unread_stmt = select(func.count()).select_from(ChatMessage).where(
        ChatMessage.conversation_id == conversation.id,
        ChatMessage.sender_id != user_id,
        ChatMessage.deleted_at.is_(None),
    )
    if participant.last_read_at is not None:
        unread_stmt = unread_stmt.where(ChatMessage.created_at > participant.last_read_at)
    unread = db.scalar(unread_stmt) or 0
    listing = db.get(ServiceListing, conversation.listing_id) if conversation.listing_id else None
    job = db.get(Job, conversation.job_id) if conversation.job_id else None
    return ConversationResponse(
        id=conversation.id,
        listing_id=conversation.listing_id,
        job_id=conversation.job_id,
        listing_type=conversation.listing_type,
        listing_title=conversation.listing_title,
        listing_image_url=conversation.listing_image_url,
        listing_price=conversation.listing_price,
        listing_status=listing.status if listing else (job.status if job else "removed"),
        other_user_id=other_id,
        other_user_name=other_name,
        is_seller=user_id == conversation.seller_id,
        status=conversation.status,
        last_message_preview=conversation.last_message_preview,
        last_message_sender_id=conversation.last_message_sender_id,
        last_message_at=conversation.last_message_at,
        unread_count=unread,
        muted=participant.muted,
        archived=participant.archived,
        created_at=conversation.created_at,
    )


@router.post("/conversations", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED)
def create_conversation(payload: ConversationCreate, db: DBSession, user: CurrentUser) -> ConversationResponse:
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before messaging")
    listing = db.get(ServiceListing, payload.listing_id)
    if not listing or listing.status != "approved":
        raise HTTPException(status_code=404, detail="Listing not found")
    if not listing.author_id:
        raise HTTPException(
            status_code=409,
            detail="This listing cannot receive messages yet because it has no seller account",
        )
    if listing.author_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot message your own listing")
    if _is_blocked(db, user.id, listing.author_id):
        raise HTTPException(status_code=403, detail="Conversation unavailable")

    existing = db.execute(
        select(ChatConversation).where(
            ChatConversation.listing_id == listing.id,
            ChatConversation.buyer_id == user.id,
            ChatConversation.seller_id == listing.author_id,
        )
    ).scalar_one_or_none()
    if existing:
        participant = db.execute(
            select(ChatParticipant).where(
                ChatParticipant.conversation_id == existing.id,
                ChatParticipant.user_id == user.id,
            )
        ).scalar_one()
        participant.archived = False
        participant.deleted_at = None
        db.commit()
        return _conversation_response(db, existing, user.id)

    recent_count = db.scalar(
        select(func.count())
        .select_from(ChatConversation)
        .where(ChatConversation.buyer_id == user.id, ChatConversation.created_at >= _now() - timedelta(hours=1))
    ) or 0
    if recent_count >= 5:
        raise HTTPException(status_code=429, detail="Too many new conversations. Try again later")

    price = "Безкоштовно" if listing.is_free else (listing.price_info or (f"CHF {listing.price_chf}" if listing.price_chf else None))
    conversation = ChatConversation(
        listing_id=listing.id,
        buyer_id=user.id,
        seller_id=listing.author_id,
        listing_type=listing.listing_type,
        listing_title=listing.title,
        listing_image_url=listing.image_urls[0] if listing.image_urls else None,
        listing_price=price,
        seller_name=listing.author_name,
    )
    db.add(conversation)
    created_new = True
    try:
        db.flush()
        db.add_all(
            [
                ChatParticipant(conversation_id=conversation.id, user_id=user.id),
                ChatParticipant(conversation_id=conversation.id, user_id=listing.author_id),
            ]
        )
        db.commit()
    except IntegrityError:
        created_new = False
        db.rollback()
        conversation = db.execute(
            select(ChatConversation).where(
                ChatConversation.listing_id == listing.id,
                ChatConversation.buyer_id == user.id,
                ChatConversation.seller_id == listing.author_id,
            )
        ).scalar_one()
    db.refresh(conversation)
    if created_new:
        CHAT_CONVERSATIONS_CREATED.labels(listing_type=conversation.listing_type).inc()
    return _conversation_response(db, conversation, user.id)


@router.post("/conversations/jobs/{job_id}", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED)
def create_job_conversation(job_id: str, db: DBSession, user: CurrentUser) -> ConversationResponse:
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before messaging")
    job = db.get(Job, job_id)
    if not job or job.status != "active" or not job.employer_id:
        raise HTTPException(status_code=404, detail="Sweezy employer job not found")
    if job.employer_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot message your own job")
    if _is_blocked(db, user.id, job.employer_id):
        raise HTTPException(status_code=403, detail="Conversation unavailable")

    existing = db.execute(
        select(ChatConversation).where(
            ChatConversation.job_id == job.id,
            ChatConversation.buyer_id == user.id,
            ChatConversation.seller_id == job.employer_id,
        )
    ).scalar_one_or_none()
    if existing:
        participant = db.execute(
            select(ChatParticipant).where(
                ChatParticipant.conversation_id == existing.id,
                ChatParticipant.user_id == user.id,
            )
        ).scalar_one()
        participant.archived = False
        participant.deleted_at = None
        db.commit()
        return _conversation_response(db, existing, user.id)

    recent_count = db.scalar(
        select(func.count())
        .select_from(ChatConversation)
        .where(ChatConversation.buyer_id == user.id, ChatConversation.created_at >= _now() - timedelta(hours=1))
    ) or 0
    if recent_count >= 5:
        raise HTTPException(status_code=429, detail="Too many new conversations. Try again later")

    salary = job.salary_text
    if not salary and (job.salary_min or job.salary_max):
        low = str(job.salary_min or "")
        high = str(job.salary_max or "")
        salary = f"CHF {low}{'–' if low and high else ''}{high}"
    conversation = ChatConversation(
        listing_id=None,
        job_id=job.id,
        buyer_id=user.id,
        seller_id=job.employer_id,
        listing_type="job",
        listing_title=job.title[:100],
        listing_image_url=None,
        listing_price=salary,
        seller_name=(job.company or "Sweezy employer")[:100],
    )
    db.add(conversation)
    created_new = True
    try:
        db.flush()
        db.add_all(
            [
                ChatParticipant(conversation_id=conversation.id, user_id=user.id),
                ChatParticipant(conversation_id=conversation.id, user_id=job.employer_id),
            ]
        )
        db.commit()
    except IntegrityError:
        created_new = False
        db.rollback()
        conversation = db.execute(
            select(ChatConversation).where(
                ChatConversation.job_id == job.id,
                ChatConversation.buyer_id == user.id,
                ChatConversation.seller_id == job.employer_id,
            )
        ).scalar_one()
    db.refresh(conversation)
    if created_new:
        CHAT_CONVERSATIONS_CREATED.labels(listing_type="job").inc()
    return _conversation_response(db, conversation, user.id)


@router.get("/conversations", response_model=ConversationPage)
def list_conversations(
    db: DBSession,
    user: CurrentUser,
    archived: bool = False,
    cursor: datetime | None = None,
    limit: int = Query(30, ge=1, le=50),
) -> ConversationPage:
    stmt = (
        select(ChatConversation)
        .join(ChatParticipant, ChatParticipant.conversation_id == ChatConversation.id)
        .where(
            ChatParticipant.user_id == user.id,
            ChatParticipant.deleted_at.is_(None),
            ChatParticipant.archived.is_(archived),
        )
    )
    blocked = exists(
        select(MarketplaceBlock.id).where(
            or_(
                and_(
                    MarketplaceBlock.user_id == ChatConversation.buyer_id,
                    MarketplaceBlock.blocked_author_id == ChatConversation.seller_id,
                ),
                and_(
                    MarketplaceBlock.user_id == ChatConversation.seller_id,
                    MarketplaceBlock.blocked_author_id == ChatConversation.buyer_id,
                ),
            )
        )
    )
    stmt = stmt.where(~blocked)
    if cursor:
        stmt = stmt.where(func.coalesce(ChatConversation.last_message_at, ChatConversation.created_at) < cursor)
    rows = db.execute(
        stmt.order_by(func.coalesce(ChatConversation.last_message_at, ChatConversation.created_at).desc()).limit(limit + 1)
    ).scalars().all()
    has_more = len(rows) > limit
    visible = rows[:limit]
    next_cursor = None
    if has_more and visible:
        next_cursor = (visible[-1].last_message_at or visible[-1].created_at).isoformat()
    return ConversationPage(
        items=[_conversation_response(db, row, user.id) for row in visible],
        next_cursor=next_cursor,
    )


@router.get("/conversations/unread-count")
def unread_count(db: DBSession, user: CurrentUser) -> dict[str, int]:
    participants = db.execute(
        select(ChatParticipant).where(
            ChatParticipant.user_id == user.id,
            ChatParticipant.archived.is_(False),
            ChatParticipant.deleted_at.is_(None),
        )
    ).scalars().all()
    total = 0
    for participant in participants:
        conversation = db.get(ChatConversation, participant.conversation_id)
        if not conversation or _is_blocked(db, conversation.buyer_id, conversation.seller_id):
            continue
        unread_stmt = select(func.count()).select_from(ChatMessage).where(
            ChatMessage.conversation_id == conversation.id,
            ChatMessage.sender_id != user.id,
            ChatMessage.deleted_at.is_(None),
        )
        if participant.last_read_at is not None:
            unread_stmt = unread_stmt.where(ChatMessage.created_at > participant.last_read_at)
        total += db.scalar(unread_stmt) or 0
    return {"count": total}


@router.get("/conversations/{conversation_id}", response_model=ConversationResponse)
def get_conversation(conversation_id: str, db: DBSession, user: CurrentUser) -> ConversationResponse:
    conversation, _ = _ensure_participant(db, conversation_id, user.id)
    _ensure_not_blocked(db, conversation)
    return _conversation_response(db, conversation, user.id)


@router.get("/conversations/{conversation_id}/messages", response_model=MessagePage)
def list_messages(
    conversation_id: str,
    db: DBSession,
    user: CurrentUser,
    before: datetime | None = None,
    limit: int = Query(50, ge=1, le=100),
) -> MessagePage:
    conversation, _ = _ensure_participant(db, conversation_id, user.id)
    _ensure_not_blocked(db, conversation)
    stmt = select(ChatMessage).where(
        ChatMessage.conversation_id == conversation.id,
        ChatMessage.deleted_at.is_(None),
    )
    if before:
        stmt = stmt.where(ChatMessage.created_at < before)
    rows = db.execute(stmt.order_by(ChatMessage.created_at.desc(), ChatMessage.id.desc()).limit(limit + 1)).scalars().all()
    has_more = len(rows) > limit
    rows = rows[:limit]
    next_cursor = rows[-1].created_at.isoformat() if has_more and rows else None
    rows.reverse()
    return MessagePage(
        items=[ChatMessageResponse.model_validate(row) for row in rows],
        next_cursor=next_cursor,
    )


@router.post("/conversations/{conversation_id}/messages", response_model=ChatMessageResponse, status_code=201)
def send_message(
    conversation_id: str,
    payload: ChatMessageCreate,
    bg: BackgroundTasks,
    db: DBSession,
    user: CurrentUser,
) -> ChatMessageResponse:
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before messaging")
    conversation, participant = _ensure_participant(db, conversation_id, user.id)
    _ensure_not_blocked(db, conversation)
    if conversation.status != "active":
        raise HTTPException(status_code=409, detail="Conversation is closed")

    duplicate = db.execute(
        select(ChatMessage).where(
            ChatMessage.sender_id == user.id,
            ChatMessage.client_message_id == payload.client_message_id,
        )
    ).scalar_one_or_none()
    if duplicate:
        if duplicate.conversation_id != conversation.id:
            raise HTTPException(status_code=409, detail="client_message_id already used")
        return ChatMessageResponse.model_validate(duplicate)

    sent_last_minute = db.scalar(
        select(func.count()).select_from(ChatMessage).where(
            ChatMessage.sender_id == user.id,
            ChatMessage.created_at >= _now() - timedelta(minutes=1),
        )
    ) or 0
    if sent_last_minute >= 30:
        raise HTTPException(status_code=429, detail="Message rate limit exceeded")
    if len(_URL_PATTERN.findall(payload.body)) > 2:
        raise HTTPException(status_code=422, detail="Too many links in one message")

    message = ChatMessage(
        conversation_id=conversation.id,
        sender_id=user.id,
        client_message_id=payload.client_message_id,
        kind="text",
        body=payload.body,
    )
    now = _now()
    db.add(message)
    db.flush()
    conversation.last_message_preview = payload.body.replace("\n", " ")[:240]
    conversation.last_message_sender_id = user.id
    conversation.last_message_at = now
    participant.last_read_at = now
    participant.archived = False

    recipient_id = _other_user_id(conversation, user.id)
    recipient = db.execute(
        select(ChatParticipant).where(
            ChatParticipant.conversation_id == conversation.id,
            ChatParticipant.user_id == recipient_id,
        )
    ).scalar_one()
    recipient.archived = False

    listing = db.get(ServiceListing, conversation.listing_id) if conversation.listing_id else None
    if user.id == conversation.seller_id and listing and listing.response_time_hours is None:
        elapsed = max(1, math.ceil((now - _utc(conversation.created_at)).total_seconds() / 3600))
        listing.response_time_hours = min(elapsed, 24 * 14)

    sender_name = conversation.seller_name if user.id == conversation.seller_id else _display_name(user)
    if not recipient.muted:
        enqueue_chat_push(
            db,
            message_id=message.id,
            recipient_id=recipient_id,
            conversation_id=conversation.id,
            sender_name=sender_name,
            message_preview=payload.body,
        )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        duplicate = db.execute(
            select(ChatMessage).where(
                ChatMessage.sender_id == user.id,
                ChatMessage.client_message_id == payload.client_message_id,
            )
        ).scalar_one_or_none()
        if duplicate and duplicate.conversation_id == conversation.id:
            return ChatMessageResponse.model_validate(duplicate)
        raise
    db.refresh(message)
    CHAT_MESSAGES_SENT.labels(listing_type=conversation.listing_type, kind=message.kind).inc()
    response = ChatMessageResponse.model_validate(message)
    bg.add_task(
        chat_realtime.publish,
        recipient_id,
        {"type": "message.created", "conversation_id": conversation.id, "message": response.model_dump(mode="json")},
    )
    return response


@router.post("/conversations/{conversation_id}/read", response_model=MarketplaceSafetyResponse)
def mark_read(
    conversation_id: str,
    payload: ReadReceiptCreate,
    bg: BackgroundTasks,
    db: DBSession,
    user: CurrentUser,
) -> MarketplaceSafetyResponse:
    conversation, participant = _ensure_participant(db, conversation_id, user.id)
    _ensure_not_blocked(db, conversation)
    message = db.get(ChatMessage, payload.message_id)
    if not message or message.conversation_id != conversation.id:
        raise HTTPException(status_code=404, detail="Message not found")
    current_read = _utc(participant.last_read_at) if participant.last_read_at else _utc(message.created_at)
    participant.last_read_at = max(current_read, _utc(message.created_at))
    db.commit()
    bg.add_task(
        chat_realtime.publish,
        _other_user_id(conversation, user.id),
        {
            "type": "message.read",
            "conversation_id": conversation.id,
            "message_id": message.id,
            "reader_id": user.id,
            "read_at": participant.last_read_at.isoformat(),
        },
    )
    return MarketplaceSafetyResponse(message="Read receipt updated")


@router.patch("/conversations/{conversation_id}", response_model=ConversationResponse)
def update_conversation(
    conversation_id: str,
    payload: ConversationUpdate,
    db: DBSession,
    user: CurrentUser,
) -> ConversationResponse:
    conversation, participant = _ensure_participant(db, conversation_id, user.id)
    _ensure_not_blocked(db, conversation)
    if payload.muted is not None:
        participant.muted = payload.muted
    if payload.archived is not None:
        participant.archived = payload.archived
    db.commit()
    return _conversation_response(db, conversation, user.id)


@router.post("/conversations/{conversation_id}/close", response_model=ConversationResponse)
def close_deal(
    conversation_id: str,
    bg: BackgroundTasks,
    db: DBSession,
    user: CurrentUser,
) -> ConversationResponse:
    conversation, _ = _ensure_participant(db, conversation_id, user.id)
    _ensure_not_blocked(db, conversation)
    if user.id != conversation.seller_id:
        raise HTTPException(status_code=403, detail="Only listing owner can close a deal")
    if conversation.status == "closed":
        return _conversation_response(db, conversation, user.id)
    conversation.status = "closed"
    listing = db.get(ServiceListing, conversation.listing_id) if conversation.listing_id else None
    if listing:
        listing.status = "sold" if conversation.listing_type == "item" else "completed"
    message = ChatMessage(
        conversation_id=conversation.id,
        sender_id=user.id,
        client_message_id=f"system-close-{conversation.id}",
        kind="system",
        body="Угоду завершено. Тепер можна залишити відгук.",
    )
    db.add(message)
    db.flush()
    conversation.last_message_preview = message.body
    conversation.last_message_sender_id = user.id
    conversation.last_message_at = _now()
    buyer_participant = db.execute(
        select(ChatParticipant).where(
            ChatParticipant.conversation_id == conversation.id,
            ChatParticipant.user_id == conversation.buyer_id,
        )
    ).scalar_one()
    if not buyer_participant.muted:
        enqueue_chat_push(
            db,
            message_id=message.id,
            recipient_id=conversation.buyer_id,
            conversation_id=conversation.id,
            sender_name=conversation.seller_name,
            message_preview=message.body,
        )
    db.commit()
    db.refresh(message)
    CHAT_MESSAGES_SENT.labels(listing_type=conversation.listing_type, kind=message.kind).inc()
    CHAT_DEALS_CLOSED.labels(listing_type=conversation.listing_type).inc()
    bg.add_task(
        chat_realtime.publish,
        conversation.buyer_id,
        {
            "type": "conversation.closed",
            "conversation_id": conversation.id,
            "message": ChatMessageResponse.model_validate(message).model_dump(mode="json"),
        },
    )
    return _conversation_response(db, conversation, user.id)


@router.post("/conversations/{conversation_id}/review", response_model=MarketplaceSafetyResponse, status_code=201)
def review_deal(
    conversation_id: str,
    payload: ChatReviewCreate,
    db: DBSession,
    user: CurrentUser,
) -> MarketplaceSafetyResponse:
    conversation, _ = _ensure_participant(db, conversation_id, user.id)
    if conversation.status != "closed":
        raise HTTPException(status_code=409, detail="Close the deal before reviewing")
    existing = db.execute(
        select(MarketplaceReview).where(
            MarketplaceReview.conversation_id == conversation.id,
            MarketplaceReview.reviewer_id == user.id,
        )
    ).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Review already submitted")
    db.add(
        MarketplaceReview(
            conversation_id=conversation.id,
            reviewer_id=user.id,
            reviewed_user_id=_other_user_id(conversation, user.id),
            rating=payload.rating,
            comment=payload.comment.strip() if payload.comment else None,
        )
    )
    db.commit()
    CHAT_REVIEWS_CREATED.labels(listing_type=conversation.listing_type).inc()
    return MarketplaceSafetyResponse(message="Review submitted")


@router.post("/messages/{message_id}/report", response_model=MarketplaceSafetyResponse)
def report_message(
    message_id: str,
    payload: ChatReportCreate,
    db: DBSession,
    user: CurrentUser,
) -> MarketplaceSafetyResponse:
    message = db.get(ChatMessage, message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    _conversation, _ = _ensure_participant(db, message.conversation_id, user.id)
    if message.sender_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot report your own message")
    existing = db.execute(
        select(ChatMessageReport).where(
            ChatMessageReport.message_id == message.id,
            ChatMessageReport.reporter_id == user.id,
        )
    ).scalar_one_or_none()
    if not existing:
        db.add(
            ChatMessageReport(
                message_id=message.id,
                reporter_id=user.id,
                reason=payload.reason,
                details=payload.details.strip() if payload.details else None,
            )
        )
        db.commit()
        CHAT_SAFETY_ACTIONS.labels(action="message_report").inc()
    return MarketplaceSafetyResponse(message="Report received for moderation")


@router.post("/conversations/{conversation_id}/block", response_model=MarketplaceSafetyResponse)
def block_chat_user(conversation_id: str, db: DBSession, user: CurrentUser) -> MarketplaceSafetyResponse:
    conversation, participant = _ensure_participant(db, conversation_id, user.id)
    other_id = _other_user_id(conversation, user.id)
    existing = db.execute(
        select(MarketplaceBlock).where(
            MarketplaceBlock.user_id == user.id,
            MarketplaceBlock.blocked_author_id == other_id,
        )
    ).scalar_one_or_none()
    if not existing:
        db.add(MarketplaceBlock(user_id=user.id, blocked_author_id=other_id))
    participant.archived = True
    db.commit()
    CHAT_SAFETY_ACTIONS.labels(action="user_block").inc()
    return MarketplaceSafetyResponse(message="User blocked")


@devices_router.post("/push", response_model=PushDeviceResponse)
def register_push_device(payload: PushDeviceCreate, db: DBSession, user: CurrentUser) -> PushDeviceResponse:
    token = payload.token.lower()
    device = db.execute(select(PushDevice).where(PushDevice.token == token)).scalar_one_or_none()
    if device:
        if device.user_id != user.id:
            raise HTTPException(status_code=409, detail="Push token is already bound to another account")
        device.environment = payload.environment
        device.enabled = True
        device.revoked_at = None
        device.last_seen_at = _now()
    else:
        device = PushDevice(user_id=user.id, token=token, environment=payload.environment)
        db.add(device)
    db.commit()
    db.refresh(device)
    return PushDeviceResponse(id=device.id, enabled=device.enabled)


@devices_router.delete("/push/{token}", status_code=204)
def unregister_push_device(token: str, db: DBSession, user: CurrentUser) -> None:
    device = db.execute(
        select(PushDevice).where(PushDevice.token == token.lower(), PushDevice.user_id == user.id)
    ).scalar_one_or_none()
    if device:
        device.enabled = False
        device.revoked_at = _now()
        db.commit()


@router.websocket("/ws")
async def chat_websocket(websocket: WebSocket) -> None:
    if not get_settings().CHAT_ENABLED:
        await websocket.close(code=1013, reason="Chat is temporarily unavailable")
        return
    authorization = websocket.headers.get("authorization", "")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise ValueError("Access token required")
        user_id = str(payload["sub"])
        with SessionLocal() as db:
            user = UserService.get_by_id(db, user_id)
            if not user or not user.is_active:
                raise ValueError("Inactive user")
    except Exception:  # noqa: BLE001 - websocket authentication rejects every malformed token variant
        await websocket.close(code=4401, reason="Invalid authentication")
        return

    await chat_realtime.connect(user_id, websocket)
    try:
        await websocket.send_json({"type": "connected"})
        while True:
            incoming = await websocket.receive_json()
            event_type = incoming.get("type")
            if event_type == "ping":
                await websocket.send_json({"type": "pong"})
                continue
            if event_type != "typing":
                continue
            conversation_id = str(incoming.get("conversation_id", ""))
            with SessionLocal() as db:
                conversation = db.get(ChatConversation, conversation_id)
                if not conversation or user_id not in _participant_ids(conversation):
                    continue
                if _is_blocked(db, conversation.buyer_id, conversation.seller_id):
                    continue
                recipient_id = _other_user_id(conversation, user_id)
            await chat_realtime.publish(
                recipient_id,
                {
                    "type": "typing",
                    "conversation_id": conversation_id,
                    "user_id": user_id,
                    "is_typing": bool(incoming.get("is_typing")),
                },
            )
    except WebSocketDisconnect:
        pass
    finally:
        await chat_realtime.disconnect(user_id, websocket)


@admin_router.get("/chat/reports", response_model=list[AdminChatReportResponse])
def admin_chat_reports(
    db: DBSession,
    _: CurrentAdmin,
    report_status: str = Query("open", alias="status", pattern="^(open|resolved|dismissed)$"),
    limit: int = Query(50, ge=1, le=100),
) -> list[AdminChatReportResponse]:
    reports = db.execute(
        select(ChatMessageReport)
        .where(ChatMessageReport.status == report_status)
        .order_by(ChatMessageReport.created_at.desc())
        .limit(limit)
    ).scalars().all()
    output: list[AdminChatReportResponse] = []
    for report in reports:
        message = db.get(ChatMessage, report.message_id)
        if not message:
            continue
        context = db.execute(
            select(ChatMessage)
            .where(ChatMessage.conversation_id == message.conversation_id)
            .order_by(ChatMessage.created_at.desc())
            .limit(10)
        ).scalars().all()
        context.reverse()
        output.append(
            AdminChatReportResponse(
                id=report.id,
                status=report.status,
                reason=report.reason,
                details=report.details,
                created_at=report.created_at,
                reporter_id=report.reporter_id,
                message=ChatMessageResponse.model_validate(message),
                context=[ChatMessageResponse.model_validate(item) for item in context],
            )
        )
    return output


@admin_router.patch("/chat/reports/{report_id}", response_model=MarketplaceSafetyResponse)
def resolve_chat_report(
    report_id: str,
    payload: AdminChatReportUpdate,
    db: DBSession,
    admin: CurrentAdmin,
) -> MarketplaceSafetyResponse:
    report = db.get(ChatMessageReport, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    report.status = payload.status
    report.resolved_by = str(admin["sub"])
    report.resolved_at = _now()
    db.commit()
    return MarketplaceSafetyResponse(message="Report updated")
