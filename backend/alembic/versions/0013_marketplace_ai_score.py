"""add ai score fields to service_listings

Revision ID: 0013_marketplace_ai_score
Revises: 0012_create_service_listings
Create Date: 2026-03-20
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0013_marketplace_ai_score"
down_revision = "0012_create_service_listings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("service_listings", sa.Column("ai_score", sa.Integer(), nullable=True))
    op.add_column("service_listings", sa.Column("ai_score_reason", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("service_listings", "ai_score_reason")
    op.drop_column("service_listings", "ai_score")
