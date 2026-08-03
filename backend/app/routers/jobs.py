from __future__ import annotations

import json
import math
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from ..core.rate_limit import limiter
from ..core.security import decode_token
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.chat import NotificationOutbox
from ..models.job import (
    Job,
    JobAlert,
    JobApplication,
    JobEmployerProfile,
    JobFavorite,
    JobReport,
    JobSearchEvent,
)
from ..models.user import User
from ..schemas.job import (
    EmployerApplicationOut,
    EmployerApplicationStatusUpdate,
    EmployerJobCreate,
    EmployerProfileOut,
    EmployerProfileUpsert,
    JobAlertCreate,
    JobAlertOut,
    JobApplicationOut,
    JobApplicationUpsert,
    JobFavoriteIn,
    JobFavoriteOut,
    JobItem,
    JobMatchProfile,
    JobMatchResponse,
    JobReportCreate,
    JobReportOut,
    JobSearchEventOut,
    JobSearchResponse,
    JobTranslationOut,
    JobTranslationRequest,
    ProviderHealth,
)
from ..services.jobs_aggregator import (
    job_fingerprint,
    job_to_item,
    match_jobs,
    provider_health,
    search_catalog,
    sync_jobs,
    translate_job_description,
)
from ..services.users import UserService

router = APIRouter()
admin_router = APIRouter()
_optional_bearer = HTTPBearer(auto_error=False)
FREE_FAVORITES_LIMIT = 3
MAX_JOB_ALERTS_PER_USER = 10
_APPLICATION_TRANSITIONS = {
    "saved": {"prepared", "applied", "withdrawn"},
    "prepared": {"saved", "applied", "withdrawn"},
    "applied": {"interview", "rejected", "withdrawn"},
    "interview": {"offer", "rejected", "withdrawn"},
    "offer": {"withdrawn"},
    "rejected": {"saved"},
    "withdrawn": {"saved"},
}


def _is_premium(user) -> bool:
    subscription = getattr(user, "subscription_status", "free") or "free"
    expire_at = getattr(user, "subscription_expire_at", None)
    if subscription not in {"trial", "premium"}:
        return False
    if expire_at is None:
        return True
    try:
        return expire_at > datetime.now(timezone.utc)
    except (TypeError, ValueError):
        return True


def _optional_user_id(
    db: DBSession,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(_optional_bearer)
    ],
) -> str | None:
    if credentials is None:
        return None
    try:
        payload = decode_token(credentials.credentials)
        user_id = payload.get("sub")
        user = UserService.get_by_id(db, user_id) if user_id else None
        return user.id if user and user.is_active else None
    except Exception:  # noqa: BLE001 - optional authentication must never break public catalog
        return None


@router.get("/search", response_model=JobSearchResponse)
@limiter.limit("60/minute")
def search(
    request: Request,
    db: DBSession,
    user: CurrentUser,
    q: str | None = Query(None, max_length=300),
    canton: str | None = Query(None, max_length=10),
    employment_type: str | None = Query(None, max_length=60),
    workplace_type: str | None = Query(None, pattern="^(remote|hybrid|on_site)$"),
    no_experience: bool | None = None,
    no_degree: bool | None = None,
    min_salary: int | None = Query(None, ge=0, le=1_000_000),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
) -> JobSearchResponse:
    items, total, sources, is_stale = search_catalog(
        db,
        q=q,
        canton=canton,
        employment_type=employment_type,
        workplace_type=workplace_type,
        no_experience=no_experience,
        no_degree=no_degree,
        min_salary=min_salary,
        page=page,
        per_page=per_page,
    )
    health = provider_health(db)
    configured = [item for item in health if item.configured]
    healthy = [item for item in configured if item.status in {"healthy", "syncing"}]
    catalog_status = "stale" if is_stale else "ready"
    if total == 0:
        catalog_status = "empty" if healthy else "source_unavailable"
    if q and q.strip():
        try:
            db.add(
                JobSearchEvent(
                    keyword=q.strip().lower(), canton=canton, result_count=total
                )
            )
            db.commit()
        except SQLAlchemyError:
            db.rollback()
    return JobSearchResponse(
        items=items,
        total=total,
        page=page,
        per_page=per_page,
        pages=max(1, math.ceil(total / per_page)),
        sources=sources,
        catalog_status=catalog_status,
        is_stale=is_stale,
        providers=health,
    )


