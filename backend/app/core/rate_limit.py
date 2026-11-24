"""
Centralized rate limiting configuration for the API.

Limits are keyed by the client address. Render terminates TLS in front of the app, so the socket
peer is always Render's proxy: keyed on that, one client could exhaust a limit for everyone. The key
is therefore the first X-Forwarded-For entry, the same address uvicorn would put in
`request.client.host` with `--forwarded-allow-ips '*'`, so it does not depend on how the service's
start command was set up. The service is only reachable through that proxy.

When REDIS_URL is configured the counters live in Redis, so they survive restarts and deploys and
are shared between workers. If Redis is unreachable the limiter falls back to memory instead of
failing requests.
"""

from __future__ import annotations

import os

from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request


def client_address(request: Request) -> str:
    """The caller's IP: first X-Forwarded-For entry behind the proxy, else the socket peer."""
    forwarded = request.headers.get("x-forwarded-for", "")
    first = forwarded.split(",", 1)[0].strip()
    return first or get_remote_address(request)


def _storage_uri() -> str | None:
    if os.getenv("APP_ENV", "").lower() == "test":
        return None
    url = os.getenv("REDIS_URL")
    if url and url.startswith(("redis://", "rediss://")):
        return url
    return None


_uri = _storage_uri()

# Global limiter instance. By default we don't enforce a global limit and
# instead configure limits per‑route for sensitive endpoints (auth, etc.).
limiter = Limiter(
    key_func=client_address,
    storage_uri=_uri or "memory://",
    key_prefix="sweezy-rl",
    swallow_errors=True,
    in_memory_fallback_enabled=bool(_uri),
)
