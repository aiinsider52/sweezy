from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
import contextlib
from typing import List
import subprocess
from pathlib import Path
import os
import time as _time

import time
import uuid
from fastapi import FastAPI, HTTPException, Request
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi.middleware.cors import CORSMiddleware

from .core.config import get_settings
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


settings = get_settings()
try:
    settings.assert_valid()
except Exception as exc:
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
        response = await call_next(request)
        duration_ms = int((time.perf_counter() - start) * 1000)
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time"] = str(duration_ms)
        return response


app.add_middleware(RequestIDMiddleware)


def _run_migrations() -> None:
    # Run Alembic migrations only if scripts exist; ignore failures
    try:
        if Path("backend/alembic").exists():
            subprocess.run(["alembic", "-c", "backend/alembic.ini", "upgrade", "head"], check=False)
    except Exception:
        pass


@app.on_event("startup")
async def startup_event() -> None:
    # Run in a background thread so startup isn't blocked
    await asyncio.to_thread(_run_migrations)
    # Seed default admin (idempotent)
    from .core.database import SessionLocal
    from .services.users import seed_admin_user
    try:
        with SessionLocal() as db:
            seed_admin_user(db)
    except Exception:
        # don't block startup if seeding fails
        pass


@app.get("/health")
def health() -> dict:
    # Liveness
    return {"status": "ok"}


@app.get("/ready")
def ready() -> dict:
    # Readiness (DB connectivity)
    from sqlalchemy import text
    from .core.database import SessionLocal

    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
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

# Serve uploaded media
try:
    app.mount("/media", StaticFiles(directory="backend/uploads"), name="media")
except Exception:
    # directory may not exist at build time
    pass


