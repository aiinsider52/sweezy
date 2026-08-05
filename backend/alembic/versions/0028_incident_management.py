"""incident management and alert deduplication

Revision ID: 0028_incident_management
Revises: 0027_jobs_copilot
"""

import sqlalchemy as sa
from alembic import op

revision = "0028_incident_management"
down_revision = "0027_jobs_copilot"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "incidents",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("fingerprint", sa.String(64), nullable=False),
        sa.Column("source", sa.String(64), nullable=False),
        sa.Column("severity", sa.String(16), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("context", sa.JSON(), server_default=sa.text("'{}'::json"), nullable=False),
        sa.Column("status", sa.String(16), server_default="open", nullable=False),
        sa.Column("occurrence_count", sa.Integer(), server_default="1", nullable=False),
        sa.Column("first_seen_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("notified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_by", sa.String(255), nullable=True),
        sa.UniqueConstraint("fingerprint", name="uq_incidents_fingerprint"),
    )
    for column in ("fingerprint", "source", "severity", "status"):
        op.create_index(f"ix_incidents_{column}", "incidents", [column])
    op.create_index("ix_incidents_status_last_seen", "incidents", ["status", "last_seen_at"])


def downgrade() -> None:
    op.drop_table("incidents")
