"""create service_listings table for marketplace

Revision ID: 0012_create_service_listings
Revises: 0011_content_indexes
Create Date: 2026-03-19
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0012_create_service_listings"
down_revision = "0011_content_indexes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "service_listings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("title", sa.String(100), nullable=False),
        sa.Column("description", sa.String(1000), nullable=False),
        sa.Column("category", sa.String(30), nullable=False),
        sa.Column("canton", sa.String(10), nullable=False),
        sa.Column("price_info", sa.String(100), nullable=True),
        sa.Column("contact_type", sa.String(20), nullable=False),
        sa.Column("contact_value", sa.String(255), nullable=False),
        sa.Column("author_id", sa.String(36), nullable=True),
        sa.Column("author_name", sa.String(100), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("rejection_reason", sa.Text, nullable=True),
        sa.Column("view_count", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_index("ix_service_listings_category", "service_listings", ["category"])
    op.create_index("ix_service_listings_canton", "service_listings", ["canton"])
    op.create_index("ix_service_listings_status", "service_listings", ["status"])
    op.create_index("ix_service_listings_author_id", "service_listings", ["author_id"])
    op.create_index("ix_service_listings_created_at", "service_listings", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_service_listings_created_at", table_name="service_listings")
    op.drop_index("ix_service_listings_author_id", table_name="service_listings")
    op.drop_index("ix_service_listings_status", table_name="service_listings")
    op.drop_index("ix_service_listings_canton", table_name="service_listings")
    op.drop_index("ix_service_listings_category", table_name="service_listings")
    op.drop_table("service_listings")
