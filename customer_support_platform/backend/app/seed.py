"""
Seed the database with demo data.

    python -m app.seed          # seed only if the DB looks empty
    python -m app.seed --fresh  # wipe all rows first, then seed

Demo accounts (all passwords shown):
    admin@laurel.test / admin1234    (admin)
    agent@laurel.test / agent1234    (agent)
    nadia@laurel.test / agent1234    (agent)
    sarah@example.com / customer1234 (customer)
    james@example.com / customer1234 (customer)
    maria@example.com / customer1234 (customer)
"""

import sys
from datetime import datetime, timedelta

from pwdlib import PasswordHash

from app.config import settings
from app.database.base import Base
from app.database.connection import SessionLocal, engine
from app.database.models import (
    Conversation,
    Message,
    Ticket,
    TicketMessage,
    TicketPriority,
    TicketStatus,
    User,
    UserRole,
)

password_hash = PasswordHash.recommended()

NOW = datetime.utcnow()


def _hash(pw: str) -> str:
    return password_hash.hash(pw)


def wipe(db) -> None:
    from app.database.models import KnowledgeChunk, KnowledgeDocument

    for model in (
        TicketMessage,
        Ticket,
        Message,
        Conversation,
        KnowledgeChunk,
        KnowledgeDocument,
        User,
    ):
        db.query(model).delete()
    db.commit()


KB_DOCS = [
    (
        "Password reset and account recovery",
        "account_recovery.md",
        "md",
        "# Password reset\n\n"
        "To reset your password, open Settings -> Security -> Reset Password. "
        "You will receive an email with a reset link that is valid for 30 minutes. "
        "If you do not receive the email within a few minutes, check your spam folder "
        "or request a new link.\n\n"
        "If you are locked out and cannot access the email on file, contact support "
        "and a human agent will verify your identity and update your address.",
    ),
    (
        "Refund policy",
        "refund_policy.md",
        "md",
        "# Refunds\n\n"
        "Refunds are issued to the original payment method within 5 to 7 business days "
        "after a return is approved. Digital goods are refundable within 14 days of "
        "purchase if they have not been downloaded. Shipping fees are non-refundable "
        "unless the return is due to our error.",
    ),
    (
        "Order tracking and delivery",
        "shipping.md",
        "md",
        "# Tracking your order\n\n"
        "Tracking information appears in your account under Orders within 24 hours of "
        "shipment. Carriers usually scan a package within 48 hours of the label being "
        "created. If tracking has not updated in 5 business days, open a support ticket "
        "and we will open an investigation with the carrier.",
    ),
    (
        "Payment issues at checkout",
        "payments_faq.faq",
        "faq",
        "Q: Why is my card being declined at checkout?\n"
        "A: The most common causes are an expired card, an incorrect billing ZIP code, "
        "or the bank blocking an unfamiliar charge. Confirm the card details, try again, "
        "and if it still fails contact your bank. You can also add a different payment "
        "method under Settings -> Billing.",
    ),
]


def seed_knowledge(db) -> None:
    from app.services import knowledge_service

    for title, filename, ftype, content in KB_DOCS:
        knowledge_service.create_document(
            db,
            title=title,
            filename=filename,
            file_type=ftype,
            content=content,
        )


