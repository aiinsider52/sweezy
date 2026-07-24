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
from .routers.marketplace import router as marketplace_router
from .routers.marketplace import admin_router as marketplace_admin_router
from .routers.events import router as events_router
from .routers.events import admin_router as events_admin_router
from .routers.moments import router as moments_router
from .routers.moments import admin_router as moments_admin_router
from .routers.experts import router as experts_router
from .routers.experts import admin_router as experts_admin_router
from .routers.chat import router as chat_router
from .routers.chat import admin_router as chat_admin_router
from .routers.chat import devices_router

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
    from .services.brave_search_importer import BraveSearchImporter

    interval = int(os.getenv("FEED_IMPORT_INTERVAL_SEC", "900"))
    brave_interval = int(os.getenv("BRAVE_REFRESH_INTERVAL_SEC", str(settings.BRAVE_REFRESH_INTERVAL_SEC)))
    last_run = 0.0
    last_brave_run = 0.0
    while True:
        await asyncio.sleep(60)
        now = _time.monotonic()
        if now - last_run < interval:
            pass
        else:
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

        if not settings.BRAVE_API_KEY or now - last_brave_run < brave_interval:
            continue

        last_brave_run = now
        try:
            with SessionLocal() as db:
                BraveSearchImporter.import_enabled_queries(db)
        except Exception:
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

    # Seed default admin + optional demo user (idempotent)
    from .core.database import SessionLocal
    from .services.users import seed_admin_user
    try:
        # Optional: may not exist in older builds; never crash startup because of demo seeding.
        from .services.users import seed_demo_user  # type: ignore
    except ImportError:
        seed_demo_user = None  # type: ignore

    def _seed_admin() -> None:
        with SessionLocal() as db:
            seed_admin_user(db)

    try:
        await asyncio.to_thread(_seed_admin)
    except Exception as exc:
        # Seeding is helpful but not critical for serving requests; log and continue.
        log.warning("seed_admin_failed", error=str(exc))

    def _seed_demo() -> None:
        with SessionLocal() as db:
            if seed_demo_user is not None:
                seed_demo_user(db)

    try:
        await asyncio.to_thread(_seed_demo)
    except Exception as exc:
        # Demo seeding is optional; log and continue.
        log.warning("seed_demo_failed", error=str(exc))

    def _seed_moments() -> int:
        from .services.moments_seed import seed_swiss_moments

        with SessionLocal() as db:
            return seed_swiss_moments(db)

    try:
        inserted = await asyncio.to_thread(_seed_moments)
        if inserted:
            log.info("seed_moments_ok", inserted=inserted)
    except Exception as exc:
        log.warning("seed_moments_failed", error=str(exc))

    def _seed_content() -> dict:
        from .services.content_seed import seed_core_content

        with SessionLocal() as db:
            return seed_core_content(db)

    try:
        seeded = await asyncio.to_thread(_seed_content)
        if any(seeded.values()):
            log.info("seed_content_ok", **seeded)
    except Exception as exc:
        log.warning("seed_content_failed", error=str(exc))

    def _repair_listing_authors() -> dict:
        from .services.marketplace_author_repair import repair_orphan_listing_authors

        with SessionLocal() as db:
            return repair_orphan_listing_authors(db)

    try:
        repaired = await asyncio.to_thread(_repair_listing_authors)
        if repaired.get("repaired"):
            log.info("repair_listing_authors_ok", **repaired)
    except Exception as exc:
        log.warning("repair_listing_authors_failed", error=str(exc))

    from .services.chat_realtime import chat_realtime
    from .services.push_notifications import notification_worker

    if settings.CHAT_ENABLED:
        await chat_realtime.start()
    task = asyncio.create_task(_background_tick())
    push_task = (
        asyncio.create_task(notification_worker())
        if settings.CHAT_ENABLED and settings.PUSH_NOTIFICATIONS_ENABLED
        else None
    )
    try:
        yield
    finally:
        task.cancel()
        if push_task:
            push_task.cancel()
        # Suppress task cancellation on shutdown to avoid noisy tracebacks
        with contextlib.suppress(asyncio.CancelledError):
            await task
        if push_task:
            with contextlib.suppress(asyncio.CancelledError):
                await push_task
        if settings.CHAT_ENABLED:
            await chat_realtime.stop()


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
        response = None
        # Attach request identifier to structlog context
        import structlog

        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            path=request.url.path,
            method=request.method,
        )
        try:
            response = await call_next(request)
            return response
        finally:
            duration_ms = int((time.perf_counter() - start) * 1000)
            status_code = getattr(response, "status_code", 500) if response is not None else 500
            client_host = request.client.host if request.client else None

            # Enrich response with headers so clients can correlate logs
            if response is not None and hasattr(response, "headers"):
                response.headers["X-Request-ID"] = request_id
                response.headers["X-Response-Time"] = str(duration_ms)

            # Structured access log
            log.info(
                "http_request",
                request_id=request_id,
                method=request.method,
                path=str(request.url.path),
                query_keys=sorted(request.query_params.keys()),
                status_code=status_code,
                duration_ms=duration_ms,
                client_ip=client_host,
            )

            # Clear contextvars for this request
            structlog.contextvars.clear_contextvars()


