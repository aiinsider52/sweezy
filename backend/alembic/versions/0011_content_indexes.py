"""add indexes for content tables

Revision ID: 0011_content_indexes
Revises: 0010_paywall_events
Create Date: 2026-01-02
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa  # noqa: F401


# revision identifiers, used by Alembic.
revision = "0011_content_indexes"
down_revision = "0010_paywall_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Guides: most queries filter by status/category and sort by created_at.
    op.create_index("ix_guides_created_at", "guides", ["created_at"])
    op.create_index("ix_guides_category", "guides", ["category"])
    op.create_index("ix_guides_status", "guides", ["status"])

    # Checklists
    op.create_index("ix_checklists_created_at", "checklists", ["created_at"])
    op.create_index("ix_checklists_status", "checklists", ["status"])

    # Templates
    op.create_index("ix_templates_created_at", "templates", ["created_at"])
    op.create_index("ix_templates_status", "templates", ["status"])
    op.create_index("ix_templates_category", "templates", ["category"])

    # News: status filter alongside existing indexes on published_at/language
    op.create_index("ix_news_status", "news", ["status"])

    # Appointments: frequently filtered by status/scheduled time
    op.create_index("ix_appointments_status", "appointments", ["status"])
    op.create_index("ix_appointments_scheduled_at", "appointments", ["scheduled_at"])


def downgrade() -> None:
    op.drop_index("ix_appointments_scheduled_at", table_name="appointments")
    op.drop_index("ix_appointments_status", table_name="appointments")
    op.drop_index("ix_news_status", table_name="news")
    op.drop_index("ix_templates_category", table_name="templates")
    op.drop_index("ix_templates_status", table_name="templates")
    op.drop_index("ix_templates_created_at", table_name="templates")
    op.drop_index("ix_checklists_status", table_name="checklists")
    op.drop_index("ix_checklists_created_at", table_name="checklists")
    op.drop_index("ix_guides_status", table_name="guides")
    op.drop_index("ix_guides_category", table_name="guides")
    op.drop_index("ix_guides_created_at", table_name="guides")



