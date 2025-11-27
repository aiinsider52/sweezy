"""create paywall_events table

Revision ID: 0010_paywall_events
Revises: 0009_subscriptions
Create Date: 2025-11-14
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


# revision identifiers, used by Alembic.
revision = "0010_paywall_events"
down_revision = "0009_subscriptions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS paywall_events (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36),
                event_type VARCHAR(64) NOT NULL,
                context VARCHAR(255),
                created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
    )
    op.execute(text("CREATE INDEX IF NOT EXISTS ix_paywall_events_user_id ON paywall_events (user_id)"))
    op.execute(text("CREATE INDEX IF NOT EXISTS ix_paywall_events_created_at ON paywall_events (created_at)"))


def downgrade() -> None:
    op.execute(text("DROP INDEX IF EXISTS ix_paywall_events_created_at"))
    op.execute(text("DROP INDEX IF EXISTS ix_paywall_events_user_id"))
    op.execute(text("DROP TABLE IF EXISTS paywall_events"))


