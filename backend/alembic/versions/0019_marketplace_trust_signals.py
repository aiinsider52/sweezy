"""add marketplace trust signals

Revision ID: 0019_marketplace_trust
Revises: 0018_social_auth
Create Date: 2026-04-29
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0019_marketplace_trust"
down_revision = "0018_social_auth"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("service_listings", sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    op.add_column("service_listings", sa.Column("is_featured", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    op.add_column("service_listings", sa.Column("trust_level", sa.String(length=30), nullable=False, server_default="community"))
    op.add_column("service_listings", sa.Column("partner_label", sa.String(length=80), nullable=True))
    op.add_column("service_listings", sa.Column("moderation_notes", sa.Text(), nullable=True))
    op.create_index("ix_service_listings_is_verified", "service_listings", ["is_verified"])
    op.create_index("ix_service_listings_is_featured", "service_listings", ["is_featured"])
    op.create_index("ix_service_listings_trust_level", "service_listings", ["trust_level"])
    op.alter_column("service_listings", "is_verified", server_default=None)
    op.alter_column("service_listings", "is_featured", server_default=None)
    op.alter_column("service_listings", "trust_level", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_service_listings_trust_level", table_name="service_listings")
    op.drop_index("ix_service_listings_is_featured", table_name="service_listings")
    op.drop_index("ix_service_listings_is_verified", table_name="service_listings")
    op.drop_column("service_listings", "moderation_notes")
    op.drop_column("service_listings", "partner_label")
    op.drop_column("service_listings", "trust_level")
    op.drop_column("service_listings", "is_featured")
    op.drop_column("service_listings", "is_verified")
