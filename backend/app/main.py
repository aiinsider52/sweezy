from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
import contextlib
from typing import List
import subprocess
from pathlib import Path

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
from .routers.appointments import router as appointments_router
from .routers.remote_config import router as remote_config_router


settings = get_settings()
try:
    settings.assert_valid()
except Exception as exc:
    # Fail fast on invalid configuration
    raise


async def _background_tick() -> None:
    while True:
        await asyncio.sleep(60)
        # Placeholder for periodic background tasks (e.g. cache refresh)


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


