import json
import sys
import types
import uuid
from datetime import date

from fastapi.testclient import TestClient

from backend.app.core.config import get_settings
from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models import PremiumUsage
from backend.app.routers.ai import LetterExplainModelOutput, _clean_letter_output, _strict_schema
from backend.app.services.users import UserService


client = TestClient(app)
TODAY = date(2026, 11, 23)


def _headers() -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(db, email=f"letter_{uuid.uuid4().hex}@example.com", password="StrongPass1!", email_verified=True)
        token = create_access_token(subject=user.id, is_admin=False, role=user.role)
        return {"Authorization": f"Bearer {token}"}, user.id


def _payload() -> dict:
    return {
        "text": "Steueramt des Kantons Zürich\nRechnung Nr. 123\nBetrag CHF 1'240.50 zahlbar innert 30 Tagen.",
        "language": "uk",
        "country": "CH",
        "region": "ZH",
        "today": TODAY.isoformat(),
    }


def _output(**overrides) -> LetterExplainModelOutput:
    base = dict(
        sender="Steueramt des Kantons Zürich",
        sender_address="Bändliweg 21, 8090 Zürich",
        category="tax",
        title="Рахунок за податки",
        summary="Податкова просить сплатити податок за 2025 рік.",
        what_they_want="Сплатити суму до кінця строку.",
        urgency="high",
        deadline="2026-12-23",
        deadline_label="Сплатити рахунок",
        amount="1'240.50",
        currency="chf",
        steps=["Перевір суму", "Сплати через банк", ""],
        reply_needed=False,
        reply_language="de",
        reply_letter="Sehr geehrte Damen und Herren",
        specialist="none",
        warnings=["Після строку нараховують пеню"],
    )
    base.update(overrides)
    return LetterExplainModelOutput(**base)


def test_clean_output_normalises_amount_deadline_and_reply():
    result = _clean_letter_output(_output(), TODAY)

    assert result.amount == 1240.50
    assert result.currency == "CHF"
    assert result.deadline == date(2026, 12, 23)
    assert result.deadline_label == "Сплатити рахунок"
    assert result.steps == ["Перевір суму", "Сплати через банк"]
    # No reply expected: the draft and its language are dropped.
    assert result.reply_letter is None and result.reply_language is None
    assert result.specialist is None


def test_clean_output_rejects_implausible_values():
    result = _clean_letter_output(
        _output(deadline="1999-01-01", amount="0", category="spaceship", urgency="extreme", specialist="wizard"),
        TODAY,
    )

    assert result.deadline is None and result.deadline_label is None
    assert result.amount is None and result.currency is None
    assert result.category == "other"
    assert result.urgency == "medium"
    assert result.specialist is None


def test_clean_output_reads_european_decimal_comma():
    assert _clean_letter_output(_output(amount="89,90", currency="EUR"), TODAY).amount == 89.90


def test_strict_schema_requires_every_field():
    schema = _strict_schema(LetterExplainModelOutput)

    assert schema["additionalProperties"] is False
    assert set(schema["required"]) == set(LetterExplainModelOutput.model_fields)


def test_letter_explain_requires_sign_in():
    assert client.post("/api/v1/ai/letter-explain", json=_payload()).status_code == 401


def test_letter_explain_refunds_free_use_when_ai_is_unavailable(monkeypatch):
    monkeypatch.setattr(get_settings(), "OPENAI_API_KEY", None)
    headers, user_id = _headers()

    response = client.post("/api/v1/ai/letter-explain", headers=headers, json=_payload())

    assert response.status_code == 503
    with SessionLocal() as db:
        usage = db.query(PremiumUsage).filter_by(user_id=user_id, feature="letter_explain").one()
        assert usage.free_uses == 0


def test_letter_explain_returns_cleaned_model_answer(monkeypatch):
    monkeypatch.setattr(get_settings(), "OPENAI_API_KEY", "test-key")
    captured = {}

    class FakeResponses:
        def create(self, **kwargs):
            captured.update(kwargs)
            return types.SimpleNamespace(output_text=json.dumps(_output().model_dump()))

    class FakeOpenAI:
        def __init__(self, api_key):
            self.responses = FakeResponses()

    monkeypatch.setitem(sys.modules, "openai", types.SimpleNamespace(OpenAI=FakeOpenAI))
    headers, user_id = _headers()

    response = client.post("/api/v1/ai/letter-explain", headers=headers, json=_payload())

    assert response.status_code == 200
    body = response.json()
    assert body["amount"] == 1240.5
    assert body["deadline"] == "2026-12-23"
    assert body["generated_by_ai"] is True
    # The letter is passed as quoted data, and the user's free allowance is spent once.
    assert "<<<" in captured["input"] and "Steueramt" in captured["input"]
    with SessionLocal() as db:
        usage = db.query(PremiumUsage).filter_by(user_id=user_id, feature="letter_explain").one()
        assert usage.free_uses == 1


def test_letter_explain_needs_plus_after_free_uses(monkeypatch):
    monkeypatch.setattr(get_settings(), "OPENAI_API_KEY", None)
    headers, user_id = _headers()
    with SessionLocal() as db:
        db.add(PremiumUsage(user_id=user_id, feature="letter_explain", free_uses=3))
        db.commit()

    response = client.post("/api/v1/ai/letter-explain", headers=headers, json=_payload())

    assert response.status_code == 402
