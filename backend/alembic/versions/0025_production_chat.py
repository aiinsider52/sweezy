"""Add production marketplace chat, moderation, reviews and push outbox.

Revision ID: 0025_production_chat
Revises: 0024_event_trust_sources
Create Date: 2026-07-20
"""

from alembic import op
import sqlalchemy as sa


revision = "0025_production_chat"
down_revision = "0024_event_trust_sources"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_conversations",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("listing_id", sa.String(36), nullable=True),
        sa.Column("buyer_id", sa.String(36), nullable=False),
        sa.Column("seller_id", sa.String(36), nullable=False),
        sa.Column("listing_type", sa.String(20), nullable=False),
        sa.Column("listing_title", sa.String(100), nullable=False),
        sa.Column("listing_image_url", sa.String(1000), nullable=True),
        sa.Column("listing_price", sa.String(100), nullable=True),
        sa.Column("seller_name", sa.String(100), nullable=False),
        sa.Column("status", sa.String(20), server_default="active", nullable=False),
        sa.Column("last_message_preview", sa.String(240), nullable=True),
        sa.Column("last_message_sender_id", sa.String(36), nullable=True),
        sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["listing_id"], ["service_listings.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["buyer_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["seller_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("listing_id", "buyer_id", "seller_id", name="uq_chat_listing_participants"),
    )
    op.create_index("ix_chat_conversations_listing_id", "chat_conversations", ["listing_id"])
    op.create_index("ix_chat_conversations_buyer_id", "chat_conversations", ["buyer_id"])
    op.create_index("ix_chat_conversations_seller_id", "chat_conversations", ["seller_id"])
    op.create_index("ix_chat_conversations_status", "chat_conversations", ["status"])
    op.create_index("ix_chat_conversations_last_message_at", "chat_conversations", ["last_message_at"])
    op.create_index("ix_chat_conversations_buyer_last", "chat_conversations", ["buyer_id", "last_message_at"])
    op.create_index("ix_chat_conversations_seller_last", "chat_conversations", ["seller_id", "last_message_at"])

    op.create_table(
        "chat_participants",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("conversation_id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(36), nullable=False),
        sa.Column("last_read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("muted", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("archived", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["conversation_id"], ["chat_conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("conversation_id", "user_id", name="uq_chat_participant"),
    )
    op.create_index("ix_chat_participants_conversation_id", "chat_participants", ["conversation_id"])
    op.create_index("ix_chat_participants_user_id", "chat_participants", ["user_id"])
    op.create_index("ix_chat_participants_archived", "chat_participants", ["archived"])

    op.create_table(
        "chat_messages",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("conversation_id", sa.String(36), nullable=False),
        sa.Column("sender_id", sa.String(36), nullable=False),
        sa.Column("client_message_id", sa.String(64), nullable=False),
        sa.Column("kind", sa.String(20), server_default="text", nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("edited_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["conversation_id"], ["chat_conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["sender_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("sender_id", "client_message_id", name="uq_chat_sender_client_message"),
    )
    op.create_index("ix_chat_messages_conversation_id", "chat_messages", ["conversation_id"])
    op.create_index("ix_chat_messages_sender_id", "chat_messages", ["sender_id"])
    op.create_index("ix_chat_messages_conversation_created", "chat_messages", ["conversation_id", "created_at", "id"])

    op.create_table(
        "chat_message_reports",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("message_id", sa.String(36), nullable=False),
        sa.Column("reporter_id", sa.String(36), nullable=False),
        sa.Column("reason", sa.String(40), nullable=False),
        sa.Column("details", sa.String(500), nullable=True),
        sa.Column("status", sa.String(20), server_default="open", nullable=False),
        sa.Column("resolved_by", sa.String(36), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["message_id"], ["chat_messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["resolved_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("message_id", "reporter_id", name="uq_chat_message_reporter"),
    )
    op.create_index("ix_chat_message_reports_message_id", "chat_message_reports", ["message_id"])
    op.create_index("ix_chat_message_reports_reporter_id", "chat_message_reports", ["reporter_id"])
    op.create_index("ix_chat_message_reports_status", "chat_message_reports", ["status"])

    op.create_table(
        "marketplace_reviews",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("conversation_id", sa.String(36), nullable=False),
        sa.Column("reviewer_id", sa.String(36), nullable=False),
        sa.Column("reviewed_user_id", sa.String(36), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("comment", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("rating >= 1 AND rating <= 5", name="ck_marketplace_review_rating"),
        sa.ForeignKeyConstraint(["conversation_id"], ["chat_conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewer_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewed_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("conversation_id", "reviewer_id", name="uq_marketplace_review_conversation_reviewer"),
    )
    op.create_index("ix_marketplace_reviews_conversation_id", "marketplace_reviews", ["conversation_id"])
    op.create_index("ix_marketplace_reviews_reviewer_id", "marketplace_reviews", ["reviewer_id"])
    op.create_index("ix_marketplace_reviews_reviewed_user_id", "marketplace_reviews", ["reviewed_user_id"])

    op.create_table(
        "push_devices",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(36), nullable=False),
        sa.Column("token", sa.String(200), nullable=False),
        sa.Column("platform", sa.String(20), server_default="ios", nullable=False),
        sa.Column("environment", sa.String(20), server_default="production", nullable=False),
        sa.Column("enabled", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token", name="uq_push_device_token"),
    )
    op.create_index("ix_push_devices_user_id", "push_devices", ["user_id"])

    op.create_table(
        "notification_outbox",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("event_key", sa.String(120), nullable=False),
        sa.Column("recipient_id", sa.String(36), nullable=False),
        sa.Column("event_type", sa.String(40), nullable=False),
        sa.Column("payload_json", sa.Text(), nullable=False),
        sa.Column("status", sa.String(20), server_default="pending", nullable=False),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_error", sa.String(500), nullable=True),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["recipient_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("event_key"),
    )
    op.create_index("ix_notification_outbox_recipient_id", "notification_outbox", ["recipient_id"])
    op.create_index("ix_notification_outbox_status", "notification_outbox", ["status"])
    op.create_index("ix_notification_outbox_due", "notification_outbox", ["status", "next_attempt_at"])


def downgrade() -> None:
    op.drop_table("notification_outbox")
    op.drop_table("push_devices")
    op.drop_table("marketplace_reviews")
    op.drop_table("chat_message_reports")
    op.drop_table("chat_messages")
    op.drop_table("chat_participants")
    op.drop_table("chat_conversations")
