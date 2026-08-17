"""Private social swipes and mutual matches

Revision ID: 0040_social_swipe_discovery
Revises: 0039_sweezy_pro_business
"""

import sqlalchemy as sa
from alembic import op

revision = "0040_social_swipe_discovery"
down_revision = "0039_sweezy_pro_business"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "social_swipes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("swiper_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_id", sa.String(36), sa.ForeignKey("social_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("decision", sa.String(10), nullable=False),
        sa.Column("source", sa.String(20), nullable=False, server_default="discovery"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("swiper_id", "target_id", name="uq_social_swipe_pair"),
        sa.CheckConstraint("decision IN ('like', 'pass')", name="ck_social_swipe_decision"),
    )
    op.create_index("ix_social_swipes_swiper_created", "social_swipes", ["swiper_id", "created_at"])
    op.create_index("ix_social_swipes_target_decision", "social_swipes", ["target_id", "decision", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_social_swipes_target_decision", table_name="social_swipes")
    op.drop_index("ix_social_swipes_swiper_created", table_name="social_swipes")
    op.drop_table("social_swipes")
