from __future__ import annotations

import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import backend.app.models  # noqa: F401
from backend.app.core.database import Base, SessionLocal, engine
from backend.app.services.users import UserService


def main() -> None:
    if os.getenv("APP_ENV", "").lower() != "test":
        raise RuntimeError("Refusing to seed auth user outside APP_ENV=test")
    email = os.environ["AUTH_E2E_EMAIL"].strip().lower()
    password = os.environ["AUTH_E2E_PASSWORD"]
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        if UserService.get_by_email(db, email) is None:
            UserService.create(db, email=email, password=password, email_verified=True, role="user")


if __name__ == "__main__":
    main()
