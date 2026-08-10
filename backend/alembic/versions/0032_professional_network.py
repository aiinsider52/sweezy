"""professional network profiles, connections, and chat context

Revision ID: 0032_professional_network
Revises: 0031_apple_subscriptions
"""

import sqlalchemy as sa
from alembic import op


revision = "0032_professional_network"
down_revision = "0031_apple_subscriptions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "professional_profiles",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("display_name", sa.String(100), nullable=False),
        sa.Column("headline", sa.String(140), nullable=False),
        sa.Column("company_name", sa.String(120), nullable=True),
        sa.Column("role", sa.String(30), nullable=False),
        sa.Column("industry", sa.String(60), nullable=False),
        sa.Column("canton", sa.String(10), nullable=False),
        sa.Column("city", sa.String(80), nullable=False),
        sa.Column("bio", sa.String(800), nullable=False),
        sa.Column("skills", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column("languages", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column("goals", sa.JSON(), server_default=sa.text("'[]'"), nullable=False),
        sa.Column("avatar_url", sa.String(1000), nullable=True),
        sa.Column("website_url", sa.String(1000), nullable=True),
        sa.Column("is_visible", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("is_verified", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("is_featured", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("open_to_connections", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    for column in ("role", "industry", "canton", "is_visible", "is_verified", "is_featured", "open_to_connections"):
        op.create_index(f"ix_professional_profiles_{column}", "professional_profiles", [column])

    op.add_column(
        "chat_conversations",
        sa.Column(
            "network_profile_id",
            sa.String(36),
            sa.ForeignKey("professional_profiles.user_id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_chat_conversations_network_profile_id", "chat_conversations", ["network_profile_id"])
    op.create_unique_constraint(
        "uq_chat_network_participants",
        "chat_conversations",
        ["network_profile_id", "buyer_id", "seller_id"],
    )

    op.create_table(
        "professional_connections",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("pair_key", sa.String(73), nullable=False),
        sa.Column("requester_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("message", sa.String(500), nullable=True),
        sa.Column("status", sa.String(20), server_default="pending", nullable=False),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("chat_conversations.id", ondelete="SET NULL"), nullable=True),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("pair_key", name="uq_professional_connection_pair"),
        sa.UniqueConstraint("requester_id", "target_id", name="uq_professional_connection_direction"),
    )
    op.create_index("ix_professional_connections_status", "professional_connections", ["status"])
    op.create_index("ix_professional_connections_conversation_id", "professional_connections", ["conversation_id"])
    op.create_index("ix_professional_connections_target_status", "professional_connections", ["target_id", "status", "created_at"])
    op.create_index("ix_professional_connections_requester_status", "professional_connections", ["requester_id", "status", "created_at"])

    op.create_table(
        "professional_profile_reports",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("profile_user_id", sa.String(36), sa.ForeignKey("professional_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("reporter_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reason", sa.String(40), nullable=False),
        sa.Column("details", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), server_default="open", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("profile_user_id", "reporter_id", name="uq_professional_profile_reporter"),
    )
    op.create_index("ix_professional_profile_reports_profile_user_id", "professional_profile_reports", ["profile_user_id"])
    op.create_index("ix_professional_profile_reports_reporter_id", "professional_profile_reports", ["reporter_id"])
    op.create_index("ix_professional_profile_reports_status", "professional_profile_reports", ["status"])


def downgrade() -> None:
    op.drop_table("professional_profile_reports")
    op.drop_table("professional_connections")
    op.drop_constraint("uq_chat_network_participants", "chat_conversations", type_="unique")
    op.drop_index("ix_chat_conversations_network_profile_id", table_name="chat_conversations")
    op.drop_column("chat_conversations", "network_profile_id")
    op.drop_table("professional_profiles")
