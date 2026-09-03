"""
AI support assistant.

`generate_ai_response(message, conversation_history)` returns:
    {"response": str, "intent": str, "confidence": float, "should_escalate": bool}

Provider is chosen by settings.AI_PROVIDER:
    mock       - deterministic canned answers, no API key (default; good for demo/tests)
    gemini     - Google AI Studio (OpenAI-compatible endpoint)   -> GEMINI_API_KEY
    groq       - Groq (OpenAI-compatible endpoint)               -> GROQ_API_KEY
    openrouter - OpenRouter (OpenAI-compatible endpoint)         -> OPENROUTER_API_KEY
    openai     - OpenAI                                          -> OPENAI_API_KEY
    anthropic  - Anthropic (native SDK)                          -> ANTHROPIC_API_KEY

The optional `context` arg carries retrieved knowledge-base passages; the
caller (app/api/messages.py) runs retrieval and passes them in. Every provider,
mock included, grounds its answer in that context when it is present.
"""

from __future__ import annotations

import json
import re

from app.config import settings

# ============================================================
# CONFIG
# ============================================================

CONFIDENCE_THRESHOLD = settings.CONFIDENCE_THRESHOLD

ALLOWED_INTENTS = {
    "order_support",
    "refund_request",
    "order_tracking",
    "order_cancellation",
    "payment_issue",
    "account_issue",
    "technical_support",
    "general_support",
    "complaint",
}

PROVIDER_DEFAULTS = {
    "gemini": "gemini-2.5-flash",
    "groq": "llama-3.3-70b-versatile",
    "openrouter": "meta-llama/llama-3.3-70b-instruct:free",
    "openai": "gpt-4o-mini",
    "anthropic": "claude-haiku-4-5",
}

_OPENAI_COMPATIBLE = {
    "gemini": (
        "https://generativelanguage.googleapis.com/v1beta/openai/",
        lambda: settings.GEMINI_API_KEY,
    ),
    "groq": ("https://api.groq.com/openai/v1", lambda: settings.GROQ_API_KEY),
    "openrouter": (
        "https://openrouter.ai/api/v1",
        lambda: settings.OPENROUTER_API_KEY or settings.OPENAI_API_KEY,
    ),
    "openai": (None, lambda: settings.OPENAI_API_KEY),
}


def _model() -> str:
    return settings.AI_MODEL or PROVIDER_DEFAULTS.get(settings.AI_PROVIDER, "")


# ============================================================
# SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """You are the AI customer support assistant for a customer support platform.

Provide helpful, concise, professional customer-facing answers.

RULES
1. Never reveal your internal reasoning, chain-of-thought, or analysis steps.
2. Never output moderation labels or internal notes.
3. Only return the final customer-facing answer (inside the JSON below).
4. Do not invent order details, payment info, account data, prices, delivery
   dates, or company policies. If information is unavailable, say so and ask the
   customer for what you need.
5. When knowledge-base context is provided, ground your answer in it and do not
   contradict it. If the context does not cover the question, say you are not
   certain and offer to connect a human agent.
6. Keep answers natural and concise. Use the conversation history.
7. Classify every message into exactly ONE allowed intent.

Allowed intents: order_support, refund_request, order_tracking,
order_cancellation, payment_issue, account_issue, technical_support,
general_support, complaint
  - account_issue: sign-in, password, 2FA, profile, account access
  - technical_support: app bugs, errors, crashes, features not working
  - complaint: the customer is expressing dissatisfaction or wants to escalate

Return ONLY valid JSON, exactly these fields:
{"response": "customer-facing answer", "intent": "one allowed intent", "confidence": 0.0}

