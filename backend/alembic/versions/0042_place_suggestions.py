"""Community place suggestions with admin moderation

Revision ID: 0042_place_suggestions
Revises: 0041_multiregion_country_context
"""

import sqlalchemy as sa
from alembic import op

revision = "0042_place_suggestions"
down_revision = "0041_multiregion_country_context"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "place_suggestions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("country_code", sa.String(2), nullable=False, server_default="CH"),
        sa.Column("subdivision_code", sa.String(10), nullable=True),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("category", sa.String(30), nullable=False),
        sa.Column("street", sa.String(160), nullable=False),
        sa.Column("postal_code", sa.String(12), nullable=False),
        sa.Column("city", sa.String(80), nullable=False),
        sa.Column("website", sa.String(300), nullable=True),
        sa.Column("phone", sa.String(40), nullable=True),
        sa.Column("note", sa.String(600), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("rejection_reason", sa.String(300), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("status IN ('pending', 'approved', 'rejected')", name="ck_place_suggestion_status"),
    )
    op.create_index("ix_place_suggestions_user_id", "place_suggestions", ["user_id"])
    op.create_index("ix_place_suggestions_status", "place_suggestions", ["status"])
    op.create_index("ix_place_suggestions_country_code", "place_suggestions", ["country_code"])


def downgrade() -> None:
    op.drop_index("ix_place_suggestions_country_code", table_name="place_suggestions")
    op.drop_index("ix_place_suggestions_status", table_name="place_suggestions")
    op.drop_index("ix_place_suggestions_user_id", table_name="place_suggestions")
    op.drop_table("place_suggestions")
