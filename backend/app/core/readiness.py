from __future__ import annotations

from pathlib import Path

from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from redis import Redis
from sqlalchemy import text

from .config import get_settings
from .database import engine


BACKEND_ROOT = Path(__file__).resolve().parents[2]
ALEMBIC_CONFIG = BACKEND_ROOT / "alembic.ini"
ALEMBIC_SCRIPTS = BACKEND_ROOT / "alembic"


def database_readiness() -> str:
    config = Config(str(ALEMBIC_CONFIG))
    config.set_main_option("script_location", str(ALEMBIC_SCRIPTS))
    expected_heads = set(ScriptDirectory.from_config(config).get_heads())

    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
        current_heads = set(MigrationContext.configure(connection).get_current_heads())

    if current_heads != expected_heads:
        raise RuntimeError(
            f"Database migration mismatch: current={sorted(current_heads)} expected={sorted(expected_heads)}"
        )
    return ",".join(sorted(current_heads))


def redis_readiness() -> str:
    settings = get_settings()
    if not settings.CHAT_ENABLED:
        return "disabled"
    if not settings.REDIS_URL:
        raise RuntimeError("REDIS_URL is missing")

    client = Redis.from_url(
        settings.REDIS_URL,
        socket_connect_timeout=2,
        socket_timeout=2,
        health_check_interval=30,
    )
    try:
        if client.ping() is not True:
            raise RuntimeError("Redis ping failed")
    finally:
        client.close()
    return "ok"


def run_readiness_checks() -> dict[str, str]:
    settings = get_settings()
    return {
        "database": "ok",
        "migrations": database_readiness(),
        "redis": redis_readiness(),
        "apns": "configured" if settings.PUSH_NOTIFICATIONS_ENABLED else "disabled",
    }
