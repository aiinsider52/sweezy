from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
import contextlib
from typing import List
import subprocess
from pathlib import Path
import os
import time as _time
import sys

import time
import uuid
from fastapi import FastAPI, HTTPException, Request
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi.middleware.cors import CORSMiddleware

from .core.config import get_settings
from .core.rate_limit import limiter
from .core.logging import configure_logging, get_logger
from .core.sentry import init_sentry
from .routers.auth import router as auth_router
from .routers.guides import router as guides_router
from .routers.checklists import router as checklists_router
from .routers.templates import router as templates_router
from .routers.analytics import router as analytics_router
from .routers.appointments import router as appointments_router
from .routers.remote_config import router as remote_config_router
from .routers.media import router as media_router
from .routers.news import router as news_router
from starlette.staticfiles import StaticFiles
from .routers.admin import router as admin_router
from .routers.ai import router as ai_router
from .routers.jobs import router as jobs_router
from .routers.live import router as live_router
from .routers.translations import router as translations_router
from .routers.subscriptions import router as subscriptions_router
from .routers.telemetry import router as telemetry_router
from .routers.legal import router as legal_router

from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from prometheus_fastapi_instrumentator import Instrumentator


configure_logging()
settings = get_settings()
try:
    settings.assert_valid()
except Exception:
    # Fail fast on invalid configuration
    raise


async def _background_tick() -> None:
    from .core.database import SessionLocal
    from .models.rss_feed import RSSFeed
    from .services.rss_importer import RSSImporter

    interval = int(os.getenv("FEED_IMPORT_INTERVAL_SEC", "900"))
    last_run = 0.0
    while True:
        await asyncio.sleep(60)
        now = _time.monotonic()
        if now - last_run < interval:
            continue
        last_run = now
        try:
            with SessionLocal() as db:
                feeds: List[RSSFeed] = db.query(RSSFeed).filter(RSSFeed.enabled == True).all()  # noqa: E712
                for f in feeds:
                    try:
                        RSSImporter.import_feed_record(db, f)
                    except Exception:
                        continue
        except Exception:
            # never break background loop
            pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_sentry()

    # NOTE: When `lifespan` is provided, FastAPI does not run `@app.on_event("startup")`
    # handlers. Therefore, all production-critical startup work must happen here.
    migrations_ok = await asyncio.to_thread(_run_migrations)
    if not migrations_ok:
        # Fail fast: running with an unmigrated DB will cause random 500s in production.
        raise RuntimeError("Database migrations failed (see logs for details)")

    # Seed default admin (idempotent)
    from .core.database import SessionLocal
    from .services.users import seed_admin_user

    def _seed_admin() -> None:
        with SessionLocal() as db:
            seed_admin_user(db)

    try:
        await asyncio.to_thread(_seed_admin)
    except Exception as exc:
        # Seeding is helpful but not critical for serving requests; log and continue.
        log.warning("seed_admin_failed", error=str(exc))

    task = asyncio.create_task(_background_tick())
    try:
        yield
    finally:
        task.cancel()
        # Suppress task cancellation on shutdown to avoid noisy tracebacks
        with contextlib.suppress(asyncio.CancelledError):
            await task


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan,
)

# Attach global limiter to app state so slowapi decorators can access it
app.state.limiter = limiter

log = get_logger(module="main")

# Prometheus metrics instrumentator
instrumentator = Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
    excluded_handlers={"/health", "/ready", "/metrics"},
)

# CORS (lock in production)
allowed_origins = list(getattr(settings, "parsed_cors_origins", lambda: settings.CORS_ORIGINS)())
if settings.APP_ENV.lower() == "production" and (not allowed_origins or "*" in allowed_origins):
    allowed_origins = []  # locked — must be provided explicitly by env

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = str(uuid.uuid4())
        start = time.perf_counter()
        # Attach request identifier to structlog context
        import structlog

        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            path=request.url.path,
            method=request.method,
        )
        try:
            response = await call_next(request)
        finally:
            duration_ms = int((time.perf_counter() - start) * 1000)
            status_code = getattr(response, "status_code", 500)
            client_host = request.client.host if request.client else None

            # Enrich response with headers so clients can correlate logs
            if hasattr(response, "headers"):
                response.headers["X-Request-ID"] = request_id
                response.headers["X-Response-Time"] = str(duration_ms)

            # Structured access log
            log.info(
                "http_request",
                request_id=request_id,
                method=request.method,
                path=str(request.url.path),
                query=str(request.url.query),
                status_code=status_code,
                duration_ms=duration_ms,
                client_ip=client_host,
            )

            # Clear contextvars for this request
            structlog.contextvars.clear_contextvars()

        return response


