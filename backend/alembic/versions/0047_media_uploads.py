"""Record who uploaded each stored image so it can be erased with the account

Revision ID: 0047_media_uploads
Revises: 0046_tokens_valid_after
"""

import sqlalchemy as sa
from alembic import op

revision = "0047_media_uploads"
down_revision = "0046_tokens_valid_after"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "media_uploads",
        sa.Column("key", sa.String(64), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_media_uploads_user_id", "media_uploads", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_media_uploads_user_id", table_name="media_uploads")
    op.drop_table("media_uploads")
