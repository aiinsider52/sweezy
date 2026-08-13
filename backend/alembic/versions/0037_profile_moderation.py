"""manual moderation for social and professional profiles

Revision ID: 0037_profile_moderation
Revises: 0036_subscription_purchase_dates
"""

import sqlalchemy as sa
from alembic import op


revision = "0037_profile_moderation"
down_revision = "0036_subscription_purchase_dates"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("social_profiles", "moderation_status", server_default="pending", existing_type=sa.String(20), existing_nullable=False)
    op.add_column("social_profiles", sa.Column("moderated_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("social_profiles", sa.Column("moderated_by", sa.String(36), nullable=True))
    op.create_foreign_key("fk_social_profiles_moderated_by", "social_profiles", "users", ["moderated_by"], ["id"], ondelete="SET NULL")
    op.execute("UPDATE social_profiles SET moderation_status = 'pending', moderation_reason = NULL")

    op.add_column("professional_profiles", sa.Column("moderation_status", sa.String(20), nullable=False, server_default="pending"))
    op.add_column("professional_profiles", sa.Column("moderation_reason", sa.String(500), nullable=True))
    op.add_column("professional_profiles", sa.Column("moderated_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("professional_profiles", sa.Column("moderated_by", sa.String(36), nullable=True))
    op.create_foreign_key("fk_professional_profiles_moderated_by", "professional_profiles", "users", ["moderated_by"], ["id"], ondelete="SET NULL")
    op.create_index("ix_professional_profiles_moderation_status", "professional_profiles", ["moderation_status"])


def downgrade() -> None:
    op.drop_index("ix_professional_profiles_moderation_status", table_name="professional_profiles")
    op.drop_constraint("fk_professional_profiles_moderated_by", "professional_profiles", type_="foreignkey")
    op.drop_column("professional_profiles", "moderated_by")
    op.drop_column("professional_profiles", "moderated_at")
    op.drop_column("professional_profiles", "moderation_reason")
    op.drop_column("professional_profiles", "moderation_status")
    op.execute("UPDATE social_profiles SET moderation_status = 'approved' WHERE moderation_status = 'pending'")
    op.alter_column("social_profiles", "moderation_status", server_default="approved", existing_type=sa.String(20), existing_nullable=False)
    op.drop_constraint("fk_social_profiles_moderated_by", "social_profiles", type_="foreignkey")
    op.drop_column("social_profiles", "moderated_by")
    op.drop_column("social_profiles", "moderated_at")