app.add_middleware(RequestIDMiddleware)

# Rate limiting middleware & handler (slowapi)
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# Prometheus metrics must be registered BEFORE startup (instrumentator adds middleware).
if settings.APP_ENV.lower() != "test":
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
    backend_root = Path(__file__).resolve().parents[1]
    repository_root = backend_root.parent
    alembic_dir = backend_root / "alembic"
    alembic_config = backend_root / "alembic.ini"
    if not alembic_dir.exists() or not alembic_config.exists():
        log.warning("alembic_missing", path=str(alembic_dir))
        return False

    cmd = [sys.executable, "-m", "alembic", "-c", str(alembic_config), "upgrade", "head"]
    try:
        subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=repository_root,
        )
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


@app.get("/health", operation_id="health")
def health() -> dict:
    # Liveness
    return {"status": "ok"}


@app.head("/health", include_in_schema=False)
def health_head() -> None:
    return None


@app.get("/ready", operation_id="ready")
def ready() -> dict:
    from .core.readiness import run_readiness_checks

    try:
        return {"status": "ready", "checks": run_readiness_checks()}
    except Exception as exc:
        log.warning("readiness_failed", error=str(exc))
        raise HTTPException(status_code=503, detail="not ready") from exc


@app.head("/ready", include_in_schema=False)
def ready_head() -> None:
    ready()
    return None


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
app.include_router(marketplace_router, prefix=f"{API_PREFIX}/marketplace", tags=["marketplace"])
app.include_router(marketplace_admin_router, prefix=f"{API_PREFIX}/admin", tags=["admin", "marketplace"])
app.include_router(events_router, prefix=f"{API_PREFIX}/events", tags=["events"])
app.include_router(events_admin_router, prefix=f"{API_PREFIX}/admin", tags=["admin", "events"])
app.include_router(moments_router, prefix=f"{API_PREFIX}/moments", tags=["moments"])
app.include_router(moments_admin_router, prefix=f"{API_PREFIX}/admin", tags=["admin", "moments"])
app.include_router(experts_router, prefix=f"{API_PREFIX}/experts", tags=["experts"])
app.include_router(experts_admin_router, prefix=f"{API_PREFIX}/admin", tags=["admin", "experts"])
app.include_router(chat_router, prefix=f"{API_PREFIX}/chat", tags=["chat"])
app.include_router(chat_admin_router, prefix=f"{API_PREFIX}/admin", tags=["admin", "chat"])
app.include_router(devices_router, prefix=f"{API_PREFIX}/devices", tags=["devices"])

# Public pages (App Store / legal)
app.include_router(legal_router, tags=["legal"])

# Serve uploaded media
try:
    app.mount("/media", StaticFiles(directory="backend/uploads"), name="media")
except Exception:
    # directory may not exist at build time
    pass
