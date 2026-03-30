"""add brave news query storage and news import metadata

Revision ID: 0015_brave_news_queries
Revises: 0014_create_event_listings
Create Date: 2026-03-25
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0015_brave_news_queries"
down_revision = "0014_create_event_listings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("news", sa.Column("import_source", sa.String(length=24), nullable=False, server_default="manual"))
    op.add_column("news", sa.Column("import_reference_id", sa.String(length=36), nullable=True))
    op.create_index("ix_news_import_source", "news", ["import_source"])
    op.create_index("ix_news_import_reference_id", "news", ["import_reference_id"])
    op.alter_column("news", "import_source", server_default=None)

    op.create_table(
        "brave_news_queries",
        sa.Column("id", sa.String(length=36), primary_key=True, nullable=False),
        sa.Column("query", sa.String(length=300), nullable=False),
        sa.Column("language", sa.String(length=8), nullable=False, server_default="uk"),
        sa.Column("country", sa.String(length=8), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="published"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("max_results", sa.Integer(), nullable=False, server_default="8"),
        sa.Column("freshness_days", sa.Integer(), nullable=False, server_default="7"),
        sa.Column("last_imported_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
    )
    op.create_index("ix_brave_news_queries_enabled", "brave_news_queries", ["enabled"])


def downgrade() -> None:
    op.drop_index("ix_brave_news_queries_enabled", table_name="brave_news_queries")
    op.drop_table("brave_news_queries")

    op.drop_index("ix_news_import_reference_id", table_name="news")
    op.drop_index("ix_news_import_source", table_name="news")
    op.drop_column("news", "import_reference_id")
    op.drop_column("news", "import_source")
