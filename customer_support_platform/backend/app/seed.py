"""
Seed the database for production / initial startup.

    python -m app.seed          # seed only if the DB looks empty
    python -m app.seed --fresh  # wipe all rows first, then seed

Production accounts:
    hammadmehmood464@gmail.com / Hammad@1234  (admin)
    maoun.778899@gmail.com     / Aoun@1234    (agent)
"""

import sys
from datetime import datetime, timezone

from pwdlib import PasswordHash

from app.config import settings
from app.database.base import Base
from app.database.connection import SessionLocal, engine
from app.database.models import (
    Conversation,
    Message,
    Ticket,
    TicketMessage,
    User,
    UserRole,
)

password_hash = PasswordHash.recommended()

NOW = datetime.now(timezone.utc)


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
        existing = (
            db.query(knowledge_service.KnowledgeDocument)
            .filter_by(filename=filename)
            .first()
        )
        if not existing:
            knowledge_service.create_document(
                db,
                title=title,
                filename=filename,
                file_type=ftype,
                content=content,
            )


def seed(db) -> None:
    # ---- 1. Production Users ------------------------------------
    admin = db.query(User).filter(User.email == "hammadmehmood464@gmail.com").first()
    if admin:
        admin.name = "Hammad Mehmood"
        admin.password_hash = _hash("Hammad@1234")
        admin.role = UserRole.ADMIN
        admin.is_active = True
    else:
        admin = User(
            name="Hammad Mehmood",
            email="hammadmehmood464@gmail.com",
            password_hash=_hash("Hammad@1234"),
            role=UserRole.ADMIN,
            is_active=True,
        )
        db.add(admin)

    agent = db.query(User).filter(User.email == "maoun.778899@gmail.com").first()
    if agent:
        agent.name = "Aoun Muhammad"
        agent.password_hash = _hash("Aoun@1234")
        agent.role = UserRole.AGENT
        agent.is_active = True
    else:
        agent = User(
            name="Aoun Muhammad",
            email="maoun.778899@gmail.com",
            password_hash=_hash("Aoun@1234"),
            role=UserRole.AGENT,
            is_active=True,
        )
        db.add(agent)

    db.commit()


def main() -> None:
    fresh = "--fresh" in sys.argv
    use_kaggle = "--kaggle" in sys.argv

    if settings.is_sqlite:
        Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        existing = db.query(User).count()
        if existing and not fresh:
            print(f"Database already has {existing} users. Ensuring production admin and agent...")
            seed(db)
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

        from app.database.models import KnowledgeDocument

        print("Production seed completed:")
        print("Users:", db.query(User).count(),
              "| Tickets:", db.query(Ticket).count(),
              "| Conversations:", db.query(Conversation).count(),
              "| Knowledge docs:", db.query(KnowledgeDocument).count())
        print("\nAdmin Account: hammadmehmood464@gmail.com / Hammad@1234 (admin)")
        print("Agent Account: maoun.778899@gmail.com     / Aoun@1234   (agent)")
    finally:
        db.close()


if __name__ == "__main__":
    main()
