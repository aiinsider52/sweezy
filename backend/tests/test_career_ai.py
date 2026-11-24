import json
import sys
import types
import uuid

from fastapi.testclient import TestClient

from backend.app.core.config import get_settings
from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models import PremiumUsage
from backend.app.routers.career_ai import _kit_schema
from backend.app.services.users import UserService


client = TestClient(app)
JOB = {"title": "Pflegefachfrau HF", "company": "Spital Zürich", "location": "Zürich",
       "description": "Wir suchen eine Pflegefachfrau mit Deutsch B2.", "languages": ["Deutsch B2"], "skills": ["Pflege"]}
CV = {"personal": {"fullName": "Olena K", "title": "Медсестра", "summary": "10 років у лікарні"},
      "experience": [{"role": "Медсестра", "company": "Лікарня №1", "period": "2014–2024", "achievements": "Хірургія"}],
      "languages": [{"name": "Deutsch", "level": "A2"}], "skills": ["Pflege"]}


def _headers() -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(db, email=f"career_{uuid.uuid4().hex}@example.com", password="StrongPass1!", email_verified=True)
        return {"Authorization": f"Bearer {create_access_token(subject=user.id, is_admin=False, role=user.role)}"}, user.id


def _fake_openai(monkeypatch, output: dict, captured: dict):
    monkeypatch.setattr(get_settings(), "OPENAI_API_KEY", "test-key")

    class Responses:
        def create(self, **kwargs):
            captured.update(kwargs)
            return types.SimpleNamespace(output_text=json.dumps(output))

    monkeypatch.setitem(sys.modules, "openai", types.SimpleNamespace(OpenAI=lambda api_key, **kwargs: types.SimpleNamespace(responses=Responses())))


def _usage(user_id: str, feature: str) -> int:
    with SessionLocal() as db:
        row = db.query(PremiumUsage).filter_by(user_id=user_id, feature=feature).one_or_none()
        return row.free_uses if row else 0


def test_kit_schema_is_strict_including_nested_gaps():
    schema = _kit_schema()
    assert schema["additionalProperties"] is False
    gap = next(iter(schema["$defs"].values()))
    assert gap["additionalProperties"] is False and set(gap["required"]) == {"title", "advice"}


def test_application_kit_cleans_output_and_spends_one_use(monkeypatch):
    captured: dict = {}
    _fake_openai(monkeypatch, {
        "fit_score": 140, "verdict": "Добрий збіг", "strengths": ["10 років досвіду", ""],
        "gaps": [{"title": "Німецька B2", "advice": "Пройди курс B1→B2"}, {"title": "", "advice": "x"}],
        "cv_summary": "Erfahrene Pflegefachfrau", "cover_letter": "Sehr geehrte Damen und Herren",
        "email_subject": "Bewerbung", "email_body": "Im Anhang", "interview_questions": ["Warum wir?"] * 7,
    }, captured)
    headers, user_id = _headers()

    response = client.post("/api/v1/ai/application-kit", headers=headers, json={"job": JOB, "cv": CV})

    assert response.status_code == 200
    body = response.json()
    assert body["fit_score"] == 100
    assert body["strengths"] == ["10 років досвіду"]
    assert [gap["title"] for gap in body["gaps"]] == ["Німецька B2"]
    assert len(body["interview_questions"]) == 5
    assert "<<<" in captured["input"] and "Spital Zürich" in captured["input"]
    assert _usage(user_id, "career_kit") == 1


def test_application_kit_refunds_when_ai_unavailable(monkeypatch):
    monkeypatch.setattr(get_settings(), "OPENAI_API_KEY", None)
    headers, user_id = _headers()
    assert client.post("/api/v1/ai/application-kit", headers=headers, json={"job": JOB, "cv": CV}).status_code == 503
    assert _usage(user_id, "career_kit") == 0


def test_interview_first_turn_asks_a_question(monkeypatch):
    _fake_openai(monkeypatch, {"feedback": "ignored", "score": 4, "better_answer": "ignored",
                               "next_question": "Erzählen Sie etwas über sich.", "final_summary": "", "overall_score": 0}, {})
    headers, _ = _headers()

    body = client.post("/api/v1/ai/interview-turn", headers=headers, json={"job": JOB}).json()

    assert body["next_question"] == "Erzählen Sie etwas über sich."
    assert body["feedback"] is None and body["score"] is None
    assert body["question_number"] == 1 and body["done"] is False


def test_interview_finishes_after_last_answer(monkeypatch):
    _fake_openai(monkeypatch, {"feedback": "Gut", "score": 9, "better_answer": "Ich habe…",
                               "next_question": "should be dropped", "final_summary": "Сильні сторони…", "overall_score": 77}, {})
    headers, _ = _headers()
    history = []
    for index in range(3):
        history += [{"role": "interviewer", "content": f"Q{index}"}, {"role": "candidate", "content": f"A{index}"}]

    body = client.post("/api/v1/ai/interview-turn", headers=headers,
                       json={"job": JOB, "history": history, "total_questions": 3}).json()

    assert body["done"] is True and body["next_question"] is None
    assert body["score"] == 5 and body["overall_score"] == 77
    assert body["final_summary"] == "Сильні сторони…"


def test_kit_requires_plus_after_free_uses(monkeypatch):
    monkeypatch.setattr(get_settings(), "OPENAI_API_KEY", None)
    headers, user_id = _headers()
    with SessionLocal() as db:
        db.add(PremiumUsage(user_id=user_id, feature="career_kit", free_uses=3))
        db.commit()
    assert client.post("/api/v1/ai/application-kit", headers=headers, json={"job": JOB, "cv": CV}).status_code == 402
