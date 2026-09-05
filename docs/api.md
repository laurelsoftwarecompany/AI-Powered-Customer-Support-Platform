# REST API Documentation

Base URL: `http://localhost:8000/api/v1`  
Interactive Swagger Documentation: `http://localhost:8000/docs`  
Interactive ReDoc Documentation: `http://localhost:8000/redoc`

---

## 1. Authentication Endpoints

### 1.1 Register Customer
- **Endpoint:** `POST /api/v1/auth/register`
- **Access:** Public
- **Description:** Registers a new customer account. The system automatically assigns the `customer` role.

**Request Body:**
```json
{
  "name": "Alex Johnson",
  "email": "alex@example.com",
  "password": "SecurePassword123!"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "token_type": "bearer",
  "user": {
    "id": 7,
    "name": "Alex Johnson",
    "email": "alex@example.com",
    "role": "customer",
    "is_active": true
  }
}
```

---

### 1.2 User Login
- **Endpoint:** `POST /api/v1/auth/login`
- **Access:** Public
- **Description:** Authenticates any user (customer, agent, admin) via standard OAuth2 form-data or JSON.

**Request (Form Data / URL-encoded):**
```
username=alex@example.com&password=SecurePassword123!
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "token_type": "bearer",
  "user": {
    "id": 7,
    "name": "Alex Johnson",
    "email": "alex@example.com",
    "role": "customer",
    "is_active": true
  }
}
```

---

### 1.3 Current User Session
- **Endpoint:** `GET /api/v1/auth/me`
- **Access:** Authenticated (Bearer Token)
- **Description:** Returns the profile and permissions of the currently authenticated token bearer.

---

## 2. AI Chat & Conversations

### 2.1 Start New Conversation
- **Endpoint:** `POST /api/v1/conversations/`
- **Access:** Authenticated (Customer)
- **Response (200 OK):**
```json
{
  "id": 33,
  "customer_id": 7,
  "status": "active",
  "ai_active": true,
  "created_at": "2026-09-05T12:00:00Z",
  "updated_at": "2026-09-05T12:00:00Z"
}
```

---

### 2.2 Send Message to AI (RAG Trigger)
- **Endpoint:** `POST /api/v1/conversations/{id}/messages`
- **Access:** Authenticated (Customer / Staff)
- **Description:** Sends a prompt to the AI. Triggers vector similarity search across the knowledge base, context retrieval, intent identification, confidence calculation, and LLM answer generation.

**Request Body:**
```json
{
  "content": "How do I reset my account password?"
}
```

**Response (200 OK):**
```json
{
  "customer_message": {
    "id": 61,
    "conversation_id": 33,
    "sender_type": "customer",
    "content": "How do I reset my account password?",
    "created_at": "2026-09-05T12:00:01Z"
  },
  "ai_message": {
    "id": 62,
    "conversation_id": 33,
    "sender_type": "ai",
    "content": "You can reset your password by navigating to Settings -> Security -> Reset Password. A reset link will be sent to your registered email address.",
    "intent": "account_issue",
    "confidence": 0.94,
    "sources": [
      {
        "document_title": "Resetting a Forgotten Computer Password",
        "score": 0.84
      }
    ],
    "created_at": "2026-09-05T12:00:02Z"
  },
  "escalated": false,
  "ticket": null
}
```

---

### 2.3 Agent Takeover
- **Endpoint:** `POST /api/v1/conversations/{id}/takeover`
- **Access:** Support Agent / Admin
- **Description:** Disables the AI assistant on this conversation (`ai_active = false`) and marks the thread for human staff management.

---

## 3. Support Tickets

### 3.1 Create Support Ticket
- **Endpoint:** `POST /api/v1/tickets/`
- **Access:** Authenticated (Customer)

**Request Body:**
```json
{
  "subject": "Unable to access order history",
  "description": "Every time I tap on past orders the application crashes.",
  "category": "technical_support",
  "priority": "high"
}
```

---

### 3.2 List Customer Tickets
- **Endpoint:** `GET /api/v1/tickets/my`
- **Access:** Authenticated (Customer)
- **Description:** Returns the chronological list of tickets filed by the requesting customer.

---

### 3.3 Post Message to Ticket
- **Endpoint:** `POST /api/v1/tickets/{id}/messages`
- **Access:** Authenticated (Customer or Staff)

**Request Body:**
```json
{
  "content": "I have verified that restarting the device does not solve it."
}
```

---

### 3.4 Post Internal Agent Note
- **Endpoint:** `POST /api/v1/tickets/{id}/internal-notes`
- **Access:** Support Agent / Admin
- **Description:** Adds an internal staff note (`is_internal = true`). Customers are completely prevented from viewing this note.

---

## 4. Knowledge Base Management

### 4.1 List Documents
- **Endpoint:** `GET /api/v1/knowledge/documents`
- **Access:** Support Agent / Admin
- **Query Params:** `query` (optional string search), `file_type` (optional filter)

---

### 4.2 Upload Knowledge Document
- **Endpoint:** `POST /api/v1/knowledge/upload`
- **Access:** Admin only
- **Format:** `multipart/form-data` with `file` (.pdf, .txt, .md)
- **Processing:** Automatically parses text, chunks into semantic segments, computes 384-d vectors, and caches in the index matrix.

---

### 4.3 Add FAQ Entry
- **Endpoint:** `POST /api/v1/knowledge/faq`
- **Access:** Admin only

**Request Body:**
```json
{
  "question": "What is the return window for electronics?",
  "answer": "Electronics can be returned within 30 days of delivery with original packaging.",
  "category": "returns"
}
```
