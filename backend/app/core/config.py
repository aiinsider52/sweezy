from __future__ import annotations

from functools import lru_cache
from typing import List, Optional

import json
import re
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file="backend/.env", env_file_encoding="utf-8", extra="ignore")

    # App
    APP_NAME: str = "SWEEEZY Backend"
    APP_ENV: str = Field(default="development", description="environment: development|staging|production")
    APP_VERSION: str = Field(default="1.0.0")

    # CORS (accepts JSON array or comma-separated string via env). Store raw string to avoid
    # pydantic-settings attempting to JSON-decode before our coercion.
    CORS_ORIGINS: str | None = Field(default="*")

    # Database
    DATABASE_URL: str = Field(
        default="postgresql+psycopg2://postgres:postgres@localhost:5432/sweeezy",
        description="SQLAlchemy database URL",
    )

    # Security
    JWT_SECRET_KEY: str = Field(default="change-me-in-production")
    JWT_ALGORITHM: str = Field(default="HS256")
    JWT_ISSUER: str = Field(default="sweezy-api")
    JWT_AUDIENCE: str = Field(default="sweezy-clients")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=60 * 24, alias="JWT_EXPIRE_MINUTES")
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(default=7)

    # Private media storage. S3-compatible settings support AWS S3 and Cloudflare R2.
    MEDIA_MAX_UPLOAD_BYTES: int = Field(default=8 * 1024 * 1024, ge=1, le=25 * 1024 * 1024)
    MEDIA_LOCAL_DIR: str = Field(default="backend/uploads")
    MEDIA_S3_BUCKET: str | None = Field(default=None)
    MEDIA_S3_REGION: str = Field(default="auto")
    MEDIA_S3_ENDPOINT_URL: str | None = Field(default=None)
    MEDIA_S3_ACCESS_KEY_ID: str | None = Field(default=None)
    MEDIA_S3_SECRET_ACCESS_KEY: str | None = Field(default=None)
    MEDIA_S3_PREFIX: str = Field(default="media")
    MEDIA_SIGNED_URL_TTL_SECONDS: int = Field(default=300, ge=60, le=3600)
    # Temporary compatibility switch while production object storage is provisioned.
    # Keep false by default; Render must opt in explicitly and logs a warning.
    MEDIA_ALLOW_EPHEMERAL_FALLBACK: bool = False
    TELEMETRY_MAX_BATCH_SIZE: int = Field(default=50)

    # Marketplace chat realtime and push notifications
    CHAT_ENABLED: bool = Field(default=True)
    REDIS_URL: str | None = Field(default=None)
    CHAT_REDIS_CHANNEL: str = Field(default="sweezy:chat:events")
    PUSH_NOTIFICATIONS_ENABLED: bool = Field(default=False)
    APNS_KEY_ID: str | None = Field(default=None)
    APNS_TEAM_ID: str | None = Field(default=None)
    APNS_PRIVATE_KEY: str | None = Field(default=None)
    APNS_BUNDLE_ID: str | None = Field(default=None)
    PUSH_SHOW_MESSAGE_PREVIEW: bool = Field(default=False)
    CHAT_OUTBOX_RETENTION_DAYS: int = Field(default=30, ge=7, le=365)
    PUSH_REVOKED_RETENTION_DAYS: int = Field(default=30, ge=7, le=365)

    # Email / SMTP (legacy optional settings; Resend is the primary provider)
    SMTP_HOST: str | None = Field(default=None, description="SMTP host for outgoing email")
    SMTP_PORT: int = Field(default=587, description="SMTP port (usually 587 for STARTTLS)")
    SMTP_USERNAME: str | None = Field(default=None, description="SMTP username/login")
    SMTP_PASSWORD: str | None = Field(default=None, description="SMTP password")
    SMTP_FROM: str | None = Field(default=None, description="From email address, defaults to SMTP_USERNAME")
    RESEND_API_KEY: str | None = Field(default=None, description="Resend API key for transactional emails")
    RESEND_FROM_EMAIL: str | None = Field(default=None, description="Verified sender email in Resend")
    RESEND_FROM_NAME: str | None = Field(default="Sweezy", description="Optional sender name for Resend")

    # Demo admin (for issuing JWT tokens). In production, replace with real user store.
    ADMIN_EMAIL: str = Field(default="admin@sweeezy.app")
    ADMIN_PASSWORD: str = Field(default="admin123")

    # App Review / Demo user (optional). If set, backend will ensure this user exists on startup.
    # Do NOT hardcode credentials in the repo; set these via environment variables.
    DEMO_USER_ENABLED: bool = Field(default=False)
    DEMO_USER_EMAIL: str | None = Field(default=None)
    DEMO_USER_PASSWORD: str | None = Field(default=None)

    # One-time setup secret to allow forced admin seeding via HTTP
    SETUP_SECRET: Optional[str] = None
    # Fallback for setups that already use SECRET_KEY
    SECRET_KEY: Optional[str] = None
    STRIPE_REDIRECT_ORIGINS: str | None = None

    # Sentry
    SENTRY_DSN: Optional[str] = None
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1
    SENTRY_PROFILES_SAMPLE_RATE: float = 0.0

    # Remote config
    REMOTE_FLAGS: dict = Field(default_factory=lambda: {"enableNewOnboarding": True})

    # Brave Search API / automated news research
    BRAVE_API_KEY: str | None = Field(default=None)
    BRAVE_SEARCH_BASE_URL: str = Field(default="https://api.search.brave.com/res/v1/web/search")
    BRAVE_REFRESH_INTERVAL_SEC: int = Field(default=60 * 60 * 24 * 7)
    BRAVE_MAX_RESULTS_PER_QUERY: int = Field(default=8)

    # Ask Sweezy. Without an API key the endpoint remains available in a
    # deterministic, citation-only fallback mode.
    OPENAI_API_KEY: str | None = Field(default=None)
    OPENAI_MODEL: str = Field(default="gpt-5.4-mini")
    ASK_SWEEZY_MAX_SOURCES: int = Field(default=8, ge=1, le=12)

    # Social auth
    GOOGLE_CLIENT_IDS: str | None = Field(default=None, description="Comma-separated Google OAuth client IDs")
    APPLE_CLIENT_IDS: str | None = Field(default=None, description="Comma-separated Apple Sign-In audience values")


    def parsed_cors_origins(self) -> List[str]:
        raw = self.CORS_ORIGINS
        if raw is None:
            return []
        s = str(raw).strip()
        if not s:
            return []
        if s.startswith("["):
            try:
                data = json.loads(s)
                if isinstance(data, list):
                    return [str(o) for o in data]
            except Exception:
                pass
        return [part.strip() for part in s.split(",") if part.strip()]

    def assert_valid(self) -> None:
        media_credentials = (
            self.MEDIA_S3_BUCKET,
            self.MEDIA_S3_ACCESS_KEY_ID,
            self.MEDIA_S3_SECRET_ACCESS_KEY,
        )
        if any(media_credentials) and not all(media_credentials):
            raise RuntimeError("MEDIA_S3_BUCKET and media S3 credentials must be configured together")
        if self.MEDIA_S3_ENDPOINT_URL and not self.MEDIA_S3_ENDPOINT_URL.startswith("https://"):
            raise RuntimeError("MEDIA_S3_ENDPOINT_URL must use HTTPS")
        if self.APP_ENV.lower() == "production":
            if (
                not self.JWT_SECRET_KEY
                or self.JWT_SECRET_KEY == "change-me-in-production"
                or len(self.JWT_SECRET_KEY.encode("utf-8")) < 32
            ):
                raise RuntimeError("JWT_SECRET_KEY must be at least 32 bytes in production")
            if self.JWT_ALGORITHM not in {"HS256", "HS384", "HS512"}:
                raise RuntimeError("JWT_ALGORITHM must be an HMAC SHA-2 algorithm")
            if not self.JWT_ISSUER or not self.JWT_AUDIENCE:
                raise RuntimeError("JWT_ISSUER and JWT_AUDIENCE must be set in production")
            if not self.DATABASE_URL:
                raise RuntimeError("DATABASE_URL must be set in production")
            if self.CORS_ORIGINS == "*" or self.parsed_cors_origins() == ["*"]:
                raise RuntimeError("CORS_ORIGINS cannot be '*' in production")
            if self.ADMIN_PASSWORD == "admin123":
                raise RuntimeError("ADMIN_PASSWORD must be changed in production")
            if not self.RESEND_API_KEY or not self.RESEND_FROM_EMAIL:
                raise RuntimeError("RESEND_API_KEY and RESEND_FROM_EMAIL are required in production")
            if self.CHAT_ENABLED:
                if not self.REDIS_URL:
                    raise RuntimeError("REDIS_URL must be set in production for chat realtime")
                if not self.REDIS_URL.startswith(("redis://", "rediss://")):
                    raise RuntimeError("REDIS_URL must use redis:// or rediss://")
            apns_values = [self.APNS_KEY_ID, self.APNS_TEAM_ID, self.APNS_PRIVATE_KEY, self.APNS_BUNDLE_ID]
            apns_credentials = [self.APNS_KEY_ID, self.APNS_TEAM_ID, self.APNS_PRIVATE_KEY]
            if self.PUSH_NOTIFICATIONS_ENABLED:
                if not self.CHAT_ENABLED:
                    raise RuntimeError("CHAT_ENABLED must be true when push notifications are enabled")
                if not all(apns_values):
                    raise RuntimeError("APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY and APNS_BUNDLE_ID are required")
            if any(apns_credentials):
                if not all(apns_values):
                    raise RuntimeError("APNs configuration must be complete when any APNs value is set")
                if not re.fullmatch(r"[A-Z0-9]{10}", self.APNS_KEY_ID or ""):
                    raise RuntimeError("APNS_KEY_ID must be a 10-character Apple key identifier")
                if not re.fullmatch(r"[A-Z0-9]{10}", self.APNS_TEAM_ID or ""):
                    raise RuntimeError("APNS_TEAM_ID must be a 10-character Apple team identifier")
                if not re.fullmatch(r"[A-Za-z0-9.-]+", self.APNS_BUNDLE_ID or ""):
                    raise RuntimeError("APNS_BUNDLE_ID is invalid")
                try:
                    from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePrivateKey, SECP256R1
                    from cryptography.hazmat.primitives.serialization import load_pem_private_key

                    private_key = (self.APNS_PRIVATE_KEY or "").replace("\\n", "\n").encode("utf-8")
                    loaded_key = load_pem_private_key(private_key, password=None)
                    if not isinstance(loaded_key, EllipticCurvePrivateKey) or not isinstance(
                        loaded_key.curve, SECP256R1
                    ):
                        raise ValueError("APNs key must use P-256")
                except Exception as exc:
                    raise RuntimeError("APNS_PRIVATE_KEY must contain a valid Apple AuthKey .p8 key") from exc

    def parsed_google_client_ids(self) -> List[str]:
        raw = (self.GOOGLE_CLIENT_IDS or "").strip()
        if not raw:
            return []
        return [part.strip() for part in raw.split(",") if part.strip()]

    def parsed_apple_client_ids(self) -> List[str]:
        raw = (self.APPLE_CLIENT_IDS or "").strip()
        if not raw:
            return []
        return [part.strip() for part in raw.split(",") if part.strip()]



@lru_cache
def get_settings() -> Settings:
    settings = Settings()  # type: ignore[call-arg]
    return settings
