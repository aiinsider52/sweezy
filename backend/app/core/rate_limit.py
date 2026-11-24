"""
Centralized rate limiting configuration for the API.

Limits are keyed by the client address. Render terminates TLS in front of the app, so uvicorn runs
with `--proxy-headers --forwarded-allow-ips '*'` (see render.yaml) and the real client IP reaches
`request.client.host`; without that every request would share the proxy's address and one client
could exhaust a limit for everyone.

When REDIS_URL is configured the counters live in Redis, so they survive restarts and deploys and
are shared between workers. If Redis is unreachable the limiter falls back to memory instead of
failing requests.
"""

from __future__ import annotations

import os

from slowapi import Limiter
from slowapi.util import get_remote_address


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
    key_func=get_remote_address,
    storage_uri=_uri or "memory://",
    key_prefix="sweezy-rl",
    swallow_errors=True,
    in_memory_fallback_enabled=bool(_uri),
)
