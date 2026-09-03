"""
Build the knowledge base from Kaggle datasets.

    python -m scripts.build_kb            # wipe KB, ingest, embed
    python -m scripts.build_kb --no-embed # ingest only (faster; embed later via /knowledge/reindex)

Sources (download with the Kaggle CLI into backend/data/kaggle/, see DATA.md):
  - bitext/bitext-gen-ai-chatbot-customer-support-dataset  -> per-category support articles
  - saadmakhdoom/ecommerce-faq-chatbot-dataset             -> topical FAQ bundles
  - dkhundley/synthetic-it-related-knowledge-items          -> IT helpdesk articles
  - dkhundley/sample-rag-knowledge-item-dataset             -> RAG eval set (tests/data/rag_eval.jsonl)
"""

from __future__ import annotations

import argparse
import collections
import csv
import json
import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent
DATA = BACKEND / "data" / "kaggle"
EVAL_OUT = BACKEND / "tests" / "data" / "rag_eval.jsonl"

csv.field_size_limit(10_000_000)


# ------------------------------------------------------------------ helpers

_PLACEHOLDER_MAP = {
    "order number": "your order number",
    "invoice number": "your invoice number",
    "tracking number": "your tracking number",
    "person name": "you",
    "customer name": "you",
    "client name": "you",
    "salutation": "",
    "company name": "our company",
    "website url": "our website",
    "online company portal info": "our website",
    "online order interaction": "our website",
    "store location": "our store",
    "account category": "your account",
    "account type": "your account",
    "refund amount": "the refund amount",
    "money amount": "the amount",
    "currency symbol": "",
    "date": "the relevant date",
    "date range": "the relevant dates",
    "time": "the relevant time",
    "delivery city": "your area",
    "delivery country": "your area",
    "shipping cut-off time": "the shipping cut-off time",
    "delivery options": "the delivery options",
}


def strip_placeholders(text: str) -> str:
    def repl(m: re.Match) -> str:
        key = m.group(1).strip().lower()
        if key in _PLACEHOLDER_MAP:
            return _PLACEHOLDER_MAP[key]
        return key  # fall back to the human-readable inner label
    text = re.sub(r"\{\{\s*([^}]+?)\s*\}\}", repl, text)
    # tidy artifacts left by generic placeholder substitution
    text = re.sub(r"'?our website'?(?:\s+or\s+'?our website'?)+", "our website", text, flags=re.I)
    text = re.sub(r"\byour our\b", "our", text, flags=re.I)
    text = re.sub(r"\b(the|our|your) \1\b", r"\1", text, flags=re.I)
    text = re.sub(r"\s{2,}", " ", text)
    text = re.sub(r"\s+([.,!?])", r"\1", text)
    return text.strip()


CATEGORY_TITLES = {
    "ACCOUNT": "Account Management",
    "CANCEL": "Order Cancellation",
    "CANCELLATION_FEE": "Cancellation Fees",
    "CONTACT": "Contacting Support",
    "DELIVERY": "Delivery",
    "FEEDBACK": "Feedback & Complaints",
    "INVOICE": "Invoices",
    "NEWSLETTER": "Newsletter",
    "ORDER": "Orders",
    "PAYMENT": "Payments",
    "REFUND": "Refunds",
    "SHIPPING": "Shipping Addresses",
    "SUBSCRIPTION": "Subscriptions",
}

_INFO_HINTS = re.compile(
    r"\b(go to|click|select|navigate|steps?|you can|within \d|policy|days?|"
    r"settings|menu|option|page|section|follow|enter|provide|contact|email|phone)\b",
    re.I,
)


def _best_response(responses: list[str]) -> str:
    """Pick the most informative response for an intent (has actionable content, longest)."""
    scored = sorted(
        responses,
        key=lambda r: (len(_INFO_HINTS.findall(r)), len(r)),
        reverse=True,
    )
    return scored[0]


# ------------------------------------------------------------------ Bitext

def load_bitext() -> list[dict]:
    path = next(
        (DATA / "bitext-gen-ai-chatbot-customer-support-dataset").glob("*.csv"), None
    )
    if not path:
        print("  ! Bitext CSV missing - skipping")
        return []

    by_cat: dict[str, dict[str, dict]] = collections.defaultdict(
        lambda: collections.defaultdict(
            lambda: {"instr": None, "instr_clean": False, "resp": []}
        )
    )
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            slot = by_cat[row["category"]][row["intent"]]
            slot["resp"].append(row["response"])
            if "{{" in row["instruction"]:
                continue
            # prefer a clean example question: skip colloquial (Q), noise (Z),
            # offensive (W), keyboard-typo (K) flag variants
            is_clean = not (set(row.get("flags", "")) & set("QZWK"))
            if slot["instr"] is None or (is_clean and not slot["instr_clean"]):
                slot["instr"] = row["instruction"]
                slot["instr_clean"] = is_clean

    docs = []
    for cat, intents in by_cat.items():
        title = CATEGORY_TITLES.get(cat, cat.title())
        parts = [f"# {title}", ""]
        for intent, slot in sorted(intents.items()):
            heading = intent.replace("_", " ").title()
            answer = strip_placeholders(_best_response(slot["resp"]))
            question = strip_placeholders(slot["instr"] or heading).capitalize()
            parts += [f"## {heading}", "", f"**Question:** {question}", "", answer, ""]
        docs.append(
            {
                "title": f"{title} - Support Guide",
                "filename": f"bitext:{cat.lower()}",
                "file_type": "md",
                "content": "\n".join(parts).strip(),
            }
        )
    print(f"  Bitext        -> {len(docs)} category guides")
    return docs


