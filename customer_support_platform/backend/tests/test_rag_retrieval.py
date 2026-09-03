"""
Knowledge-base retrieval quality.

Needs a seeded KB (`python -m app.seed --fresh --kaggle`); skips otherwise.
Checks that a customer's question pulls back topically-relevant documents and
that off-topic questions do not smuggle in low-relevance noise.
"""
import json
from pathlib import Path

import pytest

from app.config import settings
from app.services import knowledge_service

BACKEND = Path(__file__).resolve().parent.parent
EVAL_FILE = BACKEND / "tests" / "data" / "rag_eval.jsonl"


# (query, any-of these words should appear in a retrieved document title)
RETRIEVAL_CASES = [
    ("how do I reset my forgotten password", ("password", "account", "sign-in", "pin")),
    ("my credit card was declined at checkout", ("payment", "billing")),
    ("where is my parcel, it has not been delivered", ("delivery", "shipping", "order")),
    ("I want to return an item and get a refund", ("refund", "return")),
    ("how do I cancel an order before it ships", ("cancel", "cancellation", "order")),
    ("set up my company email on an iphone", ("email", "mobile", "device")),
    ("I need to connect to the VPN from home", ("vpn", "remote", "secure connection")),
    ("the office printer keeps jamming", ("printer", "copier", "jam")),
]


@pytest.mark.parametrize("query, title_keywords", RETRIEVAL_CASES)
def test_retrieval_finds_relevant_documents(db, kb_ready, query, title_keywords):
    results = knowledge_service.search(db, query, top_k=settings.RAG_TOP_K)
    assert results, f"no results for {query!r}"
    titles = " ".join(r["document_title"].lower() for r in results)
    assert any(k in titles for k in title_keywords), (
        f"{query!r} -> {[r['document_title'] for r in results]}, "
        f"expected a title containing one of {title_keywords}"
    )


def test_retrieval_scores_are_ordered_and_normalised(db, kb_ready):
    results = knowledge_service.search(db, "how do I get a refund", top_k=5)
    scores = [r["score"] for r in results]
    assert scores == sorted(scores, reverse=True)
    assert all(-1.01 <= s <= 1.01 for s in scores)


def test_retrieve_context_builds_grounding_and_sources(db, kb_ready):
    context, sources = knowledge_service.retrieve_context(db, "how do I reset my password")
    assert context and isinstance(context, str)
    assert 1 <= len(sources) <= settings.RAG_TOP_K
    for s in sources:
        assert {"document_id", "title", "score", "snippet"} <= set(s)
        assert s["score"] >= settings.RAG_MIN_SCORE


def test_off_topic_query_is_not_force_grounded(db, kb_ready):
    context, sources = knowledge_service.retrieve_context(
        db, "what is the airspeed velocity of an unladen swallow"
    )
    # Either nothing clears the score floor, or at most a weak match or two -
    # the point is we don't hand the LLM a wall of irrelevant text.
    assert context is None or len(sources) <= 2


@pytest.mark.skipif(not EVAL_FILE.exists(), reason="rag_eval.jsonl not built")
def test_eval_set_recall(db, kb_ready):
    """Recall@5 over the held-out Sample-RAG-KI questions."""
    rows = [json.loads(line) for line in EVAL_FILE.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert rows, "eval file is empty"

    hits = 0
    for row in rows:
        results = knowledge_service.search(db, row["question"], top_k=5)
        topic_words = {w for w in row["topic"].lower().split() if len(w) > 3}
        titles = " ".join(r["document_title"].lower() for r in results)
        if any(w in titles for w in topic_words):
            hits += 1

    recall = hits / len(rows)
    assert recall >= 0.6, f"recall@5 = {recall:.0%} over {len(rows)} eval questions"
