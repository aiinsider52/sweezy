"""create event_listings table

Revision ID: 0014_create_event_listings
Revises: 0013_marketplace_ai_score
Create Date: 2026-03-23
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0014_create_event_listings"
down_revision = "0013_marketplace_ai_score"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "event_listings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("description", sa.String(2000), nullable=False),
        sa.Column("category", sa.String(30), nullable=False),
        sa.Column("canton", sa.String(10), nullable=False),
        sa.Column("city", sa.String(120), nullable=False),
        sa.Column("venue_name", sa.String(150), nullable=True),
        sa.Column("address", sa.String(255), nullable=True),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_free", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("price_info", sa.String(100), nullable=True),
        sa.Column("contact_type", sa.String(20), nullable=False),
        sa.Column("contact_value", sa.String(255), nullable=False),
        sa.Column("organizer_name", sa.String(100), nullable=False),
        sa.Column("author_id", sa.String(36), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("rejection_reason", sa.Text(), nullable=True),
        sa.Column("view_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_index("ix_event_listings_category", "event_listings", ["category"])
    op.create_index("ix_event_listings_canton", "event_listings", ["canton"])
    op.create_index("ix_event_listings_starts_at", "event_listings", ["starts_at"])
    op.create_index("ix_event_listings_author_id", "event_listings", ["author_id"])
    op.create_index("ix_event_listings_status", "event_listings", ["status"])


def downgrade() -> None:
    op.drop_index("ix_event_listings_status", table_name="event_listings")
    op.drop_index("ix_event_listings_author_id", table_name="event_listings")
    op.drop_index("ix_event_listings_starts_at", table_name="event_listings")
    op.drop_index("ix_event_listings_canton", table_name="event_listings")
    op.drop_index("ix_event_listings_category", table_name="event_listings")
    op.drop_table("event_listings")