def seed(db) -> None:
    # ---- users -------------------------------------------------
    admin = User(name="Amir Rahman", email="admin@laurel.test",
                 password_hash=_hash("admin1234"), role=UserRole.ADMIN)
    agent = User(name="Omar Farid", email="agent@laurel.test",
                 password_hash=_hash("agent1234"), role=UserRole.AGENT)
    agent2 = User(name="Nadia Hassan", email="nadia@laurel.test",
                  password_hash=_hash("agent1234"), role=UserRole.AGENT)
    sarah = User(name="Sarah Chen", email="sarah@example.com",
                 password_hash=_hash("customer1234"), role=UserRole.CUSTOMER)
    james = User(name="James Miller", email="james@example.com",
                 password_hash=_hash("customer1234"), role=UserRole.CUSTOMER)
    maria = User(name="Maria Lopez", email="maria@example.com",
                 password_hash=_hash("customer1234"), role=UserRole.CUSTOMER,
                 is_active=False)

    db.add_all([admin, agent, agent2, sarah, james, maria])
    db.flush()

    # ---- tickets ----------------------------------------------
    tickets = [
        Ticket(customer_id=sarah.id, assigned_agent_id=agent.id,
               subject="Unable to access my account after password reset",
               description="I reset my password but the login page keeps reloading and never lets me in.",
               category="account_issue", priority=TicketPriority.HIGH,
               status=TicketStatus.IN_PROGRESS,
               created_at=NOW - timedelta(days=3), updated_at=NOW - timedelta(hours=5)),
        Ticket(customer_id=james.id, assigned_agent_id=agent.id,
               subject="Refund not received for cancelled order #4471",
               description="I cancelled order 4471 eight days ago and still have not seen the refund.",
               category="refund_request", priority=TicketPriority.URGENT,
               status=TicketStatus.OPEN,
               created_at=NOW - timedelta(days=1), updated_at=NOW - timedelta(hours=2)),
        Ticket(customer_id=maria.id, assigned_agent_id=None,
               subject="Payment fails at checkout with card ending 4242",
               description="Every time I try to pay, I get 'payment could not be processed'.",
               category="payment_issue", priority=TicketPriority.MEDIUM,
               status=TicketStatus.OPEN,
               created_at=NOW - timedelta(hours=20), updated_at=NOW - timedelta(hours=20)),
        Ticket(customer_id=sarah.id, assigned_agent_id=agent2.id,
               subject="How do I change the email on my account?",
               description="I want to move my account to a new work email address.",
               category="account_issue", priority=TicketPriority.LOW,
               status=TicketStatus.WAITING_FOR_CUSTOMER,
               created_at=NOW - timedelta(days=6), updated_at=NOW - timedelta(days=2)),
        Ticket(customer_id=james.id, assigned_agent_id=agent2.id,
               subject="App crashes when opening order history",
               description="The mobile app closes instantly when I tap Order History.",
               category="technical_support", priority=TicketPriority.HIGH,
               status=TicketStatus.RESOLVED,
               created_at=NOW - timedelta(days=9), updated_at=NOW - timedelta(days=4)),
        Ticket(customer_id=maria.id, assigned_agent_id=None,
               subject="Where is my order? Tracking hasn't updated in 5 days",
               description="Tracking number shows 'label created' since last Tuesday.",
               category="order_tracking", priority=TicketPriority.MEDIUM,
               status=TicketStatus.CLOSED,
               created_at=NOW - timedelta(days=14), updated_at=NOW - timedelta(days=10)),
    ]
    db.add_all(tickets)
    db.flush()

    db.add_all([
        TicketMessage(ticket_id=tickets[0].id, sender_id=sarah.id, sender_type="customer",
                      content=tickets[0].description, is_internal=False,
                      created_at=tickets[0].created_at),
        TicketMessage(ticket_id=tickets[0].id, sender_id=agent.id, sender_type="agent",
                      content="Hi Sarah, I can see a stale session lock on the account. Clearing it now — please try again in 10 minutes.",
                      is_internal=False, created_at=NOW - timedelta(hours=5)),
        TicketMessage(ticket_id=tickets[0].id, sender_id=agent.id, sender_type="agent",
                      content="Session cache cleared server-side. Escalate to platform team if it recurs.",
                      is_internal=True, created_at=NOW - timedelta(hours=5)),
        TicketMessage(ticket_id=tickets[1].id, sender_id=james.id, sender_type="customer",
                      content=tickets[1].description, is_internal=False,
                      created_at=tickets[1].created_at),
    ])

    # ---- conversations ---------------------------------------
    conv1 = Conversation(customer_id=sarah.id, status="active", ai_active=True,
                         created_at=NOW - timedelta(hours=6), updated_at=NOW - timedelta(hours=6))
    conv2 = Conversation(customer_id=james.id, status="human_support", ai_active=False,
                         created_at=NOW - timedelta(days=1), updated_at=NOW - timedelta(hours=3))
    conv3 = Conversation(customer_id=maria.id, status="active", ai_active=True,
                         created_at=NOW - timedelta(hours=30), updated_at=NOW - timedelta(hours=29))
    db.add_all([conv1, conv2, conv3])
    db.flush()

    db.add_all([
        Message(conversation_id=conv1.id, sender_type="customer",
                content="How do I reset my password?", created_at=NOW - timedelta(hours=6)),
        Message(conversation_id=conv1.id, sender_type="ai",
                content="You can reset your password from Settings -> Security -> Reset Password. "
                        "You'll get an email with a reset link that's valid for 30 minutes.",
                intent="account_issue", confidence=0.93, created_at=NOW - timedelta(hours=6)),
        Message(conversation_id=conv2.id, sender_type="customer",
                content="My refund for order 4471 still hasn't arrived and it's been over a week.",
                created_at=NOW - timedelta(days=1)),
        Message(conversation_id=conv2.id, sender_type="ai",
                content="I'm sorry about the delay. This looks like it needs a human to check the "
                        "payment processor — I'm connecting you with support now.",
                intent="refund_request", confidence=0.44, created_at=NOW - timedelta(days=1)),
        Message(conversation_id=conv2.id, sender_type="agent",
                content="Hi James, Omar here. I've raised this with billing and will update you today.",
                created_at=NOW - timedelta(hours=3)),
        Message(conversation_id=conv3.id, sender_type="customer",
                content="Where is my order? Tracking hasn't moved in days.",
                created_at=NOW - timedelta(hours=30)),
        Message(conversation_id=conv3.id, sender_type="ai",
                content="I can help. Orders usually show movement within 48 hours of the label being "
                        "created. If it's been longer, I can open a tracking investigation ticket for you.",
                intent="order_tracking", confidence=0.81, created_at=NOW - timedelta(hours=29)),
    ])

    db.commit()


