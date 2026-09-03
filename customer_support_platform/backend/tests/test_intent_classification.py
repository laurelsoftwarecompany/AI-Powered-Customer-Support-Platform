"""
Intent classification + escalation behaviour.

Runs against the deterministic `mock` provider so it needs no API key and no
network - it exercises the routing/escalation logic that every provider shares
(`_parse` applies the same rules to a real LLM's JSON).
"""
import pytest

from app.services.ai_service import generate_ai_response, _parse

pytestmark = pytest.mark.usefixtures("mock_provider")


# (customer message, expected intent)
INTENT_CASES = [
    ("I need to cancel my order, it is order number 5567", "order_cancellation"),
    ("Please cancel my recent purchase before it ships", "order_cancellation"),
    ("How do I request a refund for a broken product?", "refund_request"),
    ("I sent my item back last week, when do I get my money back?", "refund_request"),
    ("Where is my order? It still has not arrived.", "order_tracking"),
    ("Can you help me track my package?", "order_tracking"),
    ("My payment keeps failing when I try to pay", "payment_issue"),
    ("I was charged twice for one order", "payment_issue"),
    ("I cannot log in to my account", "account_issue"),
    ("I forgot my password and need to reset it", "account_issue"),
    ("The app crashes whenever I open my cart", "technical_support"),
    ("I keep getting an error when uploading a photo", "technical_support"),
    ("This is the worst service ever and I am furious", "complaint"),
    ("I want to speak to a manager right now", "complaint"),
    ("I have a question about my order", "order_support"),
    ("Do you sell this product in other colours?", "order_support"),
]


@pytest.mark.parametrize("message, expected", INTENT_CASES)
def test_intent_is_classified(message, expected):
    result = generate_ai_response(message)
    assert result["intent"] == expected, (
        f"{message!r} -> {result['intent']!r}, expected {expected!r}"
    )


def test_overall_intent_accuracy():
    correct = sum(
        generate_ai_response(m)["intent"] == expected for m, expected in INTENT_CASES
    )
    accuracy = correct / len(INTENT_CASES)
    assert accuracy >= 0.85, f"intent accuracy {accuracy:.0%} below 85%"


def test_every_response_has_the_required_shape():
    result = generate_ai_response("Where is my order?")
    assert set(result) >= {"response", "intent", "confidence", "should_escalate"}
    assert isinstance(result["response"], str) and result["response"].strip()
    assert 0.0 <= result["confidence"] <= 1.0
    assert isinstance(result["should_escalate"], bool)


# ------------------------------------------------------------------ escalation

def test_complaint_always_escalates():
    result = generate_ai_response("I want to speak to a manager right now")
    assert result["intent"] == "complaint"
    assert result["should_escalate"] is True


def test_confident_answer_does_not_escalate():
    result = generate_ai_response("How do I reset my password?")
    assert result["should_escalate"] is False


def test_unrecognised_message_escalates():
    result = generate_ai_response("qwerty asdf zxcv poiu lkjh")
    assert result["intent"] == "general_support"
    assert result["should_escalate"] is True


def test_mock_is_deterministic():
    a = generate_ai_response("Where is my order?")
    b = generate_ai_response("Where is my order?")
    assert a == b


# ------------------------------------------------------------------ _parse rules
# _parse turns a provider's raw JSON into the same shape, so test it directly.

def test_parse_reads_valid_json():
    out = _parse('{"response": "Here is how.", "intent": "account_issue", "confidence": 0.9}')
    assert out["response"] == "Here is how."
    assert out["intent"] == "account_issue"
    assert out["should_escalate"] is False


def test_parse_strips_code_fences():
    out = _parse('```json\n{"response": "hi", "intent": "general_support", "confidence": 0.8}\n```')
    assert out is not None and out["response"] == "hi"


def test_parse_forces_escalation_for_complaints_even_when_confident():
    out = _parse('{"response": "Sorry.", "intent": "complaint", "confidence": 0.99}')
    assert out["should_escalate"] is True


def test_parse_clamps_confidence_out_of_range():
    out = _parse('{"response": "x", "intent": "general_support", "confidence": 5}')
    assert out["confidence"] == 1.0


def test_parse_rejects_unknown_intent():
    out = _parse('{"response": "x", "intent": "make_me_a_sandwich", "confidence": 0.8}')
    assert out["intent"] == "general_support"


def test_parse_returns_none_on_garbage():
    assert _parse("the model said no") is None
    assert _parse("") is None
