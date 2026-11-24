"""Revoke earlier tokens after a password reset or account deletion

Revision ID: 0046_tokens_valid_after
Revises: 0045_employer_notes
"""

import sqlalchemy as sa
from alembic import op

revision = "0046_tokens_valid_after"
down_revision = "0045_employer_notes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("tokens_valid_after", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "tokens_valid_after")
