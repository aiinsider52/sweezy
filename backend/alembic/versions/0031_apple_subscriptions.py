"""Apple subscription entitlements and server-side free quotas

Revision ID: 0031_apple_subscriptions
Revises: 0030_realtime_public_profiles
"""

import sqlalchemy as sa
from alembic import op


revision = "0031_apple_subscriptions"
down_revision = "0030_realtime_public_profiles"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("subscriptions", sa.Column("provider", sa.String(24), server_default="stripe", nullable=False))
    op.add_column("subscriptions", sa.Column("product_id", sa.String(160), nullable=True))
    op.add_column("subscriptions", sa.Column("original_transaction_id", sa.String(160), nullable=True))
    op.add_column("subscriptions", sa.Column("latest_transaction_id", sa.String(160), nullable=True))
    op.add_column("subscriptions", sa.Column("app_account_token", sa.String(36), nullable=True))
    op.add_column("subscriptions", sa.Column("environment", sa.String(24), nullable=True))
    op.add_column("subscriptions", sa.Column("auto_renew_enabled", sa.Boolean(), nullable=True))
    op.add_column("subscriptions", sa.Column("revocation_date", sa.DateTime(timezone=True), nullable=True))
    op.add_column("subscriptions", sa.Column("last_verified_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_subscriptions_provider", "subscriptions", ["provider"])
    op.create_index("ix_subscriptions_app_account_token", "subscriptions", ["app_account_token"])
    op.create_index("ix_subscriptions_original_transaction_id", "subscriptions", ["original_transaction_id"], unique=True)
    op.create_index("ix_subscriptions_latest_transaction_id", "subscriptions", ["latest_transaction_id"], unique=True)

    op.add_column("subscription_events", sa.Column("provider", sa.String(24), server_default="stripe", nullable=False))
    op.add_column("subscription_events", sa.Column("external_event_id", sa.String(160), nullable=True))
    op.create_index("ix_subscription_events_external_event_id", "subscription_events", ["external_event_id"], unique=True)

    op.create_table(
        "premium_usage",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("feature", sa.String(80), nullable=False),
        sa.Column("free_uses", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("user_id", "feature", name="uq_premium_usage_user_feature"),
    )
    op.create_index("ix_premium_usage_user_id", "premium_usage", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_premium_usage_user_id", table_name="premium_usage")
    op.drop_table("premium_usage")
    op.drop_index("ix_subscription_events_external_event_id", table_name="subscription_events")
    op.drop_column("subscription_events", "external_event_id")
    op.drop_column("subscription_events", "provider")
    op.drop_index("ix_subscriptions_latest_transaction_id", table_name="subscriptions")
    op.drop_index("ix_subscriptions_original_transaction_id", table_name="subscriptions")
    op.drop_index("ix_subscriptions_app_account_token", table_name="subscriptions")
    op.drop_index("ix_subscriptions_provider", table_name="subscriptions")
    op.drop_column("subscriptions", "last_verified_at")
    op.drop_column("subscriptions", "revocation_date")
    op.drop_column("subscriptions", "auto_renew_enabled")
    op.drop_column("subscriptions", "environment")
    op.drop_column("subscriptions", "app_account_token")
    op.drop_column("subscriptions", "latest_transaction_id")
    op.drop_column("subscriptions", "original_transaction_id")
    op.drop_column("subscriptions", "product_id")
    op.drop_column("subscriptions", "provider")
