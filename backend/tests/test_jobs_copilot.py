from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timezone

import httpx
from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models.job import Job
from backend.app.services.jobs_aggregator import (
    NormalizedJob,
    _fetch_jooble,
    _salary_currency,
    _upsert_jobs,
    job_fingerprint,
)
from backend.app.services.users import UserService

client = TestClient(app)


def test_salary_currency_preserves_provider_currency() -> None:
    assert _salary_currency("€ 33 - € 36 pro Stunde") == "EUR"
    assert _salary_currency("CHF 95'000 pro Jahr") == "CHF"
    assert _salary_currency("$ 120,000 per year") == "USD"


def test_jooble_uses_localized_api_endpoint(monkeypatch) -> None:
    requests: list[httpx.Request] = []

    async def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, json={"totalCount": 0, "jobs": []})

    monkeypatch.setenv("JOOBLE_API_KEY", "test-key")
    monkeypatch.setenv("JOOBLE_SYNC_QUERIES", "it")
    monkeypatch.setenv("JOOBLE_SYNC_PAGES", "1")
    monkeypatch.setenv("JOOBLE_RESULTS_PER_PAGE", "10")
    monkeypatch.delenv("JOOBLE_API_BASE_URL", raising=False)

    async def run() -> list[NormalizedJob]:
        transport = httpx.MockTransport(handler)
        async with httpx.AsyncClient(transport=transport) as api_client:
            return await _fetch_jooble(api_client)

    assert asyncio.run(run()) == []
    assert requests[0].url == "https://de.jooble.org/api/test-key"


def _identity(*, admin: bool = False) -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"jobs_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
        return {"Authorization": f"Bearer {token}"}, user.id


def _catalog_job(*, suffix: str = "external") -> str:
    with SessionLocal() as db:
        now = datetime.now(timezone.utc)
        job = Job(
            source="greenhouse",
            source_job_id=f"{suffix}-{uuid.uuid4().hex}",
            canonical_url=f"https://example.com/jobs/{suffix}",
            apply_url=f"https://example.com/jobs/{suffix}/apply",
            title="Junior Product Designer",
            company="Swiss Product AG",
            description="Junior product design role. No experience required. German and English.",
            snippet="Junior product design role",
            location="Zürich, ZH",
            canton="ZH",
            latitude=47.3769,
            longitude=8.5417,
            employment_type="full",
            workplace_type="hybrid",
            salary_min=85_000,
            salary_max=105_000,
            salary_period="year",
            languages=["de", "en"],
            skills=["figma", "research"],
            no_experience_required=True,
            degree_required=False,
            status="active",
            is_verified=True,
            posted_at=now,
            last_seen_at=now,
        )
        db.add(job)
        db.commit()
        db.refresh(job)
        return job.id


