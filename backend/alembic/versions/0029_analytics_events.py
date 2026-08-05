"""persistent consent-aware analytics

Revision ID: 0029_analytics_events
Revises: 0028_incident_management
"""

import sqlalchemy as sa
from alembic import op


revision = "0029_analytics_events"
down_revision = "0028_incident_management"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "analytics_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("client_session_id", sa.String(64), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("guest_id", sa.String(64), nullable=True),
        sa.Column("app_version", sa.String(32), nullable=True),
        sa.Column("platform", sa.String(24), server_default="ios", nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("event_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("consent_granted", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("client_session_id", name="uq_analytics_sessions_client_session"),
    )
    for column in ("user_id", "guest_id", "app_version"):
        op.create_index(f"ix_analytics_sessions_{column}", "analytics_sessions", [column])
    op.create_index("ix_analytics_sessions_last_seen", "analytics_sessions", ["last_seen_at"])

    op.create_table(
        "analytics_events",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("session_id", sa.String(36), sa.ForeignKey("analytics_sessions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("guest_id", sa.String(64), nullable=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("level", sa.String(10), server_default="info", nullable=False),
        sa.Column("source", sa.String(64), nullable=False),
        sa.Column("event_type", sa.String(96), nullable=False),
        sa.Column("message", sa.String(500), nullable=True),
        sa.Column("properties", sa.JSON(), server_default=sa.text("'{}'::json"), nullable=False),
        sa.Column("app_version", sa.String(32), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    for column in ("session_id", "user_id", "guest_id", "occurred_at", "event_type", "app_version"):
        op.create_index(f"ix_analytics_events_{column}", "analytics_events", [column])
    op.create_index("ix_analytics_events_occurred_type", "analytics_events", ["occurred_at", "event_type"])
    op.create_index("ix_analytics_events_actor_time", "analytics_events", ["user_id", "guest_id", "occurred_at"])


def downgrade() -> None:
    op.drop_table("analytics_events")
    op.drop_table("analytics_sessions")