def attach_demo_sources(db) -> int:
    """
    Backfill RAG citations on the scripted demo conversations, using the real
    retriever now that the knowledge base exists. Keeps the seeded data honest -
    the sources shown in the dashboard are genuinely what retrieval returns.
    """
    from app.services.knowledge_service import retrieve_context

    updated = 0
    ai_messages = (
        db.query(Message)
        .filter(Message.sender_type == "ai", Message.sources.is_(None))
        .all()
    )
    for ai_msg in ai_messages:
        prompt = (
            db.query(Message)
            .filter(
                Message.conversation_id == ai_msg.conversation_id,
                Message.sender_type == "customer",
                Message.created_at <= ai_msg.created_at,
            )
            .order_by(Message.created_at.desc())
            .first()
        )
        if not prompt:
            continue
        _, sources = retrieve_context(db, prompt.content)
        if sources:
            ai_msg.sources = sources
            updated += 1

    db.commit()
    return updated


def main() -> None:
    fresh = "--fresh" in sys.argv
    use_kaggle = "--kaggle" in sys.argv

    if settings.is_sqlite:
        Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        existing = db.query(User).count()
        if existing and not fresh:
            print(f"Database already has {existing} users. Use --fresh to wipe and reseed.")
            return
        if fresh:
            wipe(db)
            print("Wiped existing rows.")
        seed(db)

        if use_kaggle:
            from scripts.build_kb import ingest_knowledge_base

            n_docs, n_emb = ingest_knowledge_base(db, embed=True, wipe=True)
            print(f"Knowledge base (Kaggle): {n_docs} documents, {n_emb} chunks embedded.")
        else:
            seed_knowledge(db)

        cited = attach_demo_sources(db)
        if cited:
            print(f"Attached RAG citations to {cited} demo AI messages.")

        from app.database.models import KnowledgeDocument

        print("Seeded:", db.query(User).count(), "users,",
              db.query(Ticket).count(), "tickets,",
              db.query(Conversation).count(), "conversations,",
              db.query(KnowledgeDocument).count(), "knowledge docs.")
        print("\nLogin as  admin@laurel.test / admin1234   (admin)")
        print("or        agent@laurel.test / agent1234   (agent)")
    finally:
        db.close()


if __name__ == "__main__":
    main()
