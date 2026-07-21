"""event trust controls and official source backfill

Revision ID: 0024_event_trust_sources
Revises: 0023_trust_sources
Create Date: 2026-07-15
"""

from alembic import op
import sqlalchemy as sa


revision = "0024_event_trust_sources"
down_revision = "0023_trust_sources"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("event_listings", sa.Column("is_verified", sa.Boolean(), server_default=sa.false(), nullable=False))
    op.add_column("event_listings", sa.Column("report_count", sa.Integer(), server_default="0", nullable=False))
    op.add_column("event_listings", sa.Column("last_moderated_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_event_listings_is_verified", "event_listings", ["is_verified"])

    op.create_table(
        "event_reports",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("event_id", sa.String(length=36), nullable=False),
        sa.Column("reporter_id", sa.String(length=36), nullable=False),
        sa.Column("reason", sa.String(length=40), nullable=False),
        sa.Column("details", sa.String(length=500), nullable=True),
        sa.Column("status", sa.String(length=20), server_default="open", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["event_id"], ["event_listings.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("event_id", "reporter_id", name="uq_event_report_event_user"),
    )
    op.create_index("ix_event_reports_event_id", "event_reports", ["event_id"])
    op.create_index("ix_event_reports_reporter_id", "event_reports", ["reporter_id"])
    op.create_index("ix_event_reports_status", "event_reports", ["status"])

    verified_at = "2026-07-15 00:00:00+00"
    guide_sources = {
        "housing": ("https://www.ch.ch/en/housing/", "ch.ch — Housing"),
        "insurance": ("https://www.ch.ch/en/health/health-insurance/", "ch.ch — Health insurance"),
        "healthcare": ("https://www.ch.ch/en/health/", "ch.ch — Health"),
        "finance": ("https://www.ch.ch/en/taxes-and-finances/", "ch.ch — Taxes and finances"),
        "education": ("https://www.ch.ch/en/school-and-education/", "ch.ch — School and education"),
        "banking": ("https://www.finma.ch/en/finma-public/fragen-und-probleme/", "FINMA — Consumer information"),
        "integration": ("https://www.sem.admin.ch/sem/en/home/integration-einbuergerung.html", "SEM — Integration"),
    }
    for category, (url, title) in guide_sources.items():
        op.execute(
            sa.text(
                "UPDATE guides SET source_url = COALESCE(source_url, :url), "
                "source_title = COALESCE(source_title, :title), verified_at = COALESCE(verified_at, :verified_at) "
                "WHERE category = :category"
            ).bindparams(url=url, title=title, verified_at=verified_at, category=category)
        )
    op.execute(
        sa.text(
            "UPDATE guides SET source_url = COALESCE(source_url, :url), "
            "source_title = COALESCE(source_title, :title), verified_at = COALESCE(verified_at, :verified_at) "
            "WHERE source_url IS NULL OR source_title IS NULL OR verified_at IS NULL"
        ).bindparams(url="https://www.ch.ch/en/", title="ch.ch — Swiss authorities online", verified_at=verified_at)
    )
    op.execute(
        sa.text(
            "UPDATE checklists SET source_url = COALESCE(source_url, :url), "
            "source_title = COALESCE(source_title, :title), verified_at = COALESCE(verified_at, :verified_at) "
            "WHERE source_url IS NULL OR source_title IS NULL OR verified_at IS NULL"
        ).bindparams(url="https://www.ch.ch/en/foreign-nationals-in-switzerland/", title="ch.ch — Foreign nationals", verified_at=verified_at)
    )


def downgrade() -> None:
    op.drop_table("event_reports")
    op.drop_index("ix_event_listings_is_verified", table_name="event_listings")
    op.drop_column("event_listings", "last_moderated_at")
    op.drop_column("event_listings", "report_count")
    op.drop_column("event_listings", "is_verified")