@router.get("/sources", response_model=list[ProviderHealth])
def sources(db: DBSession) -> list[ProviderHealth]:
    return provider_health(db)


@router.post("/analytics/events", status_code=status.HTTP_204_NO_CONTENT)
def log_event(
    db: DBSession,
    keyword: str = Query(..., min_length=1, max_length=300),
    canton: str | None = None,
):
    try:
        db.add(JobSearchEvent(keyword=keyword.strip().lower(), canton=canton))
        db.commit()
    except SQLAlchemyError:
        db.rollback()


@router.get("/analytics/top", response_model=list[JobSearchEventOut])
def top_keywords(db: DBSession, limit: int = Query(10, ge=1, le=100)):
    rows = (
        db.query(
            JobSearchEvent.keyword, JobSearchEvent.canton, func.count().label("count")
        )
        .group_by(JobSearchEvent.keyword, JobSearchEvent.canton)
        .order_by(func.count().desc())
        .limit(limit)
        .all()
    )
    return [
        JobSearchEventOut(keyword=row[0], canton=row[1], count=row[2]) for row in rows
    ]


@router.get("/favorites", response_model=list[JobFavoriteOut])
def list_favorites(user: CurrentUser, db: DBSession):
    return (
        db.execute(
            select(JobFavorite)
            .where(JobFavorite.user_id == user.id)
            .order_by(JobFavorite.created_at.desc())
        )
        .scalars()
        .all()
    )


@router.post(
    "/favorites", response_model=JobFavoriteOut, status_code=status.HTTP_201_CREATED
)
def add_favorite(payload: JobFavoriteIn, user: CurrentUser, db: DBSession):
    existing = db.execute(
        select(JobFavorite).where(
            JobFavorite.user_id == user.id, JobFavorite.job_id == payload.job_id
        )
    ).scalar_one_or_none()
    if existing:
        return existing
    if not _is_premium(user):
        count = (
            db.scalar(
                select(func.count(JobFavorite.id)).where(JobFavorite.user_id == user.id)
            )
            or 0
        )
        if count >= FREE_FAVORITES_LIMIT:
            raise HTTPException(
                status_code=402, detail="Favorites limit reached for Free plan"
            )
    favorite = JobFavorite(user_id=user.id, **payload.model_dump())
    db.add(favorite)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.execute(
            select(JobFavorite).where(
                JobFavorite.user_id == user.id,
                JobFavorite.job_id == payload.job_id,
            )
        ).scalar_one_or_none()
        if existing:
            return existing
        raise
    db.refresh(favorite)
    return favorite


