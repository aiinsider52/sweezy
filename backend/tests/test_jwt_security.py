from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

from backend.app.core.config import get_settings
from backend.app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
)
from backend.app.services import oauth_id_tokens
from backend.app.services.oauth_id_tokens import OAuthIdentityError


def test_typed_tokens_only_decode_as_their_expected_type() -> None:
    subject = str(uuid4())

    assert decode_token(create_access_token(subject), expected_type="access")["sub"] == subject
    assert decode_token(create_refresh_token(subject), expected_type="refresh")["sub"] == subject

    with pytest.raises(ValueError):
        decode_token(create_refresh_token(subject), expected_type="access")


def test_backend_token_rejects_unconfigured_algorithm() -> None:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    token = jwt.encode(
        {
            "sub": str(uuid4()),
            "type": "access",
            "iss": settings.JWT_ISSUER,
            "aud": settings.JWT_AUDIENCE,
            "iat": now,
            "nbf": now,
            "exp": now + timedelta(minutes=5),
        },
        settings.JWT_SECRET_KEY,
        algorithm="HS384",
    )

    with pytest.raises(ValueError):
        decode_token(token)


def _provider_token(*, algorithm: str = "RS256", issuer: str = "https://accounts.google.com", audience: str = "client-id") -> tuple[str, dict]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_jwk = RSAAlgorithm.to_jwk(private_key.public_key(), as_dict=True)
    public_jwk.update({"kid": "provider-key", "alg": "RS256", "use": "sig"})
    now = datetime.now(timezone.utc)
    token = jwt.encode(
        {
            "sub": "provider-subject",
            "iss": issuer,
            "aud": audience,
            "iat": now,
            "exp": now + timedelta(minutes=5),
        },
        private_key,
        algorithm=algorithm,
        headers={"kid": "provider-key"},
    )
    return token, {"keys": [public_jwk]}


def test_provider_jwk_verification_enforces_signature_issuer_and_audience(monkeypatch: pytest.MonkeyPatch) -> None:
    token, jwks = _provider_token()
    monkeypatch.setattr(oauth_id_tokens, "_load_jwks", lambda _: jwks)

    claims = oauth_id_tokens._decode_provider_jwt(
        token=token,
        jwks_url="https://example.invalid/jwks",
        issuer_values={"https://accounts.google.com", "accounts.google.com"},
        allowed_audiences={"client-id"},
    )
    assert claims["sub"] == "provider-subject"

    for issuer_values, audiences in [
        ({"https://wrong.example"}, {"client-id"}),
        ({"https://accounts.google.com"}, {"wrong-client"}),
    ]:
        with pytest.raises(OAuthIdentityError):
            oauth_id_tokens._decode_provider_jwt(
                token=token,
                jwks_url="https://example.invalid/jwks",
                issuer_values=issuer_values,
                allowed_audiences=audiences,
            )


def test_provider_token_rejects_non_rs256_algorithm(monkeypatch: pytest.MonkeyPatch) -> None:
    token, jwks = _provider_token(algorithm="RS384")
    monkeypatch.setattr(oauth_id_tokens, "_load_jwks", lambda _: jwks)

    with pytest.raises(OAuthIdentityError, match="algorithm"):
        oauth_id_tokens._decode_provider_jwt(
            token=token,
            jwks_url="https://example.invalid/jwks",
            issuer_values={"https://accounts.google.com"},
            allowed_audiences={"client-id"},
        )