def test_catalog_search_filters_and_health_state() -> None:
    headers, _ = _identity()
    job_id = _catalog_job(suffix="search")
    response = client.get(
        "/api/v1/jobs/search",
        headers=headers,
        params={
            "q": "Product Designer",
            "canton": "ZH",
            "no_experience": True,
            "no_degree": True,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["catalog_status"] == "ready"
    assert job_id in {item["id"] for item in body["items"]}
    assert body["pages"] >= 1
    assert body["sources"]["greenhouse"] >= 1
    selected = next(item for item in body["items"] if item["id"] == job_id)
    assert selected["salary_period"] == "year"


def test_catalog_search_requires_registration() -> None:
    response = client.get("/api/v1/jobs/search", params={"q": "designer"})
    assert response.status_code == 401


def test_cross_provider_jobs_are_deduplicated_by_fingerprint() -> None:
    suffix = uuid.uuid4().hex
    title = f"Data Engineer {suffix}"
    first = NormalizedJob(
        source="greenhouse:test",
        source_job_id=f"greenhouse-{suffix}",
        title=title,
        company="Sweezy Data AG",
        location="Bern, BE",
        apply_url=f"https://greenhouse.example/jobs/{suffix}",
    )
    second = NormalizedJob(
        source="lever:test",
        source_job_id=f"lever-{suffix}",
        title=title,
        company="Sweezy Data AG",
        location="Bern, BE",
        apply_url=f"https://lever.example/jobs/{suffix}",
    )
    with SessionLocal() as db:
        now = datetime.now(timezone.utc)
        _upsert_jobs(db, [first], now)
        db.commit()
        _upsert_jobs(db, [second], now)
        db.commit()
        count = (
            db.query(Job)
            .filter(
                Job.dedupe_key == job_fingerprint(title, "Sweezy Data AG", "Bern, BE")
            )
            .count()
        )
        assert count == 1


def test_provider_sync_tolerates_existing_cross_provider_duplicates() -> None:
    suffix = uuid.uuid4().hex
    canonical_url = f"https://example.com/duplicate/{suffix}"
    with SessionLocal() as db:
        for source in ("legacy:first", "legacy:second"):
            db.add(
                Job(
                    source=source,
                    source_job_id=f"{source}-{suffix}",
                    canonical_url=canonical_url,
                    apply_url=canonical_url,
                    title=f"Legacy duplicate {suffix}",
                )
            )
        db.commit()

        count, _ = _upsert_jobs(
            db,
            [
                NormalizedJob(
                    source="jooble",
                    source_job_id=f"jooble-{suffix}",
                    title=f"Updated duplicate {suffix}",
                    company="Sweezy AG",
                    location="Zürich, ZH",
                    apply_url=canonical_url,
                )
            ],
            datetime.now(timezone.utc),
        )

        assert count == 1


def test_server_favorite_tracker_alert_and_report() -> None:
    headers, _ = _identity()
    job_id = _catalog_job(suffix="copilot")
    with SessionLocal() as db:
        job = db.get(Job, job_id)
        assert job is not None
        job.translations = {"uk": "Перекладений опис вакансії"}
        db.commit()
    detail = client.get(f"/api/v1/jobs/{job_id}").json()

    translation = client.post(
        f"/api/v1/jobs/{job_id}/translation",
        headers=headers,
        json={"language": "uk"},
    )
    assert translation.status_code == 200, translation.text
    assert translation.json()["cached"] is True

    favorite_payload = {
        "job_id": job_id,
        "source": detail["source"],
        "title": detail["title"],
        "company": detail["company"],
        "location": detail["location"],
        "canton": detail["canton"],
        "url": detail["url"],
    }
    favorite = client.post(
        "/api/v1/jobs/favorites", headers=headers, json=favorite_payload
    )
    assert favorite.status_code == 201, favorite.text
    assert (
        client.post(
            "/api/v1/jobs/favorites", headers=headers, json=favorite_payload
        ).status_code
        == 201
    )

    invalid_start = client.put(
        f"/api/v1/jobs/applications/{job_id}",
        headers=headers,
        json={"job_id": job_id, "status": "applied"},
    )
    assert invalid_start.status_code == 409
    saved = client.put(
        f"/api/v1/jobs/applications/{job_id}",
        headers=headers,
        json={"job_id": job_id, "status": "saved"},
    )
    assert saved.status_code == 200, saved.text
    assert saved.json()["job_title"] == "Junior Product Designer"
    applied = client.put(
        f"/api/v1/jobs/applications/{job_id}",
        headers=headers,
        json={"job_id": job_id, "status": "applied"},
    )
    assert applied.status_code == 200, applied.text
    assert applied.json()["applied_at"] is not None

    alert = client.post(
        "/api/v1/jobs/alerts",
        headers=headers,
        json={
            "name": "Design ZH",
            "keywords": "product designer",
            "canton": "ZH",
            "enabled": True,
        },
    )
    assert alert.status_code == 201, alert.text
    duplicate_alert = client.post(
        "/api/v1/jobs/alerts",
        headers=headers,
        json={
            "name": "Duplicate",
            "keywords": "product designer",
            "canton": "ZH",
            "enabled": True,
        },
    )
    assert duplicate_alert.status_code == 201
    assert duplicate_alert.json()["id"] == alert.json()["id"]
    assert (
        client.get("/api/v1/jobs/alerts", headers=headers).json()[0]["id"]
        == alert.json()["id"]
    )

    report = client.post(
        f"/api/v1/jobs/{job_id}/report", headers=headers, json={"reason": "suspicious"}
    )
    duplicate = client.post(
        f"/api/v1/jobs/{job_id}/report", headers=headers, json={"reason": "suspicious"}
    )
    assert report.status_code == 201
    assert duplicate.status_code == 201

    admin, _ = _identity(admin=True)
    reports = client.get("/api/v1/admin/jobs/reports", headers=admin)
    assert reports.status_code == 200, reports.text
    selected_report = next(item for item in reports.json() if item["job_id"] == job_id)
    resolved = client.post(
        f"/api/v1/admin/jobs/reports/{selected_report['id']}/resolve", headers=admin
    )
    assert resolved.status_code == 200, resolved.text
    assert resolved.json()["status"] == "resolved"


def test_employer_moderation_and_direct_job_chat() -> None:
    employer, employer_id = _identity()
    candidate, _ = _identity()
    admin, _ = _identity(admin=True)

    profile = client.put(
        "/api/v1/jobs/employer/profile",
        headers=employer,
        json={
            "company_name": "Sweezy Test AG",
            "canton": "ZH",
            "contact_name": "Hiring Team",
            "contact_email": "jobs@example.com",
            "description": "Verified test employer profile",
        },
    )
    assert profile.status_code == 200, profile.text
    assert profile.json()["is_verified"] is False

    verified = client.post(
        f"/api/v1/admin/jobs/employers/{employer_id}/verify", headers=admin
    )
    assert verified.status_code == 200, verified.text

    created = client.post(
        "/api/v1/jobs/employer/jobs",
        headers=employer,
        json={
            "title": "Customer Success Specialist",
            "description": "Support customers in German and English across Switzerland with clear onboarding processes.",
            "location": "Zürich",
            "canton": "ZH",
            "employment_type": "full",
            "workplace_type": "hybrid",
            "workload_min": 80,
            "workload_max": 100,
            "salary_min": 75_000,
            "salary_max": 90_000,
            "salary_period": "year",
            "languages": ["de", "en"],
            "skills": ["support", "crm"],
            "permit_requirements": ["B", "C"],
        },
    )
    assert created.status_code == 201, created.text
    job_id = created.json()["id"]
    assert created.json()["status"] == "pending"

    approved = client.post(f"/api/v1/admin/jobs/{job_id}/approve", headers=admin)
    assert approved.status_code == 200, approved.text
    assert approved.json()["can_message"] is True

    saved = client.put(
        f"/api/v1/jobs/applications/{job_id}",
        headers=candidate,
        json={"job_id": job_id, "status": "saved"},
    )
    assert saved.status_code == 200, saved.text
    applied = client.put(
        f"/api/v1/jobs/applications/{job_id}",
        headers=candidate,
        json={"job_id": job_id, "status": "applied"},
    )
    assert applied.status_code == 200, applied.text
    employer_inbox = client.get("/api/v1/jobs/employer/applications", headers=employer)
    assert employer_inbox.status_code == 200, employer_inbox.text
    employer_application = next(
        item for item in employer_inbox.json() if item["job_id"] == job_id
    )
    assert employer_application["candidate_email"].endswith("@example.com")
    interview = client.put(
        f"/api/v1/jobs/employer/applications/{employer_application['id']}",
        headers=employer,
        json={"status": "interview"},
    )
    assert interview.status_code == 200, interview.text
    assert interview.json()["status"] == "interview"

    conversation = client.post(
        f"/api/v1/chat/conversations/jobs/{job_id}", headers=candidate
    )
    assert conversation.status_code == 201, conversation.text
    assert conversation.json()["job_id"] == job_id
    assert conversation.json()["other_user_id"] == employer_id
    duplicate = client.post(
        f"/api/v1/chat/conversations/jobs/{job_id}", headers=candidate
    )
    assert duplicate.status_code == 201
    assert duplicate.json()["id"] == conversation.json()["id"]
