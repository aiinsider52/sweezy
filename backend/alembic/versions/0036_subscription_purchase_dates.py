"""subscription purchase dates

Revision ID: 0036_subscription_purchase_dates
Revises: 0035_plus_product_features
"""

import sqlalchemy as sa
from alembic import op


revision = "0036_subscription_purchase_dates"
down_revision = "0035_plus_product_features"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("subscriptions", sa.Column("purchased_at", sa.DateTime(timezone=True), nullable=True))
    op.execute("UPDATE subscriptions SET purchased_at = created_at WHERE purchased_at IS NULL")
    op.create_index("ix_subscriptions_purchased_at", "subscriptions", ["purchased_at"])


def downgrade() -> None:
    op.drop_index("ix_subscriptions_purchased_at", table_name="subscriptions")
    op.drop_column("subscriptions", "purchased_at")