@router.delete("/favorites/by-job/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite_by_job(job_id: str, user: CurrentUser, db: DBSession):
    favorite = db.execute(
        select(JobFavorite).where(
            JobFavorite.user_id == user.id, JobFavorite.job_id == job_id
        )
    ).scalar_one_or_none()
    if favorite:
        db.delete(favorite)
        db.commit()


@router.delete("/favorites/{favorite_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(favorite_id: str, user: CurrentUser, db: DBSession):
    favorite = db.execute(
        select(JobFavorite).where(
            JobFavorite.id == favorite_id, JobFavorite.user_id == user.id
        )
    ).scalar_one_or_none()
    if not favorite:
        raise HTTPException(status_code=404, detail="Favorite not found")
    db.delete(favorite)
    db.commit()


@router.get("/applications", response_model=list[JobApplicationOut])
def list_applications(user: CurrentUser, db: DBSession):
    return (
        db.execute(
            select(JobApplication)
            .where(JobApplication.user_id == user.id)
            .order_by(JobApplication.updated_at.desc())
        )
        .scalars()
        .all()
    )


@router.put("/applications/{job_id}", response_model=JobApplicationOut)
def upsert_application(
    job_id: str, payload: JobApplicationUpsert, user: CurrentUser, db: DBSession
):
    if payload.job_id != job_id:
        raise HTTPException(status_code=400, detail="job_id does not match path")
    application = db.execute(
        select(JobApplication).where(
            JobApplication.user_id == user.id, JobApplication.job_id == job_id
        )
    ).scalar_one_or_none()
    if (
        application
        and payload.status != application.status
        and payload.status not in _APPLICATION_TRANSITIONS[application.status]
    ):
        raise HTTPException(
            status_code=409,
            detail=f"Invalid transition: {application.status} -> {payload.status}",
        )
    if application is None:
        if payload.status not in {"saved", "prepared"}:
            raise HTTPException(
                status_code=409,
                detail=f"Application must start as saved or prepared, not {payload.status}",
            )
        job = db.get(Job, job_id)
        if not job or job.status not in {"active", "closed", "expired"}:
            raise HTTPException(status_code=404, detail="Job not found")
        application = JobApplication(
            user_id=user.id,
            job_id=job_id,
            job_title=job.title,
            company=job.company,
            location=job.location,
            source=job.source,
            job_url=job.apply_url,
        )
        db.add(application)
    application.status = payload.status
    application.notes = payload.notes
    application.cover_letter = payload.cover_letter
    application.next_action_at = payload.next_action_at
    if payload.status == "applied" and application.applied_at is None:
        application.applied_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(application)
    return application


@router.delete("/applications/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_application(job_id: str, user: CurrentUser, db: DBSession):
    application = db.execute(
        select(JobApplication).where(
            JobApplication.user_id == user.id, JobApplication.job_id == job_id
        )
    ).scalar_one_or_none()
    if application:
        db.delete(application)
        db.commit()


@router.get("/alerts", response_model=list[JobAlertOut])
def list_alerts(user: CurrentUser, db: DBSession):
    return (
        db.execute(
            select(JobAlert)
            .where(JobAlert.user_id == user.id)
            .order_by(JobAlert.created_at.desc())
        )
        .scalars()
        .all()
    )


@router.post("/alerts", response_model=JobAlertOut, status_code=status.HTTP_201_CREATED)
def create_alert(payload: JobAlertCreate, user: CurrentUser, db: DBSession):
    existing = db.execute(
        select(JobAlert).where(
            JobAlert.user_id == user.id,
            func.lower(JobAlert.keywords) == payload.keywords.strip().lower(),
            JobAlert.canton == payload.canton,
            JobAlert.employment_type == payload.employment_type,
            JobAlert.workplace_type == payload.workplace_type,
        )
    ).scalar_one_or_none()
    if existing:
        return existing
    alert_count = (
        db.scalar(select(func.count(JobAlert.id)).where(JobAlert.user_id == user.id))
        or 0
    )
    if alert_count >= MAX_JOB_ALERTS_PER_USER:
        raise HTTPException(
            status_code=409,
            detail=f"Maximum {MAX_JOB_ALERTS_PER_USER} job alerts allowed",
        )
    alert = JobAlert(user_id=user.id, **payload.model_dump())
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert


@router.put("/alerts/{alert_id}", response_model=JobAlertOut)
def update_alert(
    alert_id: str, payload: JobAlertCreate, user: CurrentUser, db: DBSession
):
    alert = db.execute(
        select(JobAlert).where(JobAlert.id == alert_id, JobAlert.user_id == user.id)
    ).scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Job alert not found")
    for key, value in payload.model_dump().items():
        setattr(alert, key, value)
    db.commit()
    db.refresh(alert)
    return alert


@router.delete("/alerts/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_alert(alert_id: str, user: CurrentUser, db: DBSession):
    alert = db.execute(
        select(JobAlert).where(JobAlert.id == alert_id, JobAlert.user_id == user.id)
    ).scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Job alert not found")
    db.delete(alert)
    db.commit()


@router.post("/match", response_model=JobMatchResponse)
@limiter.limit("20/hour")
async def match(
    request: Request, payload: JobMatchProfile, user: CurrentUser, db: DBSession
):
    return await match_jobs(db, payload)


@router.post("/{job_id}/report", status_code=status.HTTP_201_CREATED)
@limiter.limit("10/hour")
def report_job(
    request: Request,
    job_id: str,
    payload: JobReportCreate,
    user: CurrentUser,
    db: DBSession,
):
    if db.get(Job, job_id) is None:
        raise HTTPException(status_code=404, detail="Job not found")
    existing = db.execute(
        select(JobReport).where(
            JobReport.job_id == job_id, JobReport.reporter_id == user.id
        )
    ).scalar_one_or_none()
    if existing:
        return {"ok": True, "message": "Report already received"}
    db.add(JobReport(job_id=job_id, reporter_id=user.id, **payload.model_dump()))
    db.commit()
    return {"ok": True, "message": "Report received"}


@router.post("/{job_id}/translation", response_model=JobTranslationOut)
@limiter.limit("10/hour")
async def translate_job(
    request: Request,
    job_id: str,
    payload: JobTranslationRequest,
    user: CurrentUser,
    db: DBSession,
) -> JobTranslationOut:
    job = db.get(Job, job_id)
    if not job or job.status != "active":
        raise HTTPException(status_code=404, detail="Job not found")
    try:
        text, cached = await translate_job_description(db, job, payload.language)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return JobTranslationOut(
        job_id=job.id, language=payload.language, text=text, cached=cached
    )


@router.put("/employer/profile", response_model=EmployerProfileOut)
def upsert_employer_profile(
    payload: EmployerProfileUpsert, user: CurrentUser, db: DBSession
):
    profile = db.get(JobEmployerProfile, user.id)
    if profile is None:
        profile = JobEmployerProfile(user_id=user.id, **payload.model_dump(mode="json"))
        db.add(profile)
    else:
        for key, value in payload.model_dump(mode="json").items():
            setattr(profile, key, value)
    db.commit()
    db.refresh(profile)
    return profile


@router.get("/employer/profile", response_model=EmployerProfileOut)
def get_employer_profile(user: CurrentUser, db: DBSession):
    profile = db.get(JobEmployerProfile, user.id)
    if not profile:
        raise HTTPException(status_code=404, detail="Employer profile not found")
    return profile


@router.post(
    "/employer/jobs", response_model=JobItem, status_code=status.HTTP_201_CREATED
)
@limiter.limit("20/day")
def create_employer_job(
    request: Request, payload: EmployerJobCreate, user: CurrentUser, db: DBSession
):
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before creating a job")
    profile = db.get(JobEmployerProfile, user.id)
    if not profile:
        raise HTTPException(status_code=409, detail="Create employer profile first")
    now = datetime.now(timezone.utc)
    job = Job(
        source="sweezy",
        source_job_id=f"pending:{user.id}:{int(now.timestamp() * 1000)}",
        dedupe_key=job_fingerprint(
            payload.title, profile.company_name, payload.location
        ),
        canonical_url=str(
            payload.apply_url or f"sweezy://jobs/pending/{int(now.timestamp())}"
        ),
        apply_url=str(payload.apply_url or "sweezy://jobs/apply"),
        title=payload.title,
        company=profile.company_name,
        description=payload.description,
        snippet=payload.description[:1200],
        location=payload.location,
        canton=payload.canton.upper(),
        employment_type=payload.employment_type,
        workplace_type=payload.workplace_type,
        workload_min=payload.workload_min,
        workload_max=payload.workload_max,
        salary_min=payload.salary_min,
        salary_max=payload.salary_max,
        salary_period=payload.salary_period,
        languages=payload.languages,
        skills=payload.skills,
        permit_requirements=payload.permit_requirements,
        experience_level=payload.experience_level,
        no_experience_required=payload.no_experience_required,
        degree_required=payload.degree_required,
        recognition_required=payload.recognition_required,
        employer_id=user.id,
        status="pending",
        is_verified=profile.is_verified,
        posted_at=now,
        last_seen_at=now,
        expires_at=payload.expires_at,
    )
    db.add(job)
    db.commit()
    db.refresh(job)
    return job_to_item(job)


@router.get("/employer/jobs", response_model=list[JobItem])
def list_employer_jobs(user: CurrentUser, db: DBSession):
    rows = (
        db.execute(
            select(Job)
            .where(Job.employer_id == user.id)
            .order_by(Job.created_at.desc())
        )
        .scalars()
        .all()
    )
    return [job_to_item(row) for row in rows]


@router.get("/employer/applications", response_model=list[EmployerApplicationOut])
def list_employer_applications(user: CurrentUser, db: DBSession):
    rows = db.execute(
        select(JobApplication, User)
        .join(Job, Job.id == JobApplication.job_id)
        .join(User, User.id == JobApplication.user_id)
        .where(
            Job.employer_id == user.id,
            JobApplication.status.in_(
                ("applied", "interview", "offer", "rejected", "withdrawn")
            ),
        )
        .order_by(JobApplication.updated_at.desc())
    ).all()
    return [
        EmployerApplicationOut.model_validate(
            {
                **application.__dict__,
                "candidate_id": candidate.id,
                "candidate_email": candidate.email,
            }
        )
        for application, candidate in rows
    ]


@router.put(
    "/employer/applications/{application_id}", response_model=EmployerApplicationOut
)
def update_employer_application(
    application_id: str,
    payload: EmployerApplicationStatusUpdate,
    user: CurrentUser,
    db: DBSession,
):
    row = db.execute(
        select(JobApplication, User)
        .join(Job, Job.id == JobApplication.job_id)
        .join(User, User.id == JobApplication.user_id)
        .where(JobApplication.id == application_id, Job.employer_id == user.id)
    ).one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Application not found")
    application, candidate = row
    if (
        payload.status != application.status
        and payload.status not in _APPLICATION_TRANSITIONS[application.status]
    ):
        raise HTTPException(
            status_code=409,
            detail=f"Invalid transition: {application.status} -> {payload.status}",
        )
    application.status = payload.status
    application.notes = payload.notes
    event_key = f"job_application:{application.id}:{payload.status}"
    if not db.scalar(
        select(func.count(NotificationOutbox.id)).where(
            NotificationOutbox.event_key == event_key
        )
    ):
        titles = {
            "interview": "Запрошення на співбесіду",
            "offer": "Нова пропозиція роботи",
            "rejected": "Статус заявки оновлено",
        }
        body = {
            "interview": f"{application.company or 'Роботодавець'} запрошує вас на співбесіду.",
            "offer": f"{application.company or 'Роботодавець'} надіслав пропозицію.",
            "rejected": f"{application.company or 'Роботодавець'} завершив розгляд заявки.",
        }
        db.add(
            NotificationOutbox(
                event_key=event_key,
                recipient_id=application.user_id,
                event_type="job_application_status",
                payload_json=json.dumps(
                    {
                        "aps": {
                            "alert": {
                                "title": titles[payload.status],
                                "body": body[payload.status],
                            },
                            "sound": "default",
                        },
                        "type": "job_application_status",
                        "job_id": application.job_id,
                        "application_id": application.id,
                        "status": payload.status,
                    },
                    ensure_ascii=False,
                ),
            )
        )
    db.commit()
    db.refresh(application)
    return EmployerApplicationOut.model_validate(
        {
            **application.__dict__,
            "candidate_id": candidate.id,
            "candidate_email": candidate.email,
        }
    )


@router.put("/employer/jobs/{job_id}", response_model=JobItem)
def update_employer_job(
    job_id: str, payload: EmployerJobCreate, user: CurrentUser, db: DBSession
):
    job = db.get(Job, job_id)
    if not job or job.employer_id != user.id:
        raise HTTPException(status_code=404, detail="Job not found")
    description_changed = job.description != payload.description
    for key, value in payload.model_dump(
        mode="json", exclude={"apply_url", "expires_at"}
    ).items():
        setattr(job, key, value)
    if description_changed:
        job.translations = {}
    job.dedupe_key = job_fingerprint(payload.title, job.company, payload.location)
    job.apply_url = str(payload.apply_url or job.apply_url)
    job.expires_at = payload.expires_at
    job.status = "pending"
    job.moderation_notes = None
    db.commit()
    db.refresh(job)
    return job_to_item(job)


@router.delete("/employer/jobs/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_employer_job(job_id: str, user: CurrentUser, db: DBSession):
    job = db.get(Job, job_id)
    if not job or job.employer_id != user.id:
        raise HTTPException(status_code=404, detail="Job not found")
    job.status = "closed"
    db.commit()


@router.get("/{job_id}", response_model=JobItem)
def get_job(
    job_id: str, db: DBSession, user_id: str | None = Depends(_optional_user_id)
):
    job = db.get(Job, job_id)
    if not job or (job.status != "active" and job.employer_id != user_id):
        raise HTTPException(status_code=404, detail="Job not found")
    return job_to_item(job)


@admin_router.post("/sync")
async def sync_catalog(
    admin: CurrentAdmin,
    db: DBSession,
    provider: Annotated[list[str] | None, Query()] = None,
):
    return await sync_jobs(db, provider_names=provider)


@admin_router.get("/sources", response_model=list[ProviderHealth])
def admin_sources(admin: CurrentAdmin, db: DBSession):
    return provider_health(db, include_errors=True)


@admin_router.get("/reports", response_model=list[JobReportOut])
def job_reports(
    admin: CurrentAdmin,
    db: DBSession,
    report_status: str = Query("open", alias="status"),
):
    return (
        db.execute(
            select(JobReport)
            .where(JobReport.status == report_status)
            .order_by(JobReport.created_at.desc())
        )
        .scalars()
        .all()
    )


@admin_router.post("/reports/{report_id}/resolve", response_model=JobReportOut)
def resolve_job_report(report_id: str, admin: CurrentAdmin, db: DBSession):
    report = db.get(JobReport, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    report.status = "resolved"
    db.commit()
    db.refresh(report)
    return report


@admin_router.get("/employers", response_model=list[EmployerProfileOut])
def employers(admin: CurrentAdmin, db: DBSession, verified: bool | None = None):
    query = select(JobEmployerProfile).order_by(JobEmployerProfile.created_at.desc())
    if verified is not None:
        query = query.where(JobEmployerProfile.is_verified.is_(verified))
    return db.execute(query).scalars().all()


@admin_router.get("/pending", response_model=list[JobItem])
def pending_jobs(admin: CurrentAdmin, db: DBSession):
    rows = (
        db.execute(select(Job).where(Job.status == "pending").order_by(Job.created_at))
        .scalars()
        .all()
    )
    return [job_to_item(row) for row in rows]


@admin_router.post("/{job_id}/approve", response_model=JobItem)
def approve_job(job_id: str, admin: CurrentAdmin, db: DBSession):
    job = db.get(Job, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    job.status = "active"
    job.is_verified = True
    job.last_seen_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(job)
    return job_to_item(job)


@admin_router.post("/{job_id}/reject", response_model=JobItem)
def reject_job(
    job_id: str,
    admin: CurrentAdmin,
    db: DBSession,
    reason: str = Query(..., min_length=2, max_length=500),
):
    job = db.get(Job, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    job.status = "rejected"
    job.moderation_notes = reason
    db.commit()
    db.refresh(job)
    return job_to_item(job)


@admin_router.post("/employers/{user_id}/verify", response_model=EmployerProfileOut)
def verify_employer(user_id: str, admin: CurrentAdmin, db: DBSession):
    profile = db.get(JobEmployerProfile, user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Employer profile not found")
    profile.is_verified = True
    for job in (
        db.execute(select(Job).where(Job.employer_id == user_id)).scalars().all()
    ):
        job.is_verified = True
    db.commit()
    db.refresh(profile)
    return profile
