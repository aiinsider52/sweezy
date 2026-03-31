"""add image urls to service listings

Revision ID: 0017_marketplace_images
Revises: 0016_auth_email_codes
Create Date: 2026-03-31
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0017_marketplace_images"
down_revision = "0016_auth_email_codes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "service_listings",
        sa.Column("image_urls", sa.JSON(), nullable=False, server_default=sa.text("'[]'::json")),
    )
    op.alter_column("service_listings", "image_urls", server_default=None)


def downgrade() -> None:
    op.drop_column("service_listings", "image_urls")
