"""add user profile, ticket and conversation fields

Revision ID: e8b2c14a9f31
Revises: d7a1c93e5b20
Create Date: 2026-09-10 18:40:00.000000

Adds missing fields to match SQLAlchemy models:
- users: phone, location, organization
- conversations: ticket_id
- messages: sender_name
- tickets: conversation_id
- ticket_messages: sources, and allows nullable sender_id for system/AI messages
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e8b2c14a9f31'
down_revision: Union[str, Sequence[str], None] = 'd7a1c93e5b20'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. User profile fields
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('phone', sa.String(length=50), nullable=True))
        batch_op.add_column(sa.Column('location', sa.String(length=150), nullable=True))
        batch_op.add_column(sa.Column('organization', sa.String(length=150), nullable=True))

    # 2. Conversation ticket linkage
    with op.batch_alter_table('conversations', schema=None) as batch_op:
        batch_op.add_column(sa.Column('ticket_id', sa.Integer(), nullable=True))
        batch_op.create_index(batch_op.f('ix_conversations_ticket_id'), ['ticket_id'], unique=False)

    # 3. Message sender name
    with op.batch_alter_table('messages', schema=None) as batch_op:
        batch_op.add_column(sa.Column('sender_name', sa.String(length=100), nullable=True))

    # 4. Tickets conversation linkage
    with op.batch_alter_table('tickets', schema=None) as batch_op:
        batch_op.add_column(sa.Column('conversation_id', sa.Integer(), nullable=True))
        batch_op.create_index(batch_op.f('ix_tickets_conversation_id'), ['conversation_id'], unique=False)

    # 5. Ticket messages RAG sources & nullable sender
    with op.batch_alter_table('ticket_messages', schema=None) as batch_op:
        batch_op.add_column(sa.Column('sources', sa.JSON(), nullable=True))
        batch_op.alter_column('sender_id', existing_type=sa.Integer(), nullable=True)


def downgrade() -> None:
    with op.batch_alter_table('ticket_messages', schema=None) as batch_op:
        batch_op.alter_column('sender_id', existing_type=sa.Integer(), nullable=False)
        batch_op.drop_column('sources')

    with op.batch_alter_table('tickets', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_tickets_conversation_id'))
        batch_op.drop_column('conversation_id')

    with op.batch_alter_table('messages', schema=None) as batch_op:
        batch_op.drop_column('sender_name')

    with op.batch_alter_table('conversations', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_conversations_ticket_id'))
        batch_op.drop_column('ticket_id')

    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('organization')
        batch_op.drop_column('location')
        batch_op.drop_column('phone')
