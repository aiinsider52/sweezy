from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, model_validator


class JobItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    source: str
    title: str
    company: str | None = None
    location: str | None = None
    canton: str | None = None
    url: str
    posted_at: datetime | None = None
    employment_type: str | None = None
    workplace_type: str | None = None
    workload_min: int | None = None
    workload_max: int | None = None
    salary: str | None = None
    salary_min: int | None = None
    salary_max: int | None = None
    salary_currency: str = "CHF"
    salary_period: str | None = None
    snippet: str | None = None
    description: str | None = None
    languages: list[str] = Field(default_factory=list)
    skills: list[str] = Field(default_factory=list)
    permit_requirements: list[str] = Field(default_factory=list)
    experience_level: str | None = None
    no_experience_required: bool = False
    degree_required: bool = False
    recognition_required: bool = False
    latitude: float | None = None
    longitude: float | None = None
    is_verified: bool = False
    is_promoted: bool = False
    can_message: bool = False
    status: str = "active"
    freshness: Literal["fresh", "recent", "stale"] = "fresh"
    expires_at: datetime | None = None


class ProviderHealth(BaseModel):
    provider: str
    configured: bool
    status: str
    last_success_at: datetime | None = None
    last_item_count: int = 0
    message: str | None = None


class JobSearchResponse(BaseModel):
    items: list[JobItem]
    total: int
    page: int = 1
    per_page: int = 20
    pages: int = 1
    sources: dict[str, int] = Field(default_factory=dict)
    catalog_status: Literal["ready", "empty", "source_unavailable", "stale"] = "ready"
    is_stale: bool = False
    providers: list[ProviderHealth] = Field(default_factory=list)
    debug: dict[str, Any] | None = None


class JobFavoriteIn(BaseModel):
    job_id: str = Field(min_length=1, max_length=255)
    source: str = Field(min_length=1, max_length=40)
    title: str = Field(min_length=1, max_length=300)
    company: str | None = Field(None, max_length=250)
    location: str | None = Field(None, max_length=300)
    canton: str | None = Field(None, max_length=10)
    url: str = Field(min_length=1, max_length=1200)


class JobFavoriteOut(JobFavoriteIn):
    id: str
    created_at: datetime


class JobSearchEventOut(BaseModel):
    keyword: str
    canton: str | None = None
    count: int


JobApplicationStatus = Literal[
    "saved", "prepared", "applied", "interview", "offer", "rejected", "withdrawn"
]


class JobApplicationUpsert(BaseModel):
    job_id: str = Field(min_length=1, max_length=255)
    status: JobApplicationStatus
    notes: str | None = Field(None, max_length=2000)
    cover_letter: str | None = Field(None, max_length=20_000)
    next_action_at: datetime | None = None


class JobApplicationOut(JobApplicationUpsert):
    model_config = ConfigDict(from_attributes=True)
    id: str
    job_title: str
    company: str | None = None
    location: str | None = None
    source: str
    job_url: str
    applied_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class EmployerApplicationOut(JobApplicationOut):
    candidate_id: str
    candidate_email: str


class EmployerApplicationStatusUpdate(BaseModel):
    status: Literal["interview", "offer", "rejected"]
    notes: str | None = Field(None, max_length=2000)


class JobAlertCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    keywords: str = Field(min_length=2, max_length=300)
    canton: str | None = Field(None, max_length=10)
    employment_type: str | None = Field(None, max_length=60)
    workplace_type: str | None = Field(None, max_length=30)
    min_salary: int | None = Field(None, ge=0, le=1_000_000)
    enabled: bool = True


class JobAlertOut(JobAlertCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    last_notified_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class JobMatchProfile(BaseModel):
    desired_position: str = Field(default="", max_length=300)
    skills: list[str] = Field(default_factory=list, max_length=100)
    canton: str | None = Field(None, max_length=10)
    employment_type: str | None = Field(None, max_length=60)
    remote: bool = False
    experience_level: str | None = Field(None, max_length=30)
    permit: str | None = Field(None, max_length=10)
    languages: list[str] = Field(default_factory=list, max_length=20)
    limit: int = Field(default=20, ge=1, le=50)


class JobMatchItem(BaseModel):
    job: JobItem
    score: int = Field(ge=0, le=100)
    reasons: list[str]
    missing: list[str]
    method: Literal["semantic", "explainable"]


class JobMatchResponse(BaseModel):
    items: list[JobMatchItem]
    method: Literal["semantic", "explainable"]
    profile_quality: int = Field(ge=0, le=100)


class JobReportCreate(BaseModel):
    reason: str = Field(min_length=2, max_length=40)
    details: str | None = Field(None, max_length=500)


class JobReportOut(JobReportCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    job_id: str
    reporter_id: str
    status: str
    created_at: datetime


class JobTranslationRequest(BaseModel):
    language: Literal["uk", "de", "en", "fr", "it"]


class JobTranslationOut(BaseModel):
    job_id: str
    language: str
    text: str
    cached: bool


class EmployerProfileUpsert(BaseModel):
    company_name: str = Field(min_length=2, max_length=250)
    website: HttpUrl | None = None
    canton: str = Field(min_length=2, max_length=10)
    contact_name: str = Field(min_length=2, max_length=150)
    contact_email: str = Field(min_length=3, max_length=255)
    description: str | None = Field(None, max_length=2000)


class EmployerProfileOut(EmployerProfileUpsert):
    model_config = ConfigDict(from_attributes=True)
    user_id: str
    is_verified: bool
    created_at: datetime
    updated_at: datetime


class EmployerJobCreate(BaseModel):
    title: str = Field(min_length=3, max_length=300)
    description: str = Field(min_length=30, max_length=30_000)
    location: str = Field(min_length=2, max_length=300)
    canton: str = Field(min_length=2, max_length=10)
    employment_type: str | None = Field(None, max_length=60)
    workplace_type: str | None = Field(None, max_length=30)
    workload_min: int | None = Field(None, ge=0, le=100)
    workload_max: int | None = Field(None, ge=0, le=100)
    salary_min: int | None = Field(None, ge=0, le=2_000_000)
    salary_max: int | None = Field(None, ge=0, le=2_000_000)
    salary_period: str | None = Field(None, max_length=20)
    languages: list[str] = Field(default_factory=list, max_length=20)
    skills: list[str] = Field(default_factory=list, max_length=100)
    permit_requirements: list[str] = Field(default_factory=list, max_length=20)
    experience_level: str | None = Field(None, max_length=30)
    no_experience_required: bool = False
    degree_required: bool = False
    recognition_required: bool = False
    apply_url: HttpUrl | None = None
    expires_at: datetime | None = None

    @model_validator(mode="after")
    def validate_ranges(self) -> EmployerJobCreate:
        if (
            self.workload_min is not None
            and self.workload_max is not None
            and self.workload_min > self.workload_max
        ):
            raise ValueError("workload_min cannot exceed workload_max")
        if (
            self.salary_min is not None
            and self.salary_max is not None
            and self.salary_min > self.salary_max
        ):
            raise ValueError("salary_min cannot exceed salary_max")
        return self
