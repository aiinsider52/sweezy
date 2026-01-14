from __future__ import annotations

from functools import lru_cache
from typing import List, Optional

import json
from pydantic import Field
from pydantic.functional_validators import field_validator
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
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=60 * 24, alias="JWT_EXPIRE_MINUTES")

    # Email / SMTP (optional, used for password reset and notifications)
    SMTP_HOST: str | None = Field(default=None, description="SMTP host for outgoing email")
    SMTP_PORT: int = Field(default=587, description="SMTP port (usually 587 for STARTTLS)")
    SMTP_USERNAME: str | None = Field(default=None, description="SMTP username/login")
    SMTP_PASSWORD: str | None = Field(default=None, description="SMTP password")
    SMTP_FROM: str | None = Field(default=None, description="From email address, defaults to SMTP_USERNAME")

    # Demo admin (for issuing JWT tokens). In production, replace with real user store.
    ADMIN_EMAIL: str = Field(default="admin@sweeezy.app")
    ADMIN_PASSWORD: str = Field(default="admin123")

    # One-time setup secret to allow forced admin seeding via HTTP
    SETUP_SECRET: Optional[str] = None
    # Fallback for setups that already use SECRET_KEY
    SECRET_KEY: Optional[str] = None

    # Sentry
    SENTRY_DSN: Optional[str] = None
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1
    SENTRY_PROFILES_SAMPLE_RATE: float = 0.0

    # Remote config
    REMOTE_FLAGS: dict = Field(default_factory=lambda: {"enableNewOnboarding": True})


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
        if self.APP_ENV.lower() == "production":
            if not self.JWT_SECRET_KEY or self.JWT_SECRET_KEY == "change-me-in-production":
                raise RuntimeError("JWT_SECRET_KEY must be set in production")
            if not self.DATABASE_URL:
                raise RuntimeError("DATABASE_URL must be set in production")
            if self.CORS_ORIGINS == "*" or self.parsed_cors_origins() == ["*"]:
                raise RuntimeError("CORS_ORIGINS cannot be '*' in production")
            if self.ADMIN_PASSWORD == "admin123":
                raise RuntimeError("ADMIN_PASSWORD must be changed in production")



@lru_cache
def get_settings() -> Settings:
    settings = Settings()  # type: ignore[call-arg]
    return settings


