from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from time import monotonic
from typing import Any

import httpx
import jwt
from jwt.algorithms import RSAAlgorithm
from jwt.exceptions import InvalidTokenError

from ..core.config import get_settings

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
JWKS_TTL_SECONDS = 60 * 60
OAUTH_SIGNING_ALGORITHM = "RS256"

_jwks_cache: dict[str, tuple[float, dict[str, Any]]] = {}


@dataclass(frozen=True)
class VerifiedOAuthIdentity:
    provider: str
    subject: str
    email: str | None
    email_verified: bool
    name: str | None
    claims: dict[str, Any]


class OAuthIdentityError(ValueError):
    pass


class OAuthIDTokenService:
    @staticmethod
    def verify_google_id_token(id_token: str) -> VerifiedOAuthIdentity:
        settings = get_settings()
        audiences = settings.parsed_google_client_ids()
        if not audiences:
            raise OAuthIdentityError("Google Sign-In is not configured")

        claims = _decode_provider_jwt(
            token=id_token,
            jwks_url=GOOGLE_JWKS_URL,
            issuer_values={"https://accounts.google.com", "accounts.google.com"},
            allowed_audiences=set(audiences),
        )

        subject = str(claims.get("sub") or "").strip()
        if not subject:
            raise OAuthIdentityError("Invalid Google token subject")

        email = _normalized_email(claims.get("email"))
        email_verified = bool(claims.get("email_verified"))
        if not email or not email_verified:
            raise OAuthIdentityError("Google account email is not verified")

        return VerifiedOAuthIdentity(
            provider="google",
            subject=subject,
            email=email,
            email_verified=True,
            name=_normalized_name(claims.get("name")),
            claims=claims,
        )

    @staticmethod
    def verify_apple_id_token(id_token: str, raw_nonce: str | None = None) -> VerifiedOAuthIdentity:
        settings = get_settings()
        audiences = settings.parsed_apple_client_ids()
        if not audiences:
            raise OAuthIdentityError("Apple Sign-In is not configured")

        claims = _decode_provider_jwt(
            token=id_token,
            jwks_url=APPLE_JWKS_URL,
            issuer_values={"https://appleid.apple.com"},
            allowed_audiences=set(audiences),
        )

        subject = str(claims.get("sub") or "").strip()
        if not subject:
            raise OAuthIdentityError("Invalid Apple token subject")

        if raw_nonce:
            expected_nonce = sha256(raw_nonce.encode("utf-8")).hexdigest()
            token_nonce = str(claims.get("nonce") or "").strip()
            if not token_nonce or token_nonce != expected_nonce:
                raise OAuthIdentityError("Invalid Apple Sign-In nonce")

        email = _normalized_email(claims.get("email"))
        email_verified = _truthy(claims.get("email_verified"))

        return VerifiedOAuthIdentity(
            provider="apple",
            subject=subject,
            email=email,
            email_verified=email_verified,
            name=_normalized_name(claims.get("name")),
            claims=claims,
        )


def _decode_provider_jwt(
    *,
    token: str,
    jwks_url: str,
    issuer_values: set[str],
    allowed_audiences: set[str],
) -> dict[str, Any]:
    try:
        header = jwt.get_unverified_header(token)
    except InvalidTokenError as exc:
        raise OAuthIdentityError("Invalid identity token") from exc
    kid = str(header.get("kid") or "").strip()
    alg = str(header.get("alg") or "").strip()
    if not kid:
        raise OAuthIdentityError("Missing token key id")
    if alg != OAUTH_SIGNING_ALGORITHM:
        raise OAuthIdentityError("Invalid token algorithm")

    jwks = _load_jwks(jwks_url)
    key = next((item for item in jwks.get("keys", []) if item.get("kid") == kid), None)
    if not key:
        raise OAuthIdentityError("Unknown signing key")

    try:
        signing_key = RSAAlgorithm.from_jwk(key)
        claims = jwt.decode(
            token,
            signing_key,
            algorithms=[OAUTH_SIGNING_ALGORITHM],
            audience=list(allowed_audiences),
            issuer=list(issuer_values),
            options={"require": ["exp", "iat", "iss", "aud", "sub"]},
        )
    except (InvalidTokenError, TypeError, ValueError) as exc:
        raise OAuthIdentityError("Invalid identity token") from exc

    return claims


def _load_jwks(url: str) -> dict[str, Any]:
    cached = _jwks_cache.get(url)
    now = monotonic()
    if cached and cached[0] > now:
        return cached[1]

    with httpx.Client(timeout=10.0) as client:
        response = client.get(url)
        response.raise_for_status()
        payload = response.json()

    if not isinstance(payload, dict) or "keys" not in payload:
        raise OAuthIdentityError("Invalid provider keys response")

    _jwks_cache[url] = (now + JWKS_TTL_SECONDS, payload)
    return payload


def _truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in {"true", "1", "yes"}
    return False


def _normalized_email(value: Any) -> str | None:
    if not value:
        return None
    email = str(value).strip().lower()
    return email or None


def _normalized_name(value: Any) -> str | None:
    if not value:
        return None
    name = str(value).strip()
    return name or None
