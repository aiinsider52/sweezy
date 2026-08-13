"""unified reports, sanctions, notifications and moderation audit

Revision ID: 0038_reports_and_safety
Revises: 0037_profile_moderation
"""

import sqlalchemy as sa
from alembic import op


revision = "0038_reports_and_safety"
down_revision = "0037_profile_moderation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("safety_status", sa.String(20), nullable=False, server_default="active"))
    op.add_column("users", sa.Column("safety_suspended_until", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("safety_strike_count", sa.Integer(), nullable=False, server_default="0"))
    op.create_index("ix_users_safety_status", "users", ["safety_status"])
    op.create_index("ix_users_safety_suspended_until", "users", ["safety_suspended_until"])

    op.create_table(
        "moderation_cases",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("source_key", sa.String(180), nullable=False, unique=True),
        sa.Column("source_type", sa.String(40), nullable=False),
        sa.Column("source_id", sa.String(255), nullable=False),
        sa.Column("subject_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("reporter_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("reason", sa.String(40), nullable=False),
        sa.Column("details", sa.Text()),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("priority", sa.String(20), nullable=False, server_default="normal"),
        sa.Column("context_json", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("assigned_to", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("decision", sa.String(20)),
        sa.Column("moderator_comment", sa.Text()),
        sa.Column("resolved_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_moderation_cases_queue", "moderation_cases", ["status", "priority", "created_at"])
    op.create_index("ix_moderation_cases_subject", "moderation_cases", ["subject_user_id", "created_at"])
    op.create_index("ix_moderation_cases_source_type", "moderation_cases", ["source_type"])
    op.create_index("ix_moderation_cases_source_id", "moderation_cases", ["source_id"])
    op.create_index("ix_moderation_cases_reporter_id", "moderation_cases", ["reporter_id"])
    op.create_index("ix_moderation_cases_status", "moderation_cases", ["status"])
    op.create_index("ix_moderation_cases_priority", "moderation_cases", ["priority"])
    op.create_index("ix_moderation_cases_assigned_to", "moderation_cases", ["assigned_to"])

    op.create_table(
        "user_sanctions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("case_id", sa.String(36), sa.ForeignKey("moderation_cases.id", ondelete="SET NULL")),
        sa.Column("action", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("strike_points", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("expires_at", sa.DateTime(timezone=True)),
        sa.Column("created_by", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("revoked_by", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("revoke_reason", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_user_sanctions_active", "user_sanctions", ["user_id", "status", "expires_at"])
    op.create_index("ix_user_sanctions_case_id", "user_sanctions", ["case_id"])
    op.create_index("ix_user_sanctions_action", "user_sanctions", ["action"])

    op.create_table(
        "moderation_actions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("case_id", sa.String(36), sa.ForeignKey("moderation_cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("subject_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("moderator_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("action", sa.String(30), nullable=False),
        sa.Column("comment", sa.Text(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_moderation_actions_case_created", "moderation_actions", ["case_id", "created_at"])
    op.create_index("ix_moderation_actions_subject_user_id", "moderation_actions", ["subject_user_id"])
    op.create_index("ix_moderation_actions_moderator_id", "moderation_actions", ["moderator_id"])

    op.create_table(
        "moderation_notifications",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("event_key", sa.String(180), nullable=False, unique=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("case_id", sa.String(36), sa.ForeignKey("moderation_cases.id", ondelete="SET NULL")),
        sa.Column("kind", sa.String(30), nullable=False),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("body", sa.String(1000), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_moderation_notifications_user_read", "moderation_notifications", ["user_id", "read_at", "created_at"])
    op.create_index("ix_moderation_notifications_case_id", "moderation_notifications", ["case_id"])


def downgrade() -> None:
    op.drop_table("moderation_notifications")
    op.drop_table("moderation_actions")
    op.drop_table("user_sanctions")
    op.drop_table("moderation_cases")
    op.drop_index("ix_users_safety_suspended_until", table_name="users")
    op.drop_index("ix_users_safety_status", table_name="users")
    op.drop_column("users", "safety_strike_count")
    op.drop_column("users", "safety_suspended_until")
    op.drop_column("users", "safety_status")
