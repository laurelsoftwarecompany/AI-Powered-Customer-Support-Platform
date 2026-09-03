"""add message.sources (RAG citations)

Revision ID: c4f2a9e17d83
Revises: fb6c8d98c5f1
Create Date: 2026-09-03 10:15:00.000000

Stores the knowledge-base articles the AI grounded an answer in, as a JSON
list of {document_id, title, score, snippet}. Null for customer/agent
messages and for AI answers where retrieval returned nothing useful.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'c4f2a9e17d83'
down_revision: Union[str, Sequence[str], None] = 'fb6c8d98c5f1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('messages', sa.Column('sources', sa.JSON(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('messages', 'sources')
