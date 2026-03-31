"""add email verification fields and auth email codes

Revision ID: 0016_auth_email_verification_codes
Revises: 0015_brave_news_queries
Create Date: 2026-03-31
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0016_auth_email_verification_codes"
down_revision = "0015_brave_news_queries"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("email_verified", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    op.add_column("users", sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_users_email_verified", "users", ["email_verified"])
    op.alter_column("users", "email_verified", server_default=None)

    op.create_table(
        "auth_email_codes",
        sa.Column("id", sa.String(length=36), primary_key=True, nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("purpose", sa.String(length=32), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_auth_email_codes_user_id", "auth_email_codes", ["user_id"])
    op.create_index("ix_auth_email_codes_email", "auth_email_codes", ["email"])
    op.create_index("ix_auth_email_codes_purpose", "auth_email_codes", ["purpose"])
    op.create_index("ix_auth_email_codes_expires_at", "auth_email_codes", ["expires_at"])


def downgrade() -> None:
    op.drop_index("ix_auth_email_codes_expires_at", table_name="auth_email_codes")
    op.drop_index("ix_auth_email_codes_purpose", table_name="auth_email_codes")
    op.drop_index("ix_auth_email_codes_email", table_name="auth_email_codes")
    op.drop_index("ix_auth_email_codes_user_id", table_name="auth_email_codes")
    op.drop_table("auth_email_codes")

    op.drop_index("ix_users_email_verified", table_name="users")
    op.drop_column("users", "email_verified_at")
    op.drop_column("users", "email_verified")
