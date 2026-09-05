# System Architecture

## 1. High-Level Architecture

The **AI-Powered Customer Support Platform** is an enterprise-grade, multi-tier platform connecting customers, support agents, administrators, and an intelligent AI assistant grounded by Retrieval-Augmented Generation (RAG).

```mermaid
flowchart TB
    subgraph Clients["Client Layer"]
        Mobile["📱 Flutter Mobile App<br/>(Customer Portal)"]
        Web["💻 Next.js Web Dashboard<br/>(Agent & Admin Console)"]
    end

    subgraph Gateway["API Gateway & Services"]
        FastAPI["⚡ FastAPI Backend Engine<br/>(/api/v1 - Auth, Tickets, Chats, Admin)"]
    end

    subgraph Security["Security & Session"]
        Auth["🔐 OAuth2 & JWT Service<br/>(Argon2 Password Hashing)"]
    end

    subgraph AIService["AI & RAG Subsystem"]
        IntentClassifier["🎯 Intent Classifier & Confidence Evaluator"]
        LLMProvider["🧠 LLM Router<br/>(Gemini 2.5 Flash / Groq / OpenAI / Anthropic / Mock)"]
        VectorEngine["⚡ FastEmbed Engine<br/>(BAAI/bge-small-en-v1.5 - 384 Dim ONNX)"]
        EmbeddingCache["🚀 In-Memory Matrix Cache<br/>(Self-healing signature, ~80ms retrieval)"]
    end

    subgraph Persistence["Data & Storage Layer"]
        DB[(🗄️ PostgreSQL / SQLite<br/>Relational Storage with Composite Indexes)]
        KB[(📚 Knowledge Base<br/>115 Support Docs + 417 Chunks)]
    end

    Mobile -->|REST API + JWT Bearer| FastAPI
    Web -->|REST API + JWT Bearer| FastAPI
    FastAPI --> Auth
    FastAPI --> IntentClassifier
    FastAPI --> VectorEngine
    VectorEngine <--> EmbeddingCache
    VectorEngine --> KB
    IntentClassifier --> LLMProvider
    LLMProvider --> FastAPI
    FastAPI <--> DB
```

---

## 2. Component Breakdown

### 2.1 Customer Mobile Application (Flutter)
- **Target Audience:** End customers seeking instant answers or filing service tickets.
- **Key Modules:**
  - **Auth Feature:** Registration, login, JWT token caching with secure storage, session recovery.
  - **AI Chat Feature:** Conversational interface with real-time intent indicators, confidence badges, source citations, and human escalation trigger.
  - **Ticket Feature:** Ticket submission with priority and category selection, active ticket list, and complete interactive ticket message thread.
  - **Alerts Feature:** Dynamic notification list reflecting live ticket updates and status transitions.

### 2.2 Web Dashboard (Next.js 16 + Tailwind CSS)
- **Target Audience:** Support agents and system administrators.
- **Key Modules:**
  - **Support Dashboard:** High-level metrics, ticket status distribution, AI resolution efficiency, and recent tickets.
  - **Ticket Management:** Filterable queue (status, priority, assignee), message replying, internal agent-only notes, and assignment reassignment.
  - **Conversation Management:** Live transcripts of AI-customer interactions, intent/confidence badges, cited KB documents, and one-click agent takeover.
  - **Customer Directory:** 360-degree view of customer profiles, history, tickets, and conversations.
  - **Knowledge Base Manager:** Uploading articles (PDF, TXT, Markdown), adding structured FAQs, archiving outdated entries, and automated chunk re-indexing.
  - **Admin Analytics:** AI intent distribution breakdown, confidence trends, and escalation rates.

### 2.3 Backend API Layer (FastAPI + SQLAlchemy)
- **Framework:** FastAPI with asynchronous request handling and Pydantic v2 data validation schemas.
- **Data Persistence:** SQLAlchemy 2.0 ORM with Alembic database schema migrations.
- **Cross-Origin Resource Sharing:** Configured CORS supporting both Next.js (`:3000`) and Flutter web/desktop clients (`:8080`).
- **Data Isolation:** Enforces strict role-based access control (RBAC). Internal notes (`ticket_messages.is_internal`) are filtered server-side to ensure customers never receive private internal discussions.

---

## 3. Retrieval-Augmented Generation (RAG) Architecture

```mermaid
sequenceDiagram
    autonumber
    actor Customer as 📱 Customer (Mobile)
    participant API as ⚡ FastAPI Backend
    participant KS as 📚 Knowledge Service (FastEmbed)
    participant Cache as 🚀 Embedding Cache
    participant LLM as 🧠 LLM / Gemini Provider
    actor Agent as 💻 Support Agent (Web)

    Customer->>API: POST /conversations/{id}/messages ("How do I reset my password?")
    API->>KS: retrieve_context(query)
    KS->>Cache: Lookup normalized matrix (check signature)
    Cache-->>KS: Active embeddings matrix
    KS->>KS: FastEmbed cosine similarity top-4 chunks (score >= 0.50)
    KS-->>API: Grounding context + Source citations
    API->>LLM: generate_ai_response(query, history, context)
    LLM-->>API: { response, intent: "account_issue", confidence: 0.94 }
    alt Confidence >= Threshold (0.70)
        API->>API: Persist Message(sender='ai', sources=[...])
        API-->>Customer: Return AI response with citation chips
    else Low Confidence (< 0.70) or Complaint Intent
        API->>API: Auto-escalate conversation (ai_active=False)
        API->>API: Auto-generate Ticket(category, priority='urgent')
        API-->>Customer: "I've escalated this to our human support team."
        API->>Agent: Ticket appears in agent queue
    end
```

### Key RAG Optimizations
1. **Local Vector Search:** Uses `fastembed` with `BAAI/bge-small-en-v1.5` (384-dimensional vectors via ONNX runtime). No external vector database service or PyTorch GPU runtime is required.
2. **Signature-Based In-Memory Matrix Caching:**
   - Instead of decoding 417 embeddings from SQLite/Postgres on every single query (which incurred ~250ms overhead), the normalized matrix is cached in memory.
   - Cache invalidation is tracked using a zero-cost database signature (`count_active:max_updated_at`). Any document creation, edit, or archival automatically triggers a cache refresh.
   - Reduces retrieval latency from **~300ms down to ~80ms** (a ~73% performance improvement).
3. **Graceful Degradation:** If the external LLM provider encounters rate limits (e.g., Gemini free tier 10 RPM) or network timeouts, the system automatically falls back to an extractive knowledge-grounded response rather than failing or dropping customer queries.

---

## 4. Security & Role-Based Access Control (RBAC)

```mermaid
graph TD
    User([User Request]) --> AuthGate{Bearer JWT Valid?}
    AuthGate -- No --> Ret401[401 Unauthorized]
    AuthGate -- Yes --> RoleGate{User Role}

    RoleGate -- Customer --> CustRoutes[Allowed: /tickets/my, /conversations/my, /messages]
    RoleGate -- Agent --> AgentRoutes[Allowed: /tickets, /conversations/takeover, /internal-notes, /customers]
    RoleGate -- Admin --> AdminRoutes[Allowed: All endpoints + /knowledge/upload, /admin/analytics, /users]

    CustRoutes -- Attempt Admin Route --> Ret403[403 Forbidden]
```
