"""Keep the employer's note on an application apart from the candidate's private notes

Revision ID: 0045_employer_notes
Revises: 0044_engagement_notifications
"""

import sqlalchemy as sa
from alembic import op

revision = "0045_employer_notes"
down_revision = "0044_engagement_notifications"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("job_applications", sa.Column("employer_notes", sa.String(2000), nullable=True))


def downgrade() -> None:
    op.drop_column("job_applications", "employer_notes")
