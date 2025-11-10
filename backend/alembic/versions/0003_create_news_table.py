"""create news table

Revision ID: 0003_create_news
Revises: 0002_add_image
Create Date: 2025-11-10 10:00:00.000000
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0003_create_news"
down_revision = "0002_add_image"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "news",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("title", sa.String(length=300), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False, server_default=""),
        sa.Column("url", sa.String(length=500), nullable=False),
        sa.Column("source", sa.String(length=120), nullable=False, server_default="Sweezy"),
        sa.Column("language", sa.String(length=8), nullable=False, server_default="uk"),
        sa.Column("published_at", sa.DateTime(), nullable=False),
        sa.Column("image_url", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_news_published_at", "news", ["published_at"])
    op.create_index("ix_news_language", "news", ["language"])


def downgrade() -> None:
    op.drop_index("ix_news_language", table_name="news")
    op.drop_index("ix_news_published_at", table_name="news")
    op.drop_table("news")