app.add_middleware(RequestIDMiddleware)

# Rate limiting middleware & handler (slowapi)
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# Prometheus metrics must be registered BEFORE startup (instrumentator adds middleware).
try:
    instrumentator.instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)
    log.info("metrics_enabled", endpoint="/metrics")
except Exception as exc:
    # Metrics are helpful but non‑critical; log and continue
    log.warning("metrics_init_failed", error=str(exc))


def _run_migrations() -> bool:
    """
    Apply Alembic migrations.

    Important:
    - We must NOT rely on the `alembic` shell entrypoint being on PATH in hosted envs.
    - In production, we want to fail fast if migrations cannot be applied.
    """
    if not Path("backend/alembic").exists():
        log.warning("alembic_missing", path="backend/alembic")
        return False

    cmd = [sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "upgrade", "head"]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=120)
        log.info("alembic_ok")
        return True
    except subprocess.TimeoutExpired:
        log.error("alembic_timeout", timeout_sec=120)
        return False
    except subprocess.CalledProcessError as exc:
        log.error(
            "alembic_failed",
            returncode=exc.returncode,
            stdout=(exc.stdout or "")[-4000:],
            stderr=(exc.stderr or "")[-4000:],
        )
        return False


@app.api_route("/health", methods=["GET", "HEAD"])
def health() -> dict:
    # Liveness
    return {"status": "ok"}


@app.api_route("/ready", methods=["GET", "HEAD"])
def ready() -> dict:
    # Readiness (DB connectivity + schema/migrations)
    from sqlalchemy import text
    from .core.database import SessionLocal

    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
            db.execute(text("SELECT 1 FROM alembic_version LIMIT 1"))
        return {"status": "ready"}
    except Exception as exc:
        raise HTTPException(status_code=503, detail="not ready") from exc


# Routers (versioned)
API_PREFIX = "/api/v1"
app.include_router(auth_router, prefix=f"{API_PREFIX}/auth", tags=["auth"])
app.include_router(guides_router, prefix=f"{API_PREFIX}/guides", tags=["guides"])
app.include_router(checklists_router, prefix=f"{API_PREFIX}/checklists", tags=["checklists"])
app.include_router(templates_router, prefix=f"{API_PREFIX}/templates", tags=["templates"])
app.include_router(appointments_router, prefix=f"{API_PREFIX}/appointments", tags=["appointments"])
app.include_router(remote_config_router, prefix=f"{API_PREFIX}/remote-config", tags=["remote-config"])
app.include_router(admin_router, prefix=f"{API_PREFIX}/admin", tags=["admin"])
app.include_router(media_router, prefix=f"{API_PREFIX}/media", tags=["media"])
app.include_router(news_router, prefix=f"{API_PREFIX}/news", tags=["news"])
app.include_router(ai_router, prefix=f"{API_PREFIX}/ai", tags=["ai"])
app.include_router(jobs_router, prefix=f"{API_PREFIX}/jobs", tags=["jobs"])
app.include_router(live_router, prefix=f"{API_PREFIX}/live", tags=["live"])
app.include_router(translations_router, prefix=f"{API_PREFIX}/translations", tags=["translations"])
app.include_router(subscriptions_router, prefix=f"{API_PREFIX}/subscriptions", tags=["subscriptions"])
app.include_router(analytics_router, prefix=f"{API_PREFIX}/analytics", tags=["analytics"])
app.include_router(telemetry_router, prefix=f"{API_PREFIX}/telemetry", tags=["telemetry"])

# Public pages (App Store / legal)
app.include_router(legal_router, tags=["legal"])

# Serve uploaded media
try:
    app.mount("/media", StaticFiles(directory="backend/uploads"), name="media")
except Exception:
    # directory may not exist at build time
    pass


@app.get("/debug/openapi")
def debug_openapi() -> dict:
    """
    Helper endpoint to debug OpenAPI generation issues in hosted environments.
    It attempts to call `app.openapi()` and, if that fails, returns the error
    and traceback instead of letting FastAPI swallow it into a generic 500.
    """
    import traceback

    try:
        return app.openapi()
    except Exception as exc:  # pragma: no cover - only used in prod debugging
        return {
            "error": str(exc),
            "traceback": traceback.format_exc(),
        }

