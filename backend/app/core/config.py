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

    # CORS (accepts JSON array or comma-separated string via env)
    CORS_ORIGINS: List[str] = Field(default_factory=lambda: ["*"])

    # Database
    DATABASE_URL: str = Field(
        default="postgresql+psycopg2://postgres:postgres@localhost:5432/sweeezy",
        description="SQLAlchemy database URL",
    )

    # Security
    JWT_SECRET_KEY: str = Field(default="change-me-in-production")
    JWT_ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=60 * 24, alias="JWT_EXPIRE_MINUTES")

    # Demo admin (for issuing JWT tokens). In production, replace with real user store.
    ADMIN_EMAIL: str = Field(default="admin@sweeezy.app")
    ADMIN_PASSWORD: str = Field(default="admin123")

    # Sentry
    SENTRY_DSN: Optional[str] = None
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1
    SENTRY_PROFILES_SAMPLE_RATE: float = 0.0

    # Remote config
    REMOTE_FLAGS: dict = Field(default_factory=lambda: {"enableNewOnboarding": True})


    def parsed_cors_origins(self) -> List[str]:
        if isinstance(self.CORS_ORIGINS, list):
            return self.CORS_ORIGINS
        # pydantic already gives list, but keep safe fallback
        raw = str(self.CORS_ORIGINS)
        return [o.strip() for o in raw.split(",") if o.strip()]

    def assert_valid(self) -> None:
        if self.APP_ENV.lower() == "production":
            if not self.JWT_SECRET_KEY or self.JWT_SECRET_KEY == "change-me-in-production":
                raise RuntimeError("JWT_SECRET_KEY must be set in production")
            if not self.DATABASE_URL:
                raise RuntimeError("DATABASE_URL must be set in production")
            if "*" in self.CORS_ORIGINS or self.CORS_ORIGINS == ["*"]:
                raise RuntimeError("CORS_ORIGINS cannot be '*' in production")

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def _coerce_cors_origins(cls, v):  # type: ignore[override]
        if v is None:
            return []
        if isinstance(v, list):
            return v
        if isinstance(v, str):
            s = v.strip()
            if not s:
                return []
            if s.startswith("["):
                try:
                    parsed = json.loads(s)
                    if isinstance(parsed, list):
                        return parsed
                except Exception:
                    # fall back to comma splitting
                    pass
            return [p.strip() for p in s.split(",") if p.strip()]
        return v


@lru_cache
def get_settings() -> Settings:
    settings = Settings()  # type: ignore[call-arg]
    return settings


