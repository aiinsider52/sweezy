from __future__ import annotations

"""
Centralized rate limiting configuration for the API.

We use slowapi with an in‑memory store, which is enough for Render and
single‑process uvicorn. If you later move to multiple workers or a
separate worker tier, you can swap the storage backend here without
touching routers.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Global limiter instance. By default we don't enforce a global limit and
# instead configure limits per‑route for sensitive endpoints (auth, etc.).
limiter = Limiter(key_func=get_remote_address)


