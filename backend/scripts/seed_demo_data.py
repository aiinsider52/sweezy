from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys

# Make the repo root importable regardless of current working directory
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app.core.database import Base, SessionLocal, engine  # noqa: E402
from backend.app.models import Appointment, Checklist, Guide, Template  # noqa: E402


def run() -> None:
    # Ensure tables exist (for local/dev convenience). Use Alembic in production.
    Base.metadata.create_all(bind=engine)

    with SessionLocal() as db:
        # Guides
        if not db.query(Guide).first():
            g1 = Guide(title="Getting Started", slug="getting-started", description="Intro guide", content="...")
            g2 = Guide(title="Pro Tips", slug="pro-tips", description="Advanced", content="...")
            db.add_all([g1, g2])

        # Checklists
        if not db.query(Checklist).first():
            c1 = Checklist(title="Launch Checklist", items=["Design", "Build", "Test", "Ship"]) 
            db.add(c1)

        # Templates
        if not db.query(Template).first():
            t1 = Template(name="Welcome Email", content="Hello {{name}}", category="email")
            db.add(t1)

        # Appointments
        if not db.query(Appointment).first():
            a1 = Appointment(
                title="Kickoff Call",
                description="Initial sync",
                scheduled_at=datetime.now(timezone.utc) + timedelta(days=1),
                duration_minutes=45,
            )
            db.add(a1)

        db.commit()
        print("Seeded demo data.")


if __name__ == "__main__":
    run()

