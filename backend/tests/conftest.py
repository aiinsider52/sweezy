from __future__ import annotations

import pytest

import backend.app.models  # noqa: F401
from backend.app.core.database import Base, engine


@pytest.fixture(scope="session", autouse=True)
def database_schema():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
