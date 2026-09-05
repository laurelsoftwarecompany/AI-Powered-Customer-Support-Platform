# Test Cases & Quality Assurance Matrix

## 1. Automated Test Suite (Pytest)

The backend includes **45 automated tests** validating core logic, RAG retrieval accuracy, intent classification, and security gates.

Execution command:
```bash
cd customer_support_platform/backend
.venv/Scripts/python.exe -m pytest -v
```

### 1.1 Intent Classification & Confidence Tests (`tests/test_ai_service.py`)
- `test_intent_classification_account_issue`: Asserts question about password reset maps to `account_issue`.
- `test_intent_classification_refund`: Asserts question about money back maps to `refund_request`.
- `test_intent_classification_order_tracking`: Asserts questions about shipping status map to `order_tracking`.
- `test_intent_classification_payment_failure`: Asserts card decline questions map to `payment_issue`.
- `test_confidence_scoring_bounds`: Verifies all returned confidence scores are between `0.0` and `1.0`.
- `test_mock_provider_determinism`: Validates offline mock returns predictable classifications without external internet.
- `test_provider_switching`: Confirms environment variables switch seamlessly between `mock`, `gemini`, and `openai`.

### 1.2 Knowledge Base & RAG Search Tests (`tests/test_knowledge_service.py`)
- `test_document_chunking_size`: Asserts documents are split into manageable semantic chunks with overlap.
- `test_vector_embedding_dimension`: Ensures `fastembed` produces exact 384-dimensional floating point vectors.
- `test_retrieval_relevance_password`: Verifies query `"how to reset password"` retrieves password documentation with score > 0.70.
- `test_retrieval_relevance_payment`: Verifies query `"card declined"` retrieves payment guides with high relevance.
- `test_retrieval_score_threshold_filtering`: Confirms irrelevant junk queries do not return false-positive documents.
- `test_embedding_cache_speed`: Tests that second search completes in under 100ms via the in-memory matrix cache.
- `test_cache_invalidation_on_archive`: Verifies that archiving a document updates the corpus signature and removes chunks from retrieval.
- `test_rag_eval_recall_at_5`: Evaluates retrieval recall over the benchmark dataset (`tests/data/rag_eval.jsonl`).

### 1.3 Escalation & Workflow Logic Tests (`tests/test_escalation.py`)
- `test_low_confidence_triggers_escalation`: Confirms queries below `0.70` confidence trigger human escalation flag.
- `test_complaint_intent_auto_escalates`: Asserts user expressing frustration/complaints automatically creates an urgent ticket.
- `test_auto_ticket_creation_on_escalation`: Confirms ticket is created in the database and linked to the conversation.
- `test_ai_conversation_deactivation`: Verifies `ai_active` is set to `false` upon human handoff.

### 1.4 API End-to-End & Security Tests (`tests/test_api_flow.py`)
- `test_customer_registration_success`: Tests `POST /api/v1/auth/register` creates user with `customer` role.
- `test_customer_registration_duplicate_email`: Asserts 400 Bad Request on duplicate email.
- `test_admin_route_protection`: Asserts regular customers receive 403 Forbidden when accessing `/api/v1/admin/*`.
- `test_user_creation_endpoint_locked`: Asserts unauthenticated callers cannot create admin accounts.
- `test_ticket_creation_and_retrieval`: Tests customer creating ticket and retrieving from `/api/v1/tickets/my`.
- `test_ticket_internal_notes_isolation`: Asserts internal notes created by agents are omitted from customer API responses.
- `test_message_sources_persistence`: Validates `Message.sources` JSON column stores and returns RAG citation metadata.

---

## 2. Acceptance Criteria Traceability Matrix

| # | Acceptance Criterion (`Team A.pdf`) | Automated Test / Verification Location | Status |
|---|---|---|---|
| **1** | Customer can register and log in | `test_customer_registration_success`, `test_auth_login` | ✅ Passed |
| **2** | Customer can communicate with AI | `test_api_send_message`, Flutter `ai_chat_screen.dart` | ✅ Passed |
| **3** | AI retrieves from Knowledge Base | `test_retrieval_relevance_*`, `test_rag_eval_recall_at_5` | ✅ Passed |
| **4** | AI identifies basic intents | `test_intent_classification_*` (11 intents tested) | ✅ Passed |
| **5** | AI escalates uncertain queries | `test_low_confidence_triggers_escalation` | ✅ Passed |
| **6** | Customers can create tickets | `test_ticket_creation_and_retrieval`, Flutter `create_ticket_screen.dart` | ✅ Passed |
| **7** | Agents can manage tickets | Next.js `/tickets`, status/priority/assignee mutations | ✅ Passed |
| **8** | Agents can take over conversations | `POST /conversations/{id}/takeover`, Next.js conversation detail | ✅ Passed |
| **9** | Admin can manage KB content | `POST /knowledge/upload`, `POST /knowledge/faq`, Next.js `/knowledge` | ✅ Passed |
| **10**| Web & mobile talk to same backend | Shared endpoints on `/api/v1`, cross-client reply verified | ✅ Passed |
| **11**| Auth & authorization work correctly | Role gates: customer, agent, admin; 401/403 enforced | ✅ Passed |
| **12**| Data is persisted | SQLAlchemy + SQLite/PostgreSQL with Alembic migrations | ✅ Passed |
| **13**| System is deployable | Dockerfiles for Backend and Web Dashboard + `docker-compose.yml` | ✅ Passed |
| **14**| Documentation provided | `README.md`, `docs/architecture.md`, `docs/api.md`, `docs/database_er.md` | ✅ Passed |
