"""Multiregion country context for Switzerland, Germany, and Austria.

Revision ID: 0041_multiregion_country_context
Revises: 0040_social_swipe_discovery
"""

import sqlalchemy as sa
from alembic import op


revision = "0041_multiregion_country_context"
down_revision = "0040_social_swipe_discovery"
branch_labels = None
depends_on = None


def _add_content_scope(table: str, *, language: bool = True, validity: bool = False) -> None:
    op.add_column(table, sa.Column("country_code", sa.String(2), nullable=False, server_default="CH"))
    op.add_column(table, sa.Column("subdivision_codes", sa.JSON(), nullable=False, server_default="[]"))
    if language:
        op.add_column(table, sa.Column("language", sa.String(10), nullable=False, server_default="uk"))
    if validity:
        op.add_column(table, sa.Column("valid_from", sa.DateTime(timezone=True), nullable=True))
        op.add_column(table, sa.Column("valid_until", sa.DateTime(timezone=True), nullable=True))
    op.create_index(f"ix_{table}_country_code", table, ["country_code"])
    if language:
        op.create_index(f"ix_{table}_language", table, ["language"])


def _add_community_scope(table: str, *, currency: bool = False) -> None:
    op.add_column(table, sa.Column("country_code", sa.String(2), nullable=False, server_default="CH"))
    op.add_column(table, sa.Column("subdivision_code", sa.String(10), nullable=False, server_default="ZH"))
    if currency:
        op.add_column(table, sa.Column("currency_code", sa.String(3), nullable=False, server_default="CHF"))
    op.create_index(f"ix_{table}_country_code", table, ["country_code"])
    op.create_index(f"ix_{table}_subdivision_code", table, ["subdivision_code"])


def upgrade() -> None:
    op.create_table(
        "user_country_contexts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("country_code", sa.String(2), nullable=False, server_default="CH"),
        sa.Column("subdivision_code", sa.String(10), nullable=True),
        sa.Column("city", sa.String(120), nullable=True),
        sa.Column("residence_status", sa.String(40), nullable=True),
        sa.Column("preferred_language", sa.String(10), nullable=False, server_default="uk"),
        sa.Column("currency_code", sa.String(3), nullable=False, server_default="CHF"),
        sa.Column("timezone", sa.String(50), nullable=False, server_default="Europe/Zurich"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "country_code", name="uq_user_country_context_country"),
    )
    op.create_index("ix_user_country_contexts_user_id", "user_country_contexts", ["user_id"])
    op.create_index("ix_user_country_contexts_country_code", "user_country_contexts", ["country_code"])
    op.create_index("ix_user_country_contexts_subdivision_code", "user_country_contexts", ["subdivision_code"])
    op.create_index("ix_user_country_contexts_is_active", "user_country_contexts", ["is_active"])
    op.create_index("ix_user_country_context_active", "user_country_contexts", ["user_id", "is_active"])
    op.create_index(
        "uq_user_country_context_active",
        "user_country_contexts",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("is_active"),
    )

    _add_content_scope("guides", validity=True)
    _add_content_scope("checklists", validity=True)
    _add_content_scope("templates")
    _add_content_scope("news", language=False)

    _add_community_scope("service_listings", currency=True)
    op.add_column("service_listings", sa.Column("price_minor", sa.Integer(), nullable=True))
    op.execute("UPDATE service_listings SET subdivision_code = canton, price_minor = price_chf * 100 WHERE country_code = 'CH'")
    _add_community_scope("event_listings", currency=True)
    op.execute("UPDATE event_listings SET subdivision_code = canton WHERE country_code = 'CH'")
    _add_community_scope("professional_profiles")
    op.execute("UPDATE professional_profiles SET subdivision_code = canton WHERE country_code = 'CH'")
    _add_community_scope("social_profiles")
    op.alter_column("social_profiles", "canton", existing_type=sa.String(2), type_=sa.String(10), nullable=False)
    op.execute("UPDATE social_profiles SET subdivision_code = canton WHERE country_code = 'CH'")
    _add_community_scope("business_profiles")
    op.execute("UPDATE business_profiles SET subdivision_code = canton WHERE country_code = 'CH'")

    for table in ("job_favorites", "job_alerts", "job_employer_profiles", "job_search_events"):
        op.add_column(table, sa.Column("country", sa.String(2), nullable=False, server_default="CH"))
        op.create_index(f"ix_{table}_country", table, ["country"])

    op.create_index("ix_jobs_country_search", "jobs", ["country", "status", "canton", "posted_at"])


def downgrade() -> None:
    op.drop_index("ix_jobs_country_search", table_name="jobs")
    for table in ("job_search_events", "job_employer_profiles", "job_alerts", "job_favorites"):
        op.drop_index(f"ix_{table}_country", table_name=table)
        op.drop_column(table, "country")

    for table in ("business_profiles", "social_profiles", "professional_profiles"):
        op.drop_index(f"ix_{table}_subdivision_code", table_name=table)
        op.drop_index(f"ix_{table}_country_code", table_name=table)
        op.drop_column(table, "subdivision_code")
        op.drop_column(table, "country_code")
    op.alter_column("social_profiles", "canton", existing_type=sa.String(10), type_=sa.String(2), nullable=False)
    for table in ("event_listings", "service_listings"):
        if table == "service_listings":
            op.drop_column(table, "price_minor")
        op.drop_column(table, "currency_code")
        op.drop_index(f"ix_{table}_subdivision_code", table_name=table)
        op.drop_index(f"ix_{table}_country_code", table_name=table)
        op.drop_column(table, "subdivision_code")
        op.drop_column(table, "country_code")

    for table, has_language, has_validity in (
        ("news", False, False), ("templates", True, False),
        ("checklists", True, True), ("guides", True, True),
    ):
        if has_validity:
            op.drop_column(table, "valid_until")
            op.drop_column(table, "valid_from")
        if has_language:
            op.drop_index(f"ix_{table}_language", table_name=table)
            op.drop_column(table, "language")
        op.drop_index(f"ix_{table}_country_code", table_name=table)
        op.drop_column(table, "subdivision_codes")
        op.drop_column(table, "country_code")

    op.drop_index("uq_user_country_context_active", table_name="user_country_contexts")
    op.drop_index("ix_user_country_context_active", table_name="user_country_contexts")
    op.drop_index("ix_user_country_contexts_is_active", table_name="user_country_contexts")
    op.drop_index("ix_user_country_contexts_subdivision_code", table_name="user_country_contexts")
    op.drop_index("ix_user_country_contexts_country_code", table_name="user_country_contexts")
    op.drop_index("ix_user_country_contexts_user_id", table_name="user_country_contexts")
    op.drop_table("user_country_contexts")
