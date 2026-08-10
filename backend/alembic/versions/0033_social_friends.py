"""friends by interests and events

Revision ID: 0033_social_friends
Revises: 0032_professional_network
"""
import sqlalchemy as sa
from alembic import op

revision = "0033_social_friends"
down_revision = "0032_professional_network"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "social_profiles",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("display_name", sa.String(100), nullable=False), sa.Column("canton", sa.String(2), nullable=False),
        sa.Column("city", sa.String(80), nullable=False), sa.Column("bio", sa.String(600), nullable=False),
        sa.Column("interests", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column("languages", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column("meetup_formats", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column("avatar_url", sa.String(1000), nullable=True),
        sa.Column("is_visible", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("open_to_friends", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("guidelines_accepted", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("is_verified", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    for name in ("canton", "is_visible", "open_to_friends", "is_verified"):
        op.create_index(f"ix_social_profiles_{name}", "social_profiles", [name])

    op.add_column("chat_conversations", sa.Column("social_profile_id", sa.String(36), sa.ForeignKey("social_profiles.user_id", ondelete="SET NULL"), nullable=True))
    op.create_index("ix_chat_conversations_social_profile_id", "chat_conversations", ["social_profile_id"])
    op.create_unique_constraint("uq_chat_social_participants", "chat_conversations", ["social_profile_id", "buyer_id", "seller_id"])

    op.create_table(
        "friend_connections", sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("pair_key", sa.String(73), nullable=False, unique=True),
        sa.Column("requester_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("context_event_id", sa.String(36), sa.ForeignKey("event_listings.id", ondelete="SET NULL"), nullable=True),
        sa.Column("message", sa.String(500), nullable=True), sa.Column("shared_interests", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column("status", sa.String(20), server_default="pending", nullable=False),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("chat_conversations.id", ondelete="SET NULL"), nullable=True),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_friend_connections_status", "friend_connections", ["status"])
    op.create_index("ix_friend_connections_conversation_id", "friend_connections", ["conversation_id"])
    op.create_index("ix_friend_connections_target_status", "friend_connections", ["target_id", "status", "created_at"])
    op.create_index("ix_friend_connections_requester_status", "friend_connections", ["requester_id", "status", "created_at"])

    op.create_table(
        "event_attendance", sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("event_id", sa.String(36), sa.ForeignKey("event_listings.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("social_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.String(20), nullable=False), sa.Column("visible_to_attendees", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("event_id", "user_id", name="uq_event_attendance_user"),
    )
    for name in ("event_id", "user_id", "status"): op.create_index(f"ix_event_attendance_{name}", "event_attendance", [name])

    op.create_table(
        "social_profile_reports", sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("profile_user_id", sa.String(36), sa.ForeignKey("social_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("reporter_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reason", sa.String(40), nullable=False), sa.Column("details", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), server_default="open", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("profile_user_id", "reporter_id", name="uq_social_profile_reporter"),
    )
    for name in ("profile_user_id", "reporter_id", "status"): op.create_index(f"ix_social_profile_reports_{name}", "social_profile_reports", [name])


def downgrade() -> None:
    op.drop_table("social_profile_reports"); op.drop_table("event_attendance"); op.drop_table("friend_connections")
    op.drop_constraint("uq_chat_social_participants", "chat_conversations", type_="unique")
    op.drop_index("ix_chat_conversations_social_profile_id", table_name="chat_conversations")
    op.drop_column("chat_conversations", "social_profile_id"); op.drop_table("social_profiles")
