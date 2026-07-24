"""marketplace safety and official source metadata

Revision ID: 0023_trust_sources
Revises: 0022_backend_identity
Create Date: 2026-07-14
"""

from alembic import op
import sqlalchemy as sa


revision = "0023_trust_sources"
down_revision = "0022_backend_identity"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for table in ("guides", "checklists"):
        op.add_column(table, sa.Column("source_url", sa.String(length=1000), nullable=True))
        op.add_column(table, sa.Column("source_title", sa.String(length=255), nullable=True))
        op.add_column(table, sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True))

    op.add_column("service_listings", sa.Column("report_count", sa.Integer(), server_default="0", nullable=False))
    op.add_column("service_listings", sa.Column("last_moderated_at", sa.DateTime(timezone=True), nullable=True))

    op.create_table(
        "marketplace_reports",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("listing_id", sa.String(length=36), nullable=False),
        sa.Column("reporter_id", sa.String(length=36), nullable=False),
        sa.Column("reason", sa.String(length=40), nullable=False),
        sa.Column("details", sa.String(length=500), nullable=True),
        sa.Column("status", sa.String(length=20), server_default="open", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["listing_id"], ["service_listings.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("listing_id", "reporter_id", name="uq_marketplace_report_listing_user"),
    )
    op.create_index("ix_marketplace_reports_listing_id", "marketplace_reports", ["listing_id"])
    op.create_index("ix_marketplace_reports_reporter_id", "marketplace_reports", ["reporter_id"])
    op.create_index("ix_marketplace_reports_status", "marketplace_reports", ["status"])

    op.create_table(
        "marketplace_blocks",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("blocked_author_id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["blocked_author_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "blocked_author_id", name="uq_marketplace_block_user_author"),
    )
    op.create_index("ix_marketplace_blocks_user_id", "marketplace_blocks", ["user_id"])
    op.create_index("ix_marketplace_blocks_blocked_author_id", "marketplace_blocks", ["blocked_author_id"])


def downgrade() -> None:
    op.drop_table("marketplace_blocks")
    op.drop_table("marketplace_reports")
    op.drop_column("service_listings", "last_moderated_at")
    op.drop_column("service_listings", "report_count")
    for table in ("checklists", "guides"):
        op.drop_column(table, "verified_at")
        op.drop_column(table, "source_title")
        op.drop_column(table, "source_url")
