"""
Production cleanup script:
- Purges all tickets, ticket messages, conversations, and chat messages.
- Removes all dummy admins, agents, and demo customer accounts.
- Sets up Admin: hammadmehmood464@gmail.com / Hammad@1234
- Sets up Agent: maoun.778899@gmail.com / Aoun@1234
- Preserves knowledge base documents and embeddings for production RAG.
"""

import sys
from pathlib import Path

# Ensure backend root is on sys.path
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from pwdlib import PasswordHash
from app.database.connection import SessionLocal
from app.database.models import (
    User,
    UserRole,
    Ticket,
    TicketMessage,
    Conversation,
    Message,
    KnowledgeDocument,
    KnowledgeChunk,
)

password_hash = PasswordHash.recommended()


def clean_database() -> None:
    db = SessionLocal()
    try:
        # 1. Purge all tickets, messages, and conversations
        deleted_ticket_messages = db.query(TicketMessage).delete(synchronize_session=False)
        deleted_tickets = db.query(Ticket).delete(synchronize_session=False)
        deleted_chat_messages = db.query(Message).delete(synchronize_session=False)
        deleted_conversations = db.query(Conversation).delete(synchronize_session=False)
        db.flush()

        # 2. Configure Admin: hammadmehmood464@gmail.com
        admin_email = "hammadmehmood464@gmail.com"
        admin = db.query(User).filter(User.email == admin_email).first()
        if admin:
            admin.name = "Hammad Mehmood"
            admin.password_hash = password_hash.hash("Hammad@1234")
            admin.role = UserRole.ADMIN
            admin.is_active = True
        else:
            admin = User(
                name="Hammad Mehmood",
                email=admin_email,
                password_hash=password_hash.hash("Hammad@1234"),
                role=UserRole.ADMIN,
                is_active=True,
            )
            db.add(admin)

        # 3. Configure Agent: maoun.778899@gmail.com
        agent_email = "maoun.778899@gmail.com"
        agent = db.query(User).filter(User.email == agent_email).first()
        if agent:
            agent.name = "Aoun Muhammad"
            agent.password_hash = password_hash.hash("Aoun@1234")
            agent.role = UserRole.AGENT
            agent.is_active = True
        else:
            agent = User(
                name="Aoun Muhammad",
                email=agent_email,
                password_hash=password_hash.hash("Aoun@1234"),
                role=UserRole.AGENT,
                is_active=True,
            )
            db.add(agent)

        db.flush()

        # 4. Remove all other dummy users (admins, agents, demo customers)
        kept_emails = {admin_email, agent_email}
        deleted_users = (
            db.query(User)
            .filter(~User.email.in_(kept_emails))
            .delete(synchronize_session=False)
        )

        db.commit()

        # 5. Summary verification
        remaining_users = db.query(User).all()
        kb_docs = db.query(KnowledgeDocument).count()
        kb_chunks = db.query(KnowledgeChunk).count()

        print("============================================================")
        print("  PRODUCTION CLEANUP COMPLETED SUCCESSFULLY")
        print("============================================================")
        print(f"Purged Tickets:          {deleted_tickets}")
        print(f"Purged Ticket Messages:  {deleted_ticket_messages}")
        print(f"Purged Conversations:    {deleted_conversations}")
        print(f"Purged Chat Messages:    {deleted_chat_messages}")
        print(f"Purged Dummy Accounts:   {deleted_users}")
        print(f"Knowledge Base Intact:   {kb_docs} documents ({kb_chunks} chunks)")
        print("\nProduction Accounts Active:")
        for u in remaining_users:
            print(f"  • [{u.role.value}] {u.name} <{u.email}> (Active: {u.is_active})")
        print("============================================================")

    except Exception as e:
        db.rollback()
        print(f"Error during cleanup: {e}", file=sys.stderr)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    clean_database()
