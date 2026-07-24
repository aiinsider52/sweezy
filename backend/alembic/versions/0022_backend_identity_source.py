"""use backend user ids for authored content

Revision ID: 0022_backend_identity
Revises: 0021_marketplace_goods
Create Date: 2026-07-13
"""

from alembic import op


revision = "0022_backend_identity"
down_revision = "0021_marketplace_goods"
branch_labels = None
depends_on = None


def _migrate_author_ids(table_name: str) -> None:
    op.execute(
        f"""
        UPDATE {table_name}
        SET author_id = (
            SELECT users.id
            FROM users
            WHERE lower(users.email) = lower({table_name}.author_id)
            LIMIT 1
        )
        WHERE author_id IS NOT NULL
          AND EXISTS (
              SELECT 1
              FROM users
              WHERE lower(users.email) = lower({table_name}.author_id)
          )
        """
    )


def upgrade() -> None:
    _migrate_author_ids("service_listings")
    _migrate_author_ids("event_listings")


def downgrade() -> None:
    pass
