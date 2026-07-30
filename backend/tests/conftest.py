from __future__ import annotations

import pytest

import backend.app.models  # noqa: F401
from backend.app.core.database import Base, engine
from backend.app.core.rate_limit import limiter


@pytest.fixture(scope="session", autouse=True)
def database_schema():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def reset_rate_limit_storage():
    """Keep per-route limits realistic without coupling TestClient cases."""
    limiter._storage.reset()
    yield
    limiter._storage.reset()
