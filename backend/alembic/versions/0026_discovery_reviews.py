"""Add ratings, comments and moderation for Swiss Discovery places.

Revision ID: 0026_discovery_reviews
Revises: 0025_production_chat
Create Date: 2026-08-02
"""

import sqlalchemy as sa
from alembic import op

revision = "0026_discovery_reviews"
down_revision = "0025_production_chat"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "discovery_reviews",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("place_id", sa.String(80), nullable=False),
        sa.Column("user_id", sa.String(36), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("comment", sa.String(1000), nullable=False),
        sa.Column("status", sa.String(20), server_default="published", nullable=False),
        sa.Column("report_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("rating >= 1 AND rating <= 5", name="ck_discovery_review_rating"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("place_id", "user_id", name="uq_discovery_review_place_user"),
    )
    op.create_index("ix_discovery_reviews_place_id", "discovery_reviews", ["place_id"])
    op.create_index("ix_discovery_reviews_user_id", "discovery_reviews", ["user_id"])
    op.create_index("ix_discovery_reviews_status", "discovery_reviews", ["status"])

    op.create_table(
        "discovery_review_reports",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("review_id", sa.String(36), nullable=False),
        sa.Column("reporter_id", sa.String(36), nullable=False),
        sa.Column("reason", sa.String(40), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["review_id"], ["discovery_reviews.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("review_id", "reporter_id", name="uq_discovery_review_reporter"),
    )
    op.create_index("ix_discovery_review_reports_review_id", "discovery_review_reports", ["review_id"])
    op.create_index("ix_discovery_review_reports_reporter_id", "discovery_review_reports", ["reporter_id"])


def downgrade() -> None:
    op.drop_table("discovery_review_reports")
    op.drop_table("discovery_reviews")
