from types import SimpleNamespace

import httpx
import pytest

from backend.app.services import email as email_service


class FakeClient:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.calls = 0

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return None

    def post(self, url, *, headers, json):
        self.calls += 1
        response = next(self.responses)
        if isinstance(response, Exception):
            raise response
        return response


def _response(status_code: int, payload: dict | None = None) -> httpx.Response:
    request = httpx.Request("POST", email_service.RESEND_API_URL)
    return httpx.Response(status_code, request=request, json=payload or {})


@pytest.fixture
def configured_email(monkeypatch):
    monkeypatch.setattr(
        email_service,
        "get_settings",
        lambda: SimpleNamespace(
            APP_ENV="production",
            RESEND_API_KEY="test-key",
            RESEND_FROM_EMAIL="no-reply@sweezy.app",
            RESEND_FROM_NAME="Sweezy",
            SMTP_FROM=None,
            SMTP_USERNAME=None,
        ),
    )
    monkeypatch.setattr(email_service.time, "sleep", lambda _: None)


def test_email_delivery_retries_transient_provider_failures(monkeypatch, configured_email):
    fake_client = FakeClient([_response(503), _response(429), _response(200, {"id": "email_123"})])
    monkeypatch.setattr(email_service.httpx, "Client", lambda **_: fake_client)

    email_service._send_email(
        "person@example.com",
        subject="Subject",
        text_body="Body",
        email_type="verification",
    )

    assert fake_client.calls == 3


def test_email_delivery_does_not_retry_permanent_rejection(monkeypatch, configured_email):
    fake_client = FakeClient([_response(422)])
    monkeypatch.setattr(email_service.httpx, "Client", lambda **_: fake_client)
    captured = []
    monkeypatch.setattr(email_service.sentry_sdk, "capture_exception", captured.append)

    with pytest.raises(email_service.EmailDeliveryError):
        email_service._send_email(
            "person@example.com",
            subject="Subject",
            text_body="Body",
            email_type="password_reset",
        )

    assert fake_client.calls == 1
    assert len(captured) == 1


def test_email_delivery_retries_network_timeout(monkeypatch, configured_email):
    request = httpx.Request("POST", email_service.RESEND_API_URL)
    fake_client = FakeClient(
        [
            httpx.ReadTimeout("provider timeout", request=request),
            _response(200, {"id": "email_456"}),
        ]
    )
    monkeypatch.setattr(email_service.httpx, "Client", lambda **_: fake_client)

    email_service._send_email(
        "person@example.com",
        subject="Subject",
        text_body="Body",
        email_type="verification",
    )

    assert fake_client.calls == 2