confidence is your certainty (0-1) that the answer fully resolves the request.
No markdown, no code fences, no extra fields, no text outside the JSON."""


# ============================================================
# RESPONSE CLEANUP / VALIDATION
# ============================================================

def _clean(text: str) -> str:
    if not text:
        return ""
    text = re.sub(r"```(?:json|text)?", "", text, flags=re.IGNORECASE).replace("```", "")
    return text.strip()


def _validate_intent(intent) -> str:
    intent = str(intent or "").strip().lower()
    return intent if intent in ALLOWED_INTENTS else "general_support"


def _parse(raw: str) -> dict | None:
    raw = _clean(raw)
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", raw, re.DOTALL)
        if not m:
            return None
        try:
            parsed = json.loads(m.group(0))
        except json.JSONDecodeError:
            return None
    if not isinstance(parsed, dict):
        return None

    response = parsed.get("response", "")
    if not isinstance(response, str) or not response.strip():
        return None

    try:
        confidence = float(parsed.get("confidence", 0.0))
    except (TypeError, ValueError):
        confidence = 0.0
    confidence = max(0.0, min(1.0, confidence))

    intent = _validate_intent(parsed.get("intent"))

    return {
        "response": response.strip(),
        "intent": intent,
        "confidence": confidence,
        # Hand off when the model is unsure, or whenever it's a complaint -
        # an unhappy customer should always reach a human.
        "should_escalate": confidence < CONFIDENCE_THRESHOLD or intent == "complaint",
    }


# ============================================================
# PROVIDERS
# ============================================================

_client_cache: dict = {}


def _openai_compatible_chat(provider: str, messages: list[dict]) -> str:
    from openai import OpenAI

    base_url, key_fn = _OPENAI_COMPATIBLE[provider]
    key = key_fn()
    if not key:
        raise RuntimeError(f"{provider}: API key not set")

    client = _client_cache.get(provider)
    if client is None:
        # max_retries covers the free-tier 429s and transient 5xx with backoff.
        opts = dict(api_key=key, max_retries=3, timeout=30.0)
        client = OpenAI(base_url=base_url, **opts) if base_url else OpenAI(**opts)
        _client_cache[provider] = client

    kwargs = dict(model=_model(), messages=messages, temperature=0.2, max_tokens=700)
    if provider in {"gemini", "groq", "openai"}:
        kwargs["response_format"] = {"type": "json_object"}

    resp = client.chat.completions.create(**kwargs)
    return resp.choices[0].message.content or ""


def _anthropic_chat(messages: list[dict]) -> str:
    import anthropic

    key = settings.ANTHROPIC_API_KEY
    if not key:
        raise RuntimeError("anthropic: ANTHROPIC_API_KEY not set")

    client = _client_cache.get("anthropic")
    if client is None:
        client = anthropic.Anthropic(api_key=key)
        _client_cache["anthropic"] = client

    system = messages[0]["content"]
    convo = [m for m in messages[1:]]
    resp = client.messages.create(
        model=_model(),
        max_tokens=700,
        system=system,
        messages=convo,
    )
    return "".join(block.text for block in resp.content if block.type == "text")


# ---- mock ---------------------------------------------------

_MOCK_RULES = [
    ("order_cancellation", 0.9, ("cancel", "cancellation"),
     "You can cancel an order from your account under Orders - open the order and "
     "choose Cancel, as long as it hasn't shipped yet. If it has already shipped, "
     "you can refuse delivery or start a return once it arrives."),
    ("refund_request", 0.88, ("refund", "money back", "reimburse"),
     "Refunds go back to your original payment method within 5-7 business days once "
     "a return is approved. If it's been longer than that, let me know your order "
     "number and I'll have an agent look into it."),
    ("order_tracking", 0.9, ("track", "where is my order", "delivery status", "hasn't arrived", "not arrived"),
     "You can see live tracking in your account under Orders. Carriers usually scan "
     "a parcel within 48 hours of the label being created; if it's been longer, I "
     "can open a tracking investigation for you."),
    ("payment_issue", 0.87, ("payment", "card declined", "can't pay", "cannot pay", "checkout fail", "charged twice"),
     "Payment failures are usually an expired card, a wrong billing ZIP, or the bank "
     "blocking the charge. Please double-check the card details and try again, or add "
     "another payment method under Settings - Billing."),
    ("account_issue", 0.9, ("password", "reset", "log in", "login", "sign in", "locked out", "can't access"),
     "To reset your password, go to Settings - Security - Reset Password and use the "
     "emailed link (valid 30 minutes). If you can't reach that email, an agent can "
     "verify your identity and update it."),
    ("technical_support", 0.8, ("bug", "error", "crash", "not working", "broken", "glitch"),
     "Sorry that's happening. Try refreshing or reinstalling the app first. If it "
     "continues, tell me what you were doing when it happened and I'll raise a ticket "
     "with the technical team."),
    ("complaint", 0.4, ("complaint", "terrible", "awful", "unacceptable", "angry", "worst", "sue", "manager"),
     "I'm really sorry about this experience. I want to make sure it's handled "
     "properly, so I'm connecting you with a human support agent now."),
    ("order_support", 0.85, ("order", "purchase", "item", "product"),
     "I can help with your order. Could you share the order number and what you'd "
     "like to change or check?"),
]


def _passage_from_context(context: str, limit: int = 700) -> str:
    """Flatten retrieved context into one clean paragraph for the fallback answer."""
    # Drop the "[1] Title" header lines retrieve_context() prepends, and light
    # markdown, then collapse to a single paragraph of real KB text.
    text = re.sub(r"(?m)^\[\d+\][^\n]*\n?", "", context)
    text = text.replace("**", "").replace("#", "")
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    cut = text[:limit]
    for sep in (". ", "! ", "? "):
        idx = cut.rfind(sep)
        if idx > limit * 0.5:
            return cut[: idx + 1].strip()
    return cut.rstrip(",;: ") + "…"


def _mock(message: str, history: list[dict], context: str | None = None) -> dict:
    text = message.lower()
    intent, confidence, answer = "general_support", 0.55, None
    for rule_intent, rule_conf, keys, rule_answer in _MOCK_RULES:
        if any(k in text for k in keys):
            intent, confidence, answer = rule_intent, rule_conf, rule_answer
            break

    # An explicit complaint always goes to a human, KB hit or not.
    if intent == "complaint":
        return {
            "response": answer,
            "intent": intent,
            "confidence": confidence,
            "should_escalate": True,
        }

    # Retrieval found something relevant -> answer from it (extractive RAG).
    if context:
        passage = _passage_from_context(context)
        if passage:
            grounded = (
                f"{passage}\n\nIf that doesn't fully answer your question, let me "
                f"know and I'll connect you with a support agent."
            )
            conf = max(confidence, 0.82)
            return {
                "response": grounded,
                "intent": intent,
                "confidence": conf,
                "should_escalate": conf < CONFIDENCE_THRESHOLD,
            }

    # No KB context -> canned rule answer, or the generic fallback.
    if answer:
        return {
            "response": answer,
            "intent": intent,
            "confidence": confidence,
            "should_escalate": confidence < CONFIDENCE_THRESHOLD,
        }
    return {
        "response": (
            "Thanks for reaching out. I want to point you to the right place - could "
            "you tell me a bit more about what you need help with (an order, a refund, "
            "your account, or something else)?"
        ),
        "intent": "general_support",
        "confidence": 0.55,
        "should_escalate": True,
    }


# ============================================================
# PUBLIC ENTRY POINT
# ============================================================

def generate_ai_response(
    message: str,
    conversation_history: list[dict] | None = None,
    context: str | None = None,
) -> dict:
    history = conversation_history or []
    provider = settings.AI_PROVIDER

    if provider == "mock":
        return _mock(message, history, context)

    system = SYSTEM_PROMPT
    if context:
        system += f"\n\nKNOWLEDGE BASE CONTEXT:\n{context}"

    messages = [{"role": "system", "content": system}]
    for h in history:
        role = "user" if h.get("sender_type") == "customer" else "assistant"
        if h.get("content"):
            messages.append({"role": role, "content": h["content"]})
    messages.append({"role": "user", "content": message})

    try:
        if provider == "anthropic":
            raw = _anthropic_chat(messages)
        elif provider in _OPENAI_COMPATIBLE:
            raw = _openai_compatible_chat(provider, messages)
        else:
            print(f"AI service: unknown provider {provider!r}, using mock")
            return _mock(message, history, context)
    except Exception as exc:  # noqa: BLE001
        # Provider down or rate-limited (free tiers 429 readily). Degrade to the
        # local answerer, which still grounds in the retrieved context.
        print(f"AI service error ({provider}): {exc} - using local fallback")
        return _mock(message, history, context)

    parsed = _parse(raw)
    if parsed is None:
        print(f"AI service: unparseable {provider} response - using local fallback")
        return _mock(message, history, context)
    return parsed
