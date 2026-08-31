
from openai import OpenAI
import json

from app.config import settings


# ============================================================
# OPENROUTER CLIENT
# ============================================================

client = OpenAI(
    api_key=settings.OPENAI_API_KEY,
    base_url="https://openrouter.ai/api/v1"
)


# ============================================================
# ALLOWED INTENTS
# ============================================================

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


# ============================================================
# SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are an AI customer support agent.

Your job is to help customers with their questions and problems.

IMPORTANT RULES:

1. Only provide the final customer-facing response.

2. NEVER reveal your internal reasoning or thinking process.

3. NEVER say things like:
   - "Here's my thinking process"
   - "I analyzed your message"
   - "Step 1..."
   - "My reasoning is..."

4. Be polite, professional, helpful and concise.

5. Use the conversation history to understand context.

6. Remember information the customer has already provided.

7. Do not ask for information that the customer already provided.

8. NEVER invent:
   - order details
   - order status
   - prices
   - refund policies
   - delivery dates
   - account information
   - payment information
   - company policies

9. IMPORTANT:
   You do NOT currently have direct access to the company's order database.

10. Therefore, NEVER say:
    - "I found your order"
    - "I located your order"
    - "Your order is delivered"
    - "Your refund has been processed"
    - "I checked your account"

    unless that information is explicitly provided in the conversation
    or supplied by the application.

11. If the customer provides an order number, remember it.

12. If the customer asks about an order but we do not have actual order
    information, explain that you need the required information or that
    the order lookup system is not currently available.

13. If information is missing, politely ask for it.

14. Do not repeat questions that have already been answered.

15. Keep responses concise and natural.

You must classify every customer message into ONE of these intents:

order_support
refund_request
order_tracking
order_cancellation
payment_issue
account_issue
technical_support
general_support
complaint

Return ONLY valid JSON.

The JSON must contain exactly these fields:

{
    "response": "customer-facing response",
    "intent": "one allowed intent",
    "confidence": 0.95
}

The confidence must be a number between 0 and 1.

DO NOT return markdown.

DO NOT return ```json.

DO NOT return explanations outside the JSON.

DO NOT return your reasoning.
"""


# ============================================================
# HELPER: SAFE FALLBACK
# ============================================================

def fallback_response(
    message: str = (
        "I'm sorry, I couldn't process your request right now. "
        "Please try again."
    )
) -> dict:

    return {
        "response": message,
        "intent": "general_support",
        "confidence": 0.0
    }


# ============================================================
# MAIN AI FUNCTION
# ============================================================

def generate_ai_response(
    message: str,
    conversation_history: list | None = None
) -> dict:

    # --------------------------------------------------------
    # Build messages
    # --------------------------------------------------------

    messages = [
        {
            "role": "system",
            "content": SYSTEM_PROMPT
        }
    ]

    # --------------------------------------------------------
    # Add previous conversation history
    # --------------------------------------------------------

    if conversation_history:

        for item in conversation_history:

            sender_type = item.get("sender_type")
            content = item.get("content")

            if not content:
                continue

            content = str(content).strip()

            if not content:
                continue

            if sender_type == "customer":

                messages.append({
                    "role": "user",
                    "content": content
                })

            elif sender_type == "ai":

                messages.append({
                    "role": "assistant",
                    "content": content
                })

    # --------------------------------------------------------
    # Add current customer message
    # --------------------------------------------------------

    messages.append({
        "role": "user",
        "content": message
    })

    # --------------------------------------------------------
    # Call OpenRouter
    # --------------------------------------------------------

    try:

        response = client.chat.completions.create(
            model="openrouter/free",
            messages=messages,
            max_tokens=500,
            temperature=0.2
        )

    except Exception as e:

        print("=" * 60)
        print("OPENROUTER ERROR")
        print(str(e))
        print("=" * 60)

        return fallback_response(
            "I'm sorry, the AI service is temporarily unavailable. "
            "Please try again in a moment."
        )

    # --------------------------------------------------------
    # Extract AI response safely
    # --------------------------------------------------------

    try:

        if not response.choices:

            raise ValueError(
                "OpenRouter returned no choices"
            )

        choice = response.choices[0]

        if choice.message is None:

            raise ValueError(
                "OpenRouter returned an empty message"
            )

        raw_content = choice.message.content

        # Some models may return None
        if raw_content is None:

            raise ValueError(
                "OpenRouter returned empty content"
            )

        raw_response = str(raw_content).strip()

        if not raw_response:

            raise ValueError(
                "OpenRouter returned blank content"
            )

    except Exception as e:

        print("=" * 60)
        print("AI RESPONSE EXTRACTION ERROR")
        print(str(e))
        print("=" * 60)

        return fallback_response()

    # --------------------------------------------------------
    # Remove markdown code fences
    # --------------------------------------------------------

    if raw_response.startswith("```"):

        raw_response = raw_response.replace(
            "```json",
            "",
            1
        )

        raw_response = raw_response.replace(
            "```",
            ""
        )

        raw_response = raw_response.strip()

    # --------------------------------------------------------
    # Try to parse JSON
    # --------------------------------------------------------

    try:

        result = json.loads(raw_response)

    except json.JSONDecodeError:

        print("=" * 60)
        print("AI RETURNED NON-JSON RESPONSE")
        print("RAW RESPONSE:")
        print(raw_response)
        print("=" * 60)

        # Do NOT treat arbitrary model output as a successful
        # structured response.
        #
        # Instead return it as a normal customer-facing response
        # with a low confidence score.

        return {
            "response": raw_response,
            "intent": "general_support",
            "confidence": 0.30
        }

    # --------------------------------------------------------
    # Validate JSON object
    # --------------------------------------------------------

    if not isinstance(result, dict):

        print("AI returned JSON but it was not an object.")

        return fallback_response()

    # --------------------------------------------------------
    # Extract fields
    # --------------------------------------------------------

    ai_response = result.get("response")
    intent = result.get("intent")
    confidence = result.get("confidence")

    # --------------------------------------------------------
    # Validate response
    # --------------------------------------------------------

    if not ai_response:

        print("AI JSON missing 'response'")

        return fallback_response()

    ai_response = str(ai_response).strip()

    # --------------------------------------------------------
    # Validate intent
    # --------------------------------------------------------

    if intent not in ALLOWED_INTENTS:

        intent = "general_support"

    # --------------------------------------------------------
    # Validate confidence
    # --------------------------------------------------------

    try:

        confidence = float(confidence)

    except (TypeError, ValueError):

        confidence = 0.50

    # Keep confidence between 0 and 1

    confidence = max(
        0.0,
        min(1.0, confidence)
    )

    # --------------------------------------------------------
    # Final result
    # --------------------------------------------------------

    return {
        "response": ai_response,
        "intent": intent,
        "confidence": confidence
    }