# ------------------------------------------------------------------ Ecommerce FAQ

_FAQ_TOPICS = [
    ("Account & Sign-in", ("account", "sign up", "sign in", "log in", "password", "profile")),
    ("Orders", ("order", "cart", "checkout", "cancel", "modify")),
    ("Payments & Billing", ("payment", "pay", "card", "paypal", "charge", "billing", "invoice", "coupon", "discount")),
    ("Shipping & Delivery", ("ship", "deliver", "tracking", "address", "courier", "arrive")),
    ("Returns & Refunds", ("return", "refund", "exchange", "warranty", "damaged", "defective")),
    ("General", ()),
]


def _faq_topic(question: str) -> str:
    q = question.lower()
    for name, keys in _FAQ_TOPICS:
        if any(k in q for k in keys):
            return name
    return "General"


def load_ecommerce_faq() -> list[dict]:
    path = DATA / "ecommerce-faq-chatbot-dataset" / "Ecommerce_FAQ_Chatbot_dataset.json"
    if not path.exists():
        print("  ! Ecommerce FAQ JSON missing - skipping")
        return []

    raw = json.loads(path.read_text(encoding="utf-8"))
    items = raw["questions"] if isinstance(raw, dict) else raw

    buckets: dict[str, list[str]] = collections.defaultdict(list)
    for it in items:
        q, a = it["question"].strip(), it["answer"].strip()
        buckets[_faq_topic(q)].append(f"**{q}**\n\n{a}")

    docs = []
    for topic, entries in buckets.items():
        docs.append(
            {
                "title": f"FAQ - {topic}",
                "filename": f"ecommerce-faq:{topic.lower().split()[0]}",
                "file_type": "faq",
                "content": f"# Frequently Asked Questions - {topic}\n\n"
                + "\n\n---\n\n".join(entries),
            }
        )
    print(f"  Ecommerce FAQ -> {len(docs)} FAQ bundles ({len(items)} Q&A pairs)")
    return docs


# ------------------------------------------------------------------ IT knowledge items

def load_it_kb() -> list[dict]:
    path = DATA / "synthetic-it-related-knowledge-items" / "synthetic_knowledge_items.csv"
    if not path.exists():
        print("  ! IT KI CSV missing - skipping")
        return []

    docs, seen = [], set()
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            topic = row["ki_topic"].strip()
            text = (row.get("ki_text") or "").strip()
            key = topic.lower()
            if not text or key in seen:
                continue
            seen.add(key)
            docs.append(
                {
                    "title": topic,
                    "filename": f"it-kb:{key.replace(' ', '_')[:40]}",
                    "file_type": "md",
                    "content": text,
                }
            )
    print(f"  IT KB         -> {len(docs)} helpdesk articles")
    return docs


# ------------------------------------------------------------------ RAG eval set

def write_rag_eval() -> int:
    path = DATA / "sample-rag-knowledge-item-dataset" / "rag_sample_qas_from_kis.csv"
    if not path.exists():
        print("  ! RAG eval CSV missing - skipping")
        return 0
    EVAL_OUT.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    with open(path, encoding="utf-8") as f, open(EVAL_OUT, "w", encoding="utf-8") as out:
        for row in csv.DictReader(f):
            out.write(
                json.dumps(
                    {
                        "topic": row["ki_topic"].strip(),
                        "question": row["sample_question"].strip().strip('"'),
                        "ground_truth": row["sample_ground_truth"].strip(),
                    }
                )
                + "\n"
            )
            n += 1
    print(f"  RAG eval      -> {n} question/answer pairs -> {EVAL_OUT.relative_to(BACKEND)}")
    return n


# ------------------------------------------------------------------ orchestration

def build_documents() -> list[dict]:
    return [*load_bitext(), *load_ecommerce_faq(), *load_it_kb()]


def ingest_knowledge_base(db, *, embed: bool = True, wipe: bool = True) -> tuple[int, int]:
    """Build + ingest the KB. Returns (documents, chunks_embedded)."""
    from app.database.models import KnowledgeChunk, KnowledgeDocument
    from app.services import knowledge_service

    if wipe:
        db.query(KnowledgeChunk).delete()
        db.query(KnowledgeDocument).delete()
        db.commit()

    docs = build_documents()
    for d in docs:
        knowledge_service.create_document(db, **d)

    embedded = 0
    if embed and docs:
        print("  embedding chunks (first run downloads the model ~30 MB)...")
        embedded = knowledge_service.reindex(db)
    return len(docs), embedded


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-embed", action="store_true", help="skip embedding")
    parser.add_argument("--keep", action="store_true", help="do not wipe existing KB")
    args = parser.parse_args()

    if not DATA.exists():
        sys.exit(
            f"No data at {DATA}. Download the datasets first - see backend/DATA.md"
        )

    from app.config import settings
    from app.database.base import Base
    from app.database.connection import SessionLocal, engine

    if settings.is_sqlite:
        Base.metadata.create_all(bind=engine)

    write_rag_eval()

    db = SessionLocal()
    try:
        n_docs, n_emb = ingest_knowledge_base(
            db, embed=not args.no_embed, wipe=not args.keep
        )
        print(f"\nKnowledge base: {n_docs} documents, {n_emb} chunks embedded.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
