from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select

from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.expert_question import ExpertQuestion
from ..models.marketplace import ServiceListing
from ..schemas.expert import (
    ExpertQuestionAnswer,
    ExpertQuestionCreate,
    ExpertQuestionResponse,
    ExpertSpecialty,
)
from ..schemas.marketplace import ServiceListingDetail


router = APIRouter()
admin_router = APIRouter()


# ── Public expert directory ─────────────────────────────────────────────────


@router.get("/", response_model=list[ServiceListingDetail])
def list_experts(
    db: DBSession,
    specialty: Optional[ExpertSpecialty] = None,
    language: Optional[str] = Query(None, max_length=10),
    canton: Optional[str] = Query(None, max_length=10),
) -> list[ServiceListingDetail]:
    stmt = (
        select(ServiceListing)
        .where(ServiceListing.is_expert.is_(True))
        .where(ServiceListing.status == "approved")
    )
    if specialty:
        stmt = stmt.where(ServiceListing.expert_specialty == specialty.value)
    if canton:
        stmt = stmt.where(ServiceListing.canton == canton)
    stmt = stmt.order_by(ServiceListing.is_featured.desc(), ServiceListing.created_at.desc())

    rows = db.execute(stmt).scalars().all()

    if language:
        lang = language.lower()
        rows = [r for r in rows if lang in (r.expert_languages or [])]

    return [ServiceListingDetail.model_validate(r) for r in rows]


@router.get("/{listing_id}/questions", response_model=list[ExpertQuestionResponse])
def list_answered_questions(listing_id: str, db: DBSession) -> list[ExpertQuestionResponse]:
    rows = (
        db.query(ExpertQuestion)
        .filter(ExpertQuestion.listing_id == listing_id)
        .filter(ExpertQuestion.status == "answered")
        .order_by(ExpertQuestion.answered_at.desc())
        .limit(50)
        .all()
    )
    return [ExpertQuestionResponse.model_validate(r) for r in rows]


@router.post("/questions", response_model=ExpertQuestionResponse, status_code=status.HTTP_201_CREATED)
def ask_expert(payload: ExpertQuestionCreate, db: DBSession, user: CurrentUser) -> ExpertQuestionResponse:
    listing = db.get(ServiceListing, payload.listing_id)
    if not listing or listing.status != "approved" or not listing.is_expert:
        raise HTTPException(status_code=404, detail="Expert not found")

    q = ExpertQuestion(
        listing_id=listing.id,
        asked_by=user.id,
        asker_name=payload.asker_name,
        asker_language=payload.asker_language,
        question_text=payload.question_text.strip(),
        status="pending",
    )
    db.add(q)
    db.commit()
    db.refresh(q)
    return ExpertQuestionResponse.model_validate(q)


# ── Admin moderation ────────────────────────────────────────────────────────


@admin_router.get("/expert-questions", response_model=list[ExpertQuestionResponse])
def admin_list_questions(
    _: CurrentAdmin,
    db: DBSession,
    listing_id: Optional[str] = Query(None),
    question_status: Optional[str] = Query(None, alias="status"),
) -> list[ExpertQuestionResponse]:
    q = db.query(ExpertQuestion)
    if listing_id:
        q = q.filter(ExpertQuestion.listing_id == listing_id)
    if question_status:
        q = q.filter(ExpertQuestion.status == question_status)
    rows = q.order_by(ExpertQuestion.created_at.desc()).limit(200).all()
    return [ExpertQuestionResponse.model_validate(r) for r in rows]


@admin_router.patch("/expert-questions/{question_id}/answer", response_model=ExpertQuestionResponse)
def admin_answer_question(
    question_id: str,
    payload: ExpertQuestionAnswer,
    admin: CurrentAdmin,
    db: DBSession,
) -> ExpertQuestionResponse:
    q = db.get(ExpertQuestion, question_id)
    if not q:
        raise HTTPException(status_code=404, detail="Question not found")

    q.answer_text = payload.answer_text.strip()
    q.answered_at = datetime.utcnow()
    q.answered_by = admin.id
    q.status = "answered"
    db.add(q)
    db.commit()
    db.refresh(q)
    return ExpertQuestionResponse.model_validate(q)


@admin_router.patch("/expert-questions/{question_id}/reject", response_model=ExpertQuestionResponse)
def admin_reject_question(question_id: str, _: CurrentAdmin, db: DBSession) -> ExpertQuestionResponse:
    q = db.get(ExpertQuestion, question_id)
    if not q:
        raise HTTPException(status_code=404, detail="Question not found")
    q.status = "rejected"
    db.add(q)
    db.commit()
    db.refresh(q)
    return ExpertQuestionResponse.model_validate(q)


@admin_router.delete("/expert-questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_question(question_id: str, _: CurrentAdmin, db: DBSession) -> None:
    q = db.get(ExpertQuestion, question_id)
    if not q:
        raise HTTPException(status_code=404, detail="Question not found")
    db.delete(q)
    db.commit()
