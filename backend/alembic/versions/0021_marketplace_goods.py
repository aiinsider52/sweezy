"""add goods marketplace fields to service_listings

Revision ID: 0021_marketplace_goods
Revises: 0020_moments_experts
Create Date: 2026-06-10
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0021_marketplace_goods"
down_revision = "0020_moments_experts"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "service_listings",
        sa.Column("listing_type", sa.String(length=20), nullable=False, server_default="service"),
    )
    op.add_column("service_listings", sa.Column("price_chf", sa.Integer(), nullable=True))
    op.add_column(
        "service_listings",
        sa.Column("is_free", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column("service_listings", sa.Column("condition", sa.String(length=20), nullable=True))
    op.add_column(
        "service_listings",
        sa.Column("negotiable", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.create_index("ix_service_listings_listing_type", "service_listings", ["listing_type"])
    op.alter_column("service_listings", "listing_type", server_default=None)
    op.alter_column("service_listings", "is_free", server_default=None)
    op.alter_column("service_listings", "negotiable", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_service_listings_listing_type", table_name="service_listings")
    op.drop_column("service_listings", "negotiable")
    op.drop_column("service_listings", "condition")
    op.drop_column("service_listings", "is_free")
    op.drop_column("service_listings", "price_chf")
    op.drop_column("service_listings", "listing_type")
