"""create paywall_events table

Revision ID: 0010_paywall_events
Revises: 0009_subscriptions
Create Date: 2025-11-14
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0010_paywall_events"
down_revision = "0009_subscriptions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "paywall_events",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), nullable=True, index=True),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("context", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_paywall_events_user_id", "paywall_events", ["user_id"])
    op.create_index("ix_paywall_events_created_at", "paywall_events", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_paywall_events_created_at", table_name="paywall_events")
    op.drop_index("ix_paywall_events_user_id", table_name="paywall_events")
    op.drop_table("paywall_events")


