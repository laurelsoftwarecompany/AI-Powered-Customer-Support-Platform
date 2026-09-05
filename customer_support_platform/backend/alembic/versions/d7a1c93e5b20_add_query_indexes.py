"""query indexes + fix knowledge_chunks.embedding nullability

Revision ID: d7a1c93e5b20
Revises: c4f2a9e17d83
Create Date: 2026-09-05 12:05:00.000000

Two things.

1. Every list endpoint filters then orders on the same pairs of columns and
   none of them were indexed:
     * tickets          - "my tickets, newest first" / "queue by status, newest first"
     * messages         - "this conversation, oldest first"
     * ticket_messages  - "this ticket, oldest first"
     * conversations    - "my conversations / all conversations, newest first"
     * knowledge_documents.status - filtered on every retrieval

2. `knowledge_chunks.embedding` was created NOT NULL by revision b0459148151f,
   but the model declares it nullable and ingestion depends on that: documents
   are chunked first and embedded afterwards by `knowledge_service.reindex()`.
   The SQLite dev database is built by `create_all` (model wins) so this never
   surfaced, but any alembic-migrated database - i.e. the PostgreSQL one in
   docker-compose - would fail on the first document with
   "NOT NULL constraint failed: knowledge_chunks.embedding".
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'd7a1c93e5b20'
down_revision: Union[str, Sequence[str], None] = 'c4f2a9e17d83'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Chunks are inserted before they are embedded - the column must allow NULL.
    # batch_alter_table keeps this working on SQLite, which cannot ALTER COLUMN.
    with op.batch_alter_table('knowledge_chunks') as batch_op:
        batch_op.alter_column(
            'embedding', existing_type=sa.JSON(), nullable=True
        )

    op.create_index(
        'ix_tickets_customer_updated', 'tickets', ['customer_id', 'updated_at']
    )
    op.create_index(
        'ix_tickets_status_updated', 'tickets', ['status', 'updated_at']
    )
    op.create_index(
        'ix_messages_conversation_created',
        'messages',
        ['conversation_id', 'created_at'],
    )
    op.create_index(
        'ix_ticket_messages_ticket_created',
        'ticket_messages',
        ['ticket_id', 'created_at'],
    )
    op.create_index(
        'ix_conversations_customer_updated',
        'conversations',
        ['customer_id', 'updated_at'],
    )
    op.create_index('ix_conversations_updated', 'conversations', ['updated_at'])
    op.create_index(
        'ix_knowledge_documents_status', 'knowledge_documents', ['status']
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_knowledge_documents_status', table_name='knowledge_documents')
    op.drop_index('ix_conversations_updated', table_name='conversations')
    op.drop_index('ix_conversations_customer_updated', table_name='conversations')
    op.drop_index('ix_ticket_messages_ticket_created', table_name='ticket_messages')
    op.drop_index('ix_messages_conversation_created', table_name='messages')
    op.drop_index('ix_tickets_status_updated', table_name='tickets')
    op.drop_index('ix_tickets_customer_updated', table_name='tickets')
    with op.batch_alter_table('knowledge_chunks') as batch_op:
        batch_op.alter_column(
            'embedding', existing_type=sa.JSON(), nullable=False
        )
