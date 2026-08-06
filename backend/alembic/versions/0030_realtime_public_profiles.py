"""realtime receipts and privacy-safe public profiles

Revision ID: 0030_realtime_public_profiles
Revises: 0029_analytics_events
"""

import sqlalchemy as sa
from alembic import op


revision = "0030_realtime_public_profiles"
down_revision = "0029_analytics_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("chat_messages", sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("chat_messages", sa.Column("read_at", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "public_user_profiles",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("display_name", sa.String(100), nullable=False),
        sa.Column("avatar_url", sa.String(1000), nullable=True),
        sa.Column("is_verified", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("trust_badge", sa.String(40), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.execute(
        """
        INSERT INTO public_user_profiles (user_id, display_name, is_verified, created_at, updated_at)
        SELECT u.id, LEFT(l.author_name, 100), u.email_verified, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM users u
        JOIN (
            SELECT DISTINCT ON (author_id) author_id, author_name
            FROM service_listings
            WHERE author_id IS NOT NULL AND status = 'approved' AND BTRIM(author_name) <> ''
            ORDER BY author_id, updated_at DESC
        ) l ON l.author_id = u.id
        """
    )


def downgrade() -> None:
    op.drop_table("public_user_profiles")
    op.drop_column("chat_messages", "read_at")
    op.drop_column("chat_messages", "delivered_at")
