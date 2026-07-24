"""swiss moments + expert marketplace + expert questions

Revision ID: 0020_moments_experts
Revises: 0019_marketplace_trust
Create Date: 2026-04-29
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0020_moments_experts"
down_revision = "0019_marketplace_trust"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── swiss_moments ───────────────────────────────────────────────────────
    op.create_table(
        "swiss_moments",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("description_md", sa.Text(), nullable=False, server_default=""),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("recurrence", sa.String(length=16), nullable=False, server_default="yearly"),
        sa.Column("audience_filters", sa.JSON(), nullable=False),
        sa.Column("cta_kind", sa.String(length=20), nullable=False, server_default="link"),
        sa.Column("cta_payload", sa.JSON(), nullable=False),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_swiss_moments_key", "swiss_moments", ["key"], unique=True)
    op.create_index("ix_swiss_moments_starts_at", "swiss_moments", ["starts_at"])
    op.create_index("ix_swiss_moments_ends_at", "swiss_moments", ["ends_at"])
    op.create_index("ix_swiss_moments_is_active", "swiss_moments", ["is_active"])

    # ── service_listings: expert columns ────────────────────────────────────
    op.add_column(
        "service_listings",
        sa.Column("is_expert", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column("service_listings", sa.Column("expert_specialty", sa.String(length=40), nullable=True))
    op.add_column(
        "service_listings",
        sa.Column("expert_languages", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
    )
    op.add_column("service_listings", sa.Column("response_time_hours", sa.Integer(), nullable=True))
    op.add_column("service_listings", sa.Column("expert_bio", sa.Text(), nullable=True))
    op.create_index("ix_service_listings_is_expert", "service_listings", ["is_expert"])
    op.create_index("ix_service_listings_expert_specialty", "service_listings", ["expert_specialty"])
    op.alter_column("service_listings", "is_expert", server_default=None)
    op.alter_column("service_listings", "expert_languages", server_default=None)

    # ── expert_questions ────────────────────────────────────────────────────
    op.create_table(
        "expert_questions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("listing_id", sa.String(length=36), nullable=False),
        sa.Column("asked_by", sa.String(length=36), nullable=True),
        sa.Column("asker_name", sa.String(length=120), nullable=True),
        sa.Column("asker_language", sa.String(length=10), nullable=True),
        sa.Column("question_text", sa.Text(), nullable=False),
        sa.Column("answer_text", sa.Text(), nullable=True),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("answered_by", sa.String(length=36), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["listing_id"], ["service_listings.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_expert_questions_listing_id", "expert_questions", ["listing_id"])
    op.create_index("ix_expert_questions_status", "expert_questions", ["status"])
    op.create_index("ix_expert_questions_asked_by", "expert_questions", ["asked_by"])


def downgrade() -> None:
    op.drop_index("ix_expert_questions_asked_by", table_name="expert_questions")
    op.drop_index("ix_expert_questions_status", table_name="expert_questions")
    op.drop_index("ix_expert_questions_listing_id", table_name="expert_questions")
    op.drop_table("expert_questions")

    op.drop_index("ix_service_listings_expert_specialty", table_name="service_listings")
    op.drop_index("ix_service_listings_is_expert", table_name="service_listings")
    op.drop_column("service_listings", "expert_bio")
    op.drop_column("service_listings", "response_time_hours")
    op.drop_column("service_listings", "expert_languages")
    op.drop_column("service_listings", "expert_specialty")
    op.drop_column("service_listings", "is_expert")

    op.drop_index("ix_swiss_moments_is_active", table_name="swiss_moments")
    op.drop_index("ix_swiss_moments_ends_at", table_name="swiss_moments")
    op.drop_index("ix_swiss_moments_starts_at", table_name="swiss_moments")
    op.drop_index("ix_swiss_moments_key", table_name="swiss_moments")
    op.drop_table("swiss_moments")
