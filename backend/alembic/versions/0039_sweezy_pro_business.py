"""Sweezy Pro business CRM, booking and AI receptionist

Revision ID: 0039_sweezy_pro_business
Revises: 0038_reports_and_safety
"""

import sqlalchemy as sa
from alembic import op


revision = "0039_sweezy_pro_business"
down_revision = "0038_reports_and_safety"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "business_profiles",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("display_name", sa.String(120), nullable=False),
        sa.Column("legal_name", sa.String(180)),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("category", sa.String(40), nullable=False, server_default="other"),
        sa.Column("canton", sa.String(10), nullable=False),
        sa.Column("city", sa.String(100), nullable=False),
        sa.Column("address", sa.String(240)),
        sa.Column("service_area", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("languages", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("logo_url", sa.String(1000)),
        sa.Column("cover_url", sa.String(1000)),
        sa.Column("phone", sa.String(40)),
        sa.Column("email", sa.String(255)),
        sa.Column("website", sa.String(500)),
        sa.Column("uid_number", sa.String(40)),
        sa.Column("delivery_modes", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("cancellation_policy", sa.Text()),
        sa.Column("payment_link", sa.String(1000)),
        sa.Column("timezone", sa.String(50), nullable=False, server_default="Europe/Zurich"),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("rejection_reason", sa.Text()),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("submitted_at", sa.DateTime(timezone=True)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("reviewed_by", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("ai_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("ai_auto_reply", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("ai_tone", sa.String(30), nullable=False, server_default="friendly_professional"),
        sa.Column("ai_business_facts", sa.Text(), nullable=False, server_default=""),
        sa.Column("ai_instructions", sa.Text(), nullable=False, server_default=""),
        sa.Column("ai_greeting", sa.String(500)),
        sa.Column("ai_faq", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("ai_handoff_topics", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("ai_allowed_languages", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_business_profiles_category", "business_profiles", ["category"])
    op.create_index("ix_business_profiles_canton", "business_profiles", ["canton"])
    op.create_index("ix_business_profiles_uid_number", "business_profiles", ["uid_number"])
    op.create_index("ix_business_profiles_status", "business_profiles", ["status"])
    op.create_index("ix_business_profiles_is_verified", "business_profiles", ["is_verified"])

    op.create_table(
        "business_services",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("listing_id", sa.String(36), sa.ForeignKey("service_listings.id", ondelete="SET NULL"), unique=True),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("category", sa.String(40), nullable=False, server_default="other"),
        sa.Column("duration_minutes", sa.Integer(), nullable=False, server_default="60"),
        sa.Column("price_cents", sa.Integer()),
        sa.Column("price_to_cents", sa.Integer()),
        sa.Column("currency", sa.String(3), nullable=False, server_default="CHF"),
        sa.Column("delivery_mode", sa.String(20), nullable=False, server_default="onsite"),
        sa.Column("buffer_minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_business_services_business_user_id", "business_services", ["business_user_id"])
    op.create_index("ix_business_services_owner_active", "business_services", ["business_user_id", "is_active"])

    op.create_table(
        "business_availability_rules",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("weekday", sa.Integer(), nullable=False),
        sa.Column("start_time", sa.String(5), nullable=False),
        sa.Column("end_time", sa.String(5), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("business_user_id", "weekday", "start_time", "end_time", name="uq_business_availability_window"),
    )
    op.create_index("ix_business_availability_rules_business_user_id", "business_availability_rules", ["business_user_id"])
    op.create_index("ix_business_availability_owner_day", "business_availability_rules", ["business_user_id", "weekday"])

    op.create_table(
        "business_leads",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("chat_conversations.id", ondelete="SET NULL")),
        sa.Column("customer_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("service_id", sa.String(36), sa.ForeignKey("business_services.id", ondelete="SET NULL")),
        sa.Column("customer_name", sa.String(120), nullable=False),
        sa.Column("customer_language", sa.String(10)),
        sa.Column("contact_value", sa.String(255)),
        sa.Column("status", sa.String(30), nullable=False, server_default="new"),
        sa.Column("source", sa.String(30), nullable=False, server_default="marketplace"),
        sa.Column("budget_cents", sa.Integer()),
        sa.Column("desired_at", sa.DateTime(timezone=True)),
        sa.Column("notes", sa.Text(), nullable=False, server_default=""),
        sa.Column("next_action", sa.String(240)),
        sa.Column("next_action_at", sa.DateTime(timezone=True)),
        sa.Column("assignee_name", sa.String(120)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("business_user_id", "conversation_id", name="uq_business_lead_conversation"),
    )
    op.create_index("ix_business_leads_business_user_id", "business_leads", ["business_user_id"])
    op.create_index("ix_business_leads_customer_user_id", "business_leads", ["customer_user_id"])
    op.create_index("ix_business_leads_status", "business_leads", ["status"])
    op.create_index("ix_business_leads_pipeline", "business_leads", ["business_user_id", "status", "updated_at"])

    op.create_table(
        "business_clients",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("customer_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("display_name", sa.String(120), nullable=False),
        sa.Column("email", sa.String(255)),
        sa.Column("phone", sa.String(40)),
        sa.Column("language", sa.String(10)),
        sa.Column("notes", sa.Text(), nullable=False, server_default=""),
        sa.Column("tags", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("booking_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("completed_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_spend_cents", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_activity_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("business_user_id", "customer_user_id", name="uq_business_client_user"),
    )
    op.create_index("ix_business_clients_business_user_id", "business_clients", ["business_user_id"])
    op.create_index("ix_business_clients_owner_activity", "business_clients", ["business_user_id", "last_activity_at"])

    op.create_table(
        "business_bookings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("client_id", sa.String(36), sa.ForeignKey("business_clients.id", ondelete="SET NULL")),
        sa.Column("lead_id", sa.String(36), sa.ForeignKey("business_leads.id", ondelete="SET NULL")),
        sa.Column("service_id", sa.String(36), sa.ForeignKey("business_services.id", ondelete="SET NULL")),
        sa.Column("customer_name", sa.String(120), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="requested"),
        sa.Column("location", sa.String(240)),
        sa.Column("notes", sa.Text(), nullable=False, server_default=""),
        sa.Column("price_cents", sa.Integer()),
        sa.Column("currency", sa.String(3), nullable=False, server_default="CHF"),
        sa.Column("reminder_minutes", sa.Integer(), nullable=False, server_default="1440"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_business_bookings_business_user_id", "business_bookings", ["business_user_id"])
    op.create_index("ix_business_bookings_status", "business_bookings", ["status"])
    op.create_index("ix_business_bookings_calendar", "business_bookings", ["business_user_id", "starts_at", "status"])

    op.create_table(
        "business_quick_replies",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(80), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("language", sa.String(10), nullable=False, server_default="de"),
        sa.Column("category", sa.String(30), nullable=False, server_default="general"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_business_quick_replies_business_user_id", "business_quick_replies", ["business_user_id"])
    op.create_index("ix_business_quick_replies_owner_order", "business_quick_replies", ["business_user_id", "sort_order"])

    op.create_table(
        "business_team_members",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("member_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("display_name", sa.String(120), nullable=False),
        sa.Column("role", sa.String(20), nullable=False, server_default="staff"),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("business_user_id", "email", name="uq_business_team_email"),
    )
    op.create_index("ix_business_team_members_business_user_id", "business_team_members", ["business_user_id"])
    op.create_index("ix_business_team_members_member_user_id", "business_team_members", ["member_user_id"])

    op.create_table(
        "business_documents",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_user_id", sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("client_id", sa.String(36), sa.ForeignKey("business_clients.id", ondelete="SET NULL")),
        sa.Column("lead_id", sa.String(36), sa.ForeignKey("business_leads.id", ondelete="SET NULL")),
        sa.Column("document_type", sa.String(20), nullable=False, server_default="quote"),
        sa.Column("number", sa.String(40), nullable=False),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("line_items", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("notes", sa.Text(), nullable=False, server_default=""),
        sa.Column("total_cents", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(3), nullable=False, server_default="CHF"),
        sa.Column("due_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_business_documents_business_user_id", "business_documents", ["business_user_id"])
    op.create_index("ix_business_documents_owner_created", "business_documents", ["business_user_id", "created_at"])


def downgrade() -> None:
    for table in (
        "business_documents",
        "business_team_members",
        "business_quick_replies",
        "business_bookings",
        "business_clients",
        "business_leads",
        "business_availability_rules",
        "business_services",
        "business_profiles",
    ):
        op.drop_table(table)
