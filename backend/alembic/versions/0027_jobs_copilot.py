"""production jobs catalog, tracker, alerts and employer publishing

Revision ID: 0027_jobs_copilot
Revises: 0026_discovery_reviews
"""

import sqlalchemy as sa
from alembic import op

revision = "0027_jobs_copilot"
down_revision = "0026_discovery_reviews"
branch_labels = None
depends_on = None


def _timestamps() -> list[sa.Column]:
    return [
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    ]


def upgrade() -> None:
    # 0008 used UUID columns although users.id has always been varchar.
    op.alter_column("job_favorites", "id", type_=sa.String(36), postgresql_using="id::text")
    op.alter_column("job_favorites", "user_id", type_=sa.String(36), postgresql_using="user_id::text")
    op.alter_column("job_favorites", "job_id", type_=sa.String(255))
    op.alter_column("job_favorites", "source", type_=sa.String(40))
    op.alter_column("job_favorites", "title", type_=sa.String(300))
    op.alter_column("job_favorites", "company", type_=sa.String(250))
    op.alter_column("job_favorites", "location", type_=sa.String(300))
    op.alter_column("job_favorites", "canton", type_=sa.String(10))
    op.alter_column("job_favorites", "url", type_=sa.String(1200))
    op.execute("DELETE FROM job_favorites WHERE user_id NOT IN (SELECT id FROM users)")
    op.execute(
        "DELETE FROM job_favorites a USING job_favorites b "
        "WHERE a.ctid < b.ctid AND a.user_id = b.user_id AND a.job_id = b.job_id"
    )
    op.create_foreign_key("fk_job_favorites_user", "job_favorites", "users", ["user_id"], ["id"], ondelete="CASCADE")
    op.create_unique_constraint("uq_job_favorite_user_job", "job_favorites", ["user_id", "job_id"])
    op.alter_column("job_search_events", "id", type_=sa.String(36), postgresql_using="id::text")
    op.add_column("job_search_events", sa.Column("result_count", sa.Integer(), nullable=True))

    op.create_table(
        "jobs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("source", sa.String(40), nullable=False),
        sa.Column("source_job_id", sa.String(255), nullable=False),
        sa.Column("dedupe_key", sa.String(64), nullable=True),
        sa.Column("canonical_url", sa.String(1200), nullable=False),
        sa.Column("apply_url", sa.String(1200), nullable=False),
        sa.Column("title", sa.String(300), nullable=False),
        sa.Column("company", sa.String(250), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("snippet", sa.String(1200), nullable=True),
        sa.Column("location", sa.String(300), nullable=True),
        sa.Column("canton", sa.String(10), nullable=True),
        sa.Column("country", sa.String(2), server_default="CH", nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("employment_type", sa.String(60), nullable=True),
        sa.Column("workplace_type", sa.String(30), nullable=True),
        sa.Column("workload_min", sa.Integer(), nullable=True),
        sa.Column("workload_max", sa.Integer(), nullable=True),
        sa.Column("salary_text", sa.String(180), nullable=True),
        sa.Column("salary_min", sa.Integer(), nullable=True),
        sa.Column("salary_max", sa.Integer(), nullable=True),
        sa.Column("salary_currency", sa.String(3), server_default="CHF", nullable=False),
        sa.Column("salary_period", sa.String(20), nullable=True),
        sa.Column("languages", sa.JSON(), server_default=sa.text("'[]'::json"), nullable=False),
        sa.Column("skills", sa.JSON(), server_default=sa.text("'[]'::json"), nullable=False),
        sa.Column("permit_requirements", sa.JSON(), server_default=sa.text("'[]'::json"), nullable=False),
        sa.Column("translations", sa.JSON(), server_default=sa.text("'{}'::json"), nullable=False),
        sa.Column("experience_level", sa.String(30), nullable=True),
        sa.Column("no_experience_required", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("degree_required", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("recognition_required", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("employer_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("status", sa.String(20), server_default="active", nullable=False),
        sa.Column("is_verified", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("is_promoted", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("moderation_notes", sa.Text(), nullable=True),
        sa.Column("source_updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("posted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("first_seen_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        *_timestamps(),
        sa.UniqueConstraint("source", "source_job_id", name="uq_jobs_source_external"),
    )
    op.create_index("ix_jobs_search", "jobs", ["status", "canton", "employment_type", "posted_at"])
    op.create_index("ix_jobs_freshness", "jobs", ["status", "last_seen_at"])
    for column in ("source", "title", "company", "canton", "employment_type", "workplace_type", "employer_id", "status", "is_verified", "is_promoted", "posted_at", "dedupe_key"):
        op.create_index(f"ix_jobs_{column}", "jobs", [column])

    op.add_column("chat_conversations", sa.Column("job_id", sa.String(36), nullable=True))
    op.create_foreign_key(
        "fk_chat_conversations_job", "chat_conversations", "jobs", ["job_id"], ["id"], ondelete="SET NULL"
    )
    op.create_index("ix_chat_conversations_job_id", "chat_conversations", ["job_id"])
    op.create_unique_constraint(
        "uq_chat_job_participants", "chat_conversations", ["job_id", "buyer_id", "seller_id"]
    )

    op.create_table(
        "job_provider_states",
        sa.Column("provider", sa.String(60), primary_key=True),
        sa.Column("configured", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("status", sa.String(20), server_default="disabled", nullable=False),
        sa.Column("last_started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_success_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.String(500), nullable=True),
        sa.Column("last_item_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("consecutive_failures", sa.Integer(), server_default="0", nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_table(
        "job_applications",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("job_id", sa.String(255), nullable=False),
        sa.Column("job_title", sa.String(300), nullable=False),
        sa.Column("company", sa.String(250), nullable=True),
        sa.Column("location", sa.String(300), nullable=True),
        sa.Column("source", sa.String(40), nullable=False),
        sa.Column("job_url", sa.String(1200), nullable=False),
        sa.Column("status", sa.String(20), server_default="saved", nullable=False),
        sa.Column("notes", sa.String(2000), nullable=True),
        sa.Column("cover_letter", sa.Text(), nullable=True),
        sa.Column("applied_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("next_action_at", sa.DateTime(timezone=True), nullable=True),
        *_timestamps(),
        sa.UniqueConstraint("user_id", "job_id", name="uq_job_application_user_job"),
    )
    op.create_index("ix_job_applications_user_id", "job_applications", ["user_id"])
    op.create_index("ix_job_applications_job_id", "job_applications", ["job_id"])
    op.create_index("ix_job_applications_status", "job_applications", ["status"])
    op.create_table(
        "job_alerts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("keywords", sa.String(300), nullable=False),
        sa.Column("canton", sa.String(10), nullable=True),
        sa.Column("employment_type", sa.String(60), nullable=True),
        sa.Column("workplace_type", sa.String(30), nullable=True),
        sa.Column("min_salary", sa.Integer(), nullable=True),
        sa.Column("enabled", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("last_notified_at", sa.DateTime(timezone=True), nullable=True),
        *_timestamps(),
    )
    op.create_index("ix_job_alerts_user_id", "job_alerts", ["user_id"])
    op.create_table(
        "job_reports",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("job_id", sa.String(255), nullable=False),
        sa.Column("reporter_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reason", sa.String(40), nullable=False),
        sa.Column("details", sa.String(500), nullable=True),
        sa.Column("status", sa.String(20), server_default="open", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("job_id", "reporter_id", name="uq_job_report_job_user"),
    )
    op.create_index("ix_job_reports_job_id", "job_reports", ["job_id"])
    op.create_index("ix_job_reports_reporter_id", "job_reports", ["reporter_id"])
    op.create_index("ix_job_reports_status", "job_reports", ["status"])
    op.create_table(
        "job_employer_profiles",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("company_name", sa.String(250), nullable=False),
        sa.Column("website", sa.String(500), nullable=True),
        sa.Column("canton", sa.String(10), nullable=False),
        sa.Column("contact_name", sa.String(150), nullable=False),
        sa.Column("contact_email", sa.String(255), nullable=False),
        sa.Column("description", sa.String(2000), nullable=True),
        sa.Column("is_verified", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        *_timestamps(),
    )
    op.create_index("ix_job_employer_profiles_is_verified", "job_employer_profiles", ["is_verified"])


def downgrade() -> None:
    op.drop_constraint("uq_chat_job_participants", "chat_conversations", type_="unique")
    op.drop_index("ix_chat_conversations_job_id", table_name="chat_conversations")
    op.drop_constraint("fk_chat_conversations_job", "chat_conversations", type_="foreignkey")
    op.drop_column("chat_conversations", "job_id")
    op.drop_table("job_employer_profiles")
    op.drop_table("job_reports")
    op.drop_table("job_alerts")
    op.drop_table("job_applications")
    op.drop_table("job_provider_states")
    op.drop_table("jobs")
    op.drop_column("job_search_events", "result_count")
    op.alter_column("job_search_events", "id", type_=sa.UUID(), postgresql_using="id::uuid")
    op.drop_constraint("fk_job_favorites_user", "job_favorites", type_="foreignkey")
    op.drop_constraint("uq_job_favorite_user_job", "job_favorites", type_="unique")
    op.alter_column("job_favorites", "user_id", type_=sa.UUID(), postgresql_using="user_id::uuid")
    op.alter_column("job_favorites", "id", type_=sa.UUID(), postgresql_using="id::uuid")
