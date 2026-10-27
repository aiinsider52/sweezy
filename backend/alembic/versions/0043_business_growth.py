"""Business accounts: kinds, plans, boosts, reviews, offers, stats and clubs

Revision ID: 0043_business_growth
Revises: 0042_place_suggestions
"""

import sqlalchemy as sa
from alembic import op

revision = "0043_business_growth"
down_revision = "0042_place_suggestions"
branch_labels = None
depends_on = None


PROFILE_COLUMNS = (
    sa.Column("kind", sa.String(20), nullable=False, server_default="business"),
    sa.Column("tagline", sa.String(140), nullable=True),
    sa.Column("latitude", sa.Float(), nullable=True),
    sa.Column("longitude", sa.Float(), nullable=True),
    sa.Column("photo_urls", sa.JSON(), nullable=False, server_default="[]"),
    sa.Column("social_links", sa.JSON(), nullable=False, server_default="{}"),
    sa.Column("opening_hours_note", sa.String(240), nullable=True),
    sa.Column("represented_by", sa.String(120), nullable=True),
    sa.Column("plan", sa.String(20), nullable=False, server_default="free"),
    sa.Column("plan_expires_at", sa.DateTime(timezone=True), nullable=True),
    sa.Column("plan_source", sa.String(20), nullable=True),
    sa.Column("plan_original_transaction_id", sa.String(160), nullable=True),
    sa.Column("boost_until", sa.DateTime(timezone=True), nullable=True),
    sa.Column("average_rating", sa.Float(), nullable=True),
    sa.Column("review_count", sa.Integer(), nullable=False, server_default="0"),
)


def _business_fk(name: str = "business_user_id") -> sa.Column:
    return sa.Column(name, sa.String(36), sa.ForeignKey("business_profiles.user_id", ondelete="CASCADE"), nullable=False)


def upgrade() -> None:
    for column in PROFILE_COLUMNS:
        op.add_column("business_profiles", column)
    op.create_index("ix_business_profiles_kind", "business_profiles", ["kind"])
    op.create_index("ix_business_profiles_plan", "business_profiles", ["plan"])
    op.create_index("ix_business_profiles_boost_until", "business_profiles", ["boost_until"])
    op.create_index(
        "ix_business_profiles_plan_original_transaction_id",
        "business_profiles",
        ["plan_original_transaction_id"],
    )

    op.create_table(
        "business_reviews",
        sa.Column("id", sa.String(36), primary_key=True),
        _business_fk(),
        sa.Column("author_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("booking_id", sa.String(36), sa.ForeignKey("business_bookings.id", ondelete="SET NULL"), nullable=True),
        sa.Column("author_name", sa.String(120), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False, server_default=""),
        sa.Column("owner_reply", sa.Text(), nullable=True),
        sa.Column("owner_replied_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="published"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("business_user_id", "author_id", name="uq_business_review_author"),
        sa.CheckConstraint("rating BETWEEN 1 AND 5", name="ck_business_review_rating"),
    )
    op.create_index("ix_business_reviews_business_user_id", "business_reviews", ["business_user_id"])
    op.create_index("ix_business_reviews_author_id", "business_reviews", ["author_id"])
    op.create_index("ix_business_reviews_status", "business_reviews", ["status"])
    op.create_index("ix_business_reviews_public", "business_reviews", ["business_user_id", "status", "created_at"])

    op.create_table(
        "business_offers",
        sa.Column("id", sa.String(36), primary_key=True),
        _business_fk(),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("discount_label", sa.String(40), nullable=False),
        sa.Column("promo_code", sa.String(40), nullable=True),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_business_offers_business_user_id", "business_offers", ["business_user_id"])
    op.create_index("ix_business_offers_ends_at", "business_offers", ["ends_at"])
    op.create_index("ix_business_offers_owner_active", "business_offers", ["business_user_id", "is_active"])

    op.create_table(
        "business_stats_daily",
        sa.Column("id", sa.String(36), primary_key=True),
        _business_fk(),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("metric", sa.String(30), nullable=False),
        sa.Column("count", sa.Integer(), nullable=False, server_default="0"),
        sa.UniqueConstraint("business_user_id", "day", "metric", name="uq_business_stat_day_metric"),
    )
    op.create_index("ix_business_stats_daily_business_user_id", "business_stats_daily", ["business_user_id"])

    op.create_table(
        "business_purchases",
        sa.Column("id", sa.String(36), primary_key=True),
        _business_fk(),
        sa.Column("provider", sa.String(20), nullable=False, server_default="apple"),
        sa.Column("product_id", sa.String(160), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("transaction_id", sa.String(160), nullable=False, unique=True),
        sa.Column("original_transaction_id", sa.String(160), nullable=True),
        sa.Column("environment", sa.String(24), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_business_purchases_business_user_id", "business_purchases", ["business_user_id"])
    op.create_index("ix_business_purchases_original_transaction_id", "business_purchases", ["original_transaction_id"])

    op.create_table(
        "business_club_members",
        sa.Column("id", sa.String(36), primary_key=True),
        _business_fk("club_user_id"),
        _business_fk("member_user_id"),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("club_user_id", "member_user_id", name="uq_business_club_member"),
    )
    op.create_index("ix_business_club_members_club_user_id", "business_club_members", ["club_user_id"])
    op.create_index("ix_business_club_members_member_user_id", "business_club_members", ["member_user_id"])
    op.create_index("ix_business_club_members_status", "business_club_members", ["status"])


def downgrade() -> None:
    op.drop_table("business_club_members")
    op.drop_table("business_purchases")
    op.drop_table("business_stats_daily")
    op.drop_table("business_offers")
    op.drop_table("business_reviews")
    op.drop_index("ix_business_profiles_plan_original_transaction_id", table_name="business_profiles")
    op.drop_index("ix_business_profiles_boost_until", table_name="business_profiles")
    op.drop_index("ix_business_profiles_plan", table_name="business_profiles")
    op.drop_index("ix_business_profiles_kind", table_name="business_profiles")
    for column in reversed(PROFILE_COLUMNS):
        op.drop_column("business_profiles", column.name)
