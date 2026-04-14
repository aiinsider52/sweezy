"""add social auth identity columns

Revision ID: 0018_social_auth
Revises: 0017_marketplace_images
Create Date: 2026-04-14
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0018_social_auth"
down_revision = "0017_marketplace_images"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("password_login_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.add_column("users", sa.Column("apple_sub", sa.String(length=255), nullable=True))
    op.add_column("users", sa.Column("google_sub", sa.String(length=255), nullable=True))
    op.create_index("ix_users_apple_sub", "users", ["apple_sub"], unique=True)
    op.create_index("ix_users_google_sub", "users", ["google_sub"], unique=True)
    op.alter_column("users", "password_login_enabled", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_users_google_sub", table_name="users")
    op.drop_index("ix_users_apple_sub", table_name="users")
    op.drop_column("users", "google_sub")
    op.drop_column("users", "apple_sub")
    op.drop_column("users", "password_login_enabled")
