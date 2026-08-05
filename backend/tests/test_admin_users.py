from __future__ import annotations

import asyncio
import hashlib
import json
from datetime import datetime, timezone

from backend.app.core.database import SessionLocal
from backend.app.models.audit_log import AuditLog
from backend.app.models.user import User
from backend.app.routers.admin import _csv_safe, export_audit_logs, export_users, list_users, user_stats


def _user(email: str, *, role: str = "viewer", active: bool = True, subscription: str = "free") -> User:
    return User(
        email=email,
        hashed_password="test",
        role=role,
        is_superuser=role == "admin",
        is_active=active,
        email_verified=active,
        subscription_status=subscription,
        created_at=datetime.now(timezone.utc),
    )


async def _stream_text(response) -> str:
    chunks = []
    async for chunk in response.body_iterator:
        chunks.append(chunk.decode() if isinstance(chunk, bytes) else chunk)
    return "".join(chunks)


def test_admin_user_pagination_filters_stats_and_csv() -> None:
    with SessionLocal() as db:
        emails = ["admin-list-a@example.test", "admin-list-b@example.test"]
        db.add_all([
            _user(emails[0], role="admin", subscription="premium"),
            _user(emails[1], active=False),
        ])
        db.commit()
        try:
            result = list_users(object(), db, page=1, page_size=25, search="admin-list-", role=None, status=None, subscription=None, created_from=None, created_to=None)
            assert result["total"] == 2
            assert {item["email"] for item in result["items"]} == set(emails)

            inactive = list_users(object(), db, page=1, page_size=25, search="admin-list-", role=None, status="inactive", subscription=None, created_from=None, created_to=None)
            assert inactive["total"] == 1
            assert inactive["items"][0]["is_active"] is False

            stats = user_stats(object(), db)
            assert stats["total"] >= 2
            assert stats["premium"] >= 1

            admin_user = db.query(User).filter(User.email == emails[0]).one()
            csv_text = asyncio.run(_stream_text(export_users(
                {"sub": admin_user.id},
                db,
                search="admin-list-",
                role=None,
                status=None,
                subscription=None,
                created_from=None,
                created_to=None,
                purpose="meta_custom_audience",
            )))
            assert csv_text.splitlines()[0] == "email"
            assert emails[0] not in csv_text
            assert hashlib.sha256(emails[0].encode()).hexdigest() in csv_text
            assert hashlib.sha256(emails[1].encode()).hexdigest() not in csv_text

            audit = (
                db.query(AuditLog)
                .filter(AuditLog.entity == "users", AuditLog.entity_id == "meta_custom_audience")
                .order_by(AuditLog.created_at.desc())
                .first()
            )
            assert audit is not None
            details = json.loads(audit.changes)
            assert details["row_count"] == 1
            assert details["outcome"] == "success"
            assert not any(email in audit.changes for email in emails)
            assert _csv_safe("=SUM(1,1)").startswith("'")

            audit_response = export_audit_logs(object(), db, limit=10)
            assert audit_response.media_type == "text/csv"
        finally:
            db.query(AuditLog).filter(
                AuditLog.entity == "users",
                AuditLog.entity_id == "meta_custom_audience",
            ).delete(synchronize_session=False)
            db.query(User).filter(User.email.in_(emails)).delete(synchronize_session=False)
            db.commit()
