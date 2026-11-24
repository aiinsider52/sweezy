"""Engagement push preferences, saved-listing price watches and marketplace follows

Revision ID: 0044_engagement_notifications
Revises: 0043_business_growth
"""

import sqlalchemy as sa
from alembic import op

revision = "0044_engagement_notifications"
down_revision = "0043_business_growth"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notification_preferences",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("locale", sa.String(5), nullable=False, server_default="uk"),
        sa.Column("timezone", sa.String(64), nullable=False, server_default="Europe/Zurich"),
        sa.Column("social_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("events_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("marketplace_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("likes_digest_sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("events_checked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_table(
        "marketplace_watches",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("listing_id", sa.String(36), sa.ForeignKey("service_listings.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "listing_id", name="uq_marketplace_watch_user_listing"),
    )
    op.create_index("ix_marketplace_watches_user_id", "marketplace_watches", ["user_id"])
    op.create_index("ix_marketplace_watches_listing_id", "marketplace_watches", ["listing_id"])
    op.create_table(
        "marketplace_follows",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("country_code", sa.String(2), nullable=False),
        sa.Column("subdivision_code", sa.String(10), nullable=False),
        sa.Column("category", sa.String(30), nullable=False, server_default=""),
        sa.Column("last_notified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "country_code", "subdivision_code", "category", name="uq_marketplace_follow"),
    )
    op.create_index("ix_marketplace_follows_user_id", "marketplace_follows", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_marketplace_follows_user_id", table_name="marketplace_follows")
    op.drop_table("marketplace_follows")
    op.drop_index("ix_marketplace_watches_listing_id", table_name="marketplace_watches")
    op.drop_index("ix_marketplace_watches_user_id", table_name="marketplace_watches")
    op.drop_table("marketplace_watches")
    op.drop_table("notification_preferences")
