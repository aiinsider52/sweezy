"""social passport search, invites and event chat

Revision ID: 0034_social_passport_plus
Revises: 0033_social_friends
"""

import sqlalchemy as sa
from alembic import op

revision = "0034_social_passport_plus"
down_revision = "0033_social_friends"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("social_profiles", sa.Column("availability", sa.JSON(), server_default=sa.text("'[]'"), nullable=False))
    op.add_column("social_profiles", sa.Column("age_band", sa.String(12), nullable=True))
    op.add_column("social_profiles", sa.Column("arrival_year", sa.Integer(), nullable=True))
    op.add_column("social_profiles", sa.Column("latitude", sa.Float(), nullable=True))
    op.add_column("social_profiles", sa.Column("longitude", sa.Float(), nullable=True))
    op.add_column("social_profiles", sa.Column("moderation_status", sa.String(20), server_default="approved", nullable=False))
    op.add_column("social_profiles", sa.Column("moderation_reason", sa.String(500), nullable=True))
    op.add_column("social_profiles", sa.Column("boosted_until", sa.DateTime(timezone=True), nullable=True))
    for name in ("age_band", "arrival_year", "moderation_status", "boosted_until"):
        op.create_index(f"ix_social_profiles_{name}", "social_profiles", [name])

    op.add_column("event_listings", sa.Column("is_private", sa.Boolean(), server_default=sa.text("false"), nullable=False))
    op.create_index("ix_event_listings_is_private", "event_listings", ["is_private"])

    op.create_table(
        "social_event_invites",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("event_id", sa.String(36), sa.ForeignKey("event_listings.id", ondelete="CASCADE"), nullable=False),
        sa.Column("inviter_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("invitee_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.String(20), server_default="pending", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("event_id", "invitee_id", name="uq_social_event_invitee"),
    )
    for name in ("event_id", "inviter_id", "invitee_id", "status"):
        op.create_index(f"ix_social_event_invites_{name}", "social_event_invites", [name])

    op.create_table(
        "social_event_messages",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("event_id", sa.String(36), sa.ForeignKey("event_listings.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sender_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("body", sa.String(1000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_social_event_messages_event_id", "social_event_messages", ["event_id"])
    op.create_index("ix_social_event_messages_sender_id", "social_event_messages", ["sender_id"])
    op.create_index("ix_social_event_messages_event_created", "social_event_messages", ["event_id", "created_at"])


def downgrade() -> None:
    op.drop_table("social_event_messages")
    op.drop_table("social_event_invites")
    op.drop_index("ix_event_listings_is_private", table_name="event_listings")
    op.drop_column("event_listings", "is_private")
    for name in ("boosted_until", "moderation_status", "arrival_year", "age_band"):
        op.drop_index(f"ix_social_profiles_{name}", table_name="social_profiles")
    for name in ("boosted_until", "moderation_reason", "moderation_status", "longitude", "latitude", "arrival_year", "age_band", "availability"):
        op.drop_column("social_profiles", name)
