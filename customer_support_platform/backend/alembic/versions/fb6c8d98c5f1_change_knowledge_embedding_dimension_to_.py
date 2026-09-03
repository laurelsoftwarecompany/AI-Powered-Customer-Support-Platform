"""change knowledge embedding dimension to 384

Revision ID: fb6c8d98c5f1
Revises: b0459148151f
Create Date: 2026-09-02 20:51:36.096070

Note: embeddings are now stored as a portable JSON array (see
app/database/models/knowledge_chunk.py), so there is no fixed vector
dimension at the database level. This revision is kept as a no-op to
preserve a linear migration history.
"""
from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = 'fb6c8d98c5f1'
down_revision: Union[str, Sequence[str], None] = 'b0459148151f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """No-op: embedding column is JSON, dimension is not enforced by the DB."""
    pass


def downgrade() -> None:
    """No-op."""
    pass
