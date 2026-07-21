from __future__ import annotations

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

from backend.app.core import readiness
from backend.app.core.config import Settings


def _private_key() -> str:
    key = ec.generate_private_key(ec.SECP256R1())
    return key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")


def _production_settings(**overrides) -> Settings:
    values = {
        "APP_ENV": "production",
        "DATABASE_URL": "postgresql://example.invalid/sweezy",
        "JWT_SECRET_KEY": "x" * 48,
        "CORS_ORIGINS": '["https://sweezy-admin.onrender.com"]',
        "ADMIN_PASSWORD": "not-the-default-password",
        "CHAT_ENABLED": True,
        "REDIS_URL": "rediss://example.invalid:6379/0",
        "PUSH_NOTIFICATIONS_ENABLED": True,
        "APNS_KEY_ID": "ABCDEFGHIJ",
        "APNS_TEAM_ID": "1234567890",
        "APNS_PRIVATE_KEY": _private_key(),
        "APNS_BUNDLE_ID": "com.sweezy.mobile",
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


def test_valid_production_chat_configuration() -> None:
    _production_settings().assert_valid()


def test_valid_production_chat_without_push_configuration() -> None:
    _production_settings(
        PUSH_NOTIFICATIONS_ENABLED=False,
        APNS_KEY_ID=None,
        APNS_TEAM_ID=None,
        APNS_PRIVATE_KEY=None,
        APNS_BUNDLE_ID=None,
    ).assert_valid()


def test_push_requires_complete_apns_configuration() -> None:
    with pytest.raises(RuntimeError):
        _production_settings(
            PUSH_NOTIFICATIONS_ENABLED=True,
            APNS_KEY_ID=None,
            APNS_TEAM_ID=None,
            APNS_PRIVATE_KEY=None,
            APNS_BUNDLE_ID=None,
        ).assert_valid()


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("REDIS_URL", "https://example.invalid"),
        ("APNS_KEY_ID", "short"),
        ("APNS_TEAM_ID", "bad-team"),
        ("APNS_PRIVATE_KEY", "not-a-private-key"),
        ("APNS_BUNDLE_ID", "bad bundle id"),
    ],
)
def test_invalid_production_chat_configuration_is_rejected(field: str, value: str) -> None:
    with pytest.raises(RuntimeError):
        _production_settings(**{field: value}).assert_valid()


def test_readiness_aggregates_critical_dependencies(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(readiness, "database_readiness", lambda: "0025_production_chat")
    monkeypatch.setattr(readiness, "redis_readiness", lambda: "ok")
    monkeypatch.setattr(
        readiness,
        "get_settings",
        lambda: type("S", (), {"CHAT_ENABLED": True, "PUSH_NOTIFICATIONS_ENABLED": True})(),
    )

    assert readiness.run_readiness_checks() == {
        "database": "ok",
        "migrations": "0025_production_chat",
        "redis": "ok",
        "apns": "configured",
    }
