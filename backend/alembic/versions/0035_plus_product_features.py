"""plus product features

Revision ID: 0035_plus_product_features
Revises: 0034_social_passport_plus
"""

import sqlalchemy as sa
from alembic import op

revision = "0035_plus_product_features"
down_revision = "0034_social_passport_plus"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("service_listings", sa.Column("featured_until", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_service_listings_featured_until", "service_listings", ["featured_until"])
    op.create_table(
        "social_profile_visits",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("profile_user_id", sa.String(36), sa.ForeignKey("social_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("visitor_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("visit_count", sa.Integer(), server_default="1", nullable=False),
        sa.Column("first_visited_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("last_visited_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("profile_user_id", "visitor_id", name="uq_social_profile_visit_pair"),
    )
    op.create_index("ix_social_profile_visits_profile_last", "social_profile_visits", ["profile_user_id", "last_visited_at"])


def downgrade() -> None:
    op.drop_table("social_profile_visits")
    op.drop_index("ix_service_listings_featured_until", table_name="service_listings")
    op.drop_column("service_listings", "featured_until")
