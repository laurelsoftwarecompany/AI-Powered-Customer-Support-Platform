# Final Demonstration & Presentation Script

This script provides a 5-to-7 minute step-by-step walkthrough to present to instructors, evaluators, and stakeholders.

---

## Pre-Demo Checklist

1. **Backend Server:**
   ```bash
   cd customer_support_platform/backend
   uvicorn app.main:app --port 8000 --reload
   ```
2. **Web Dashboard:**
   ```bash
   cd customer_support_platform/web-dashboard
   npm run dev
   ```
   Open in browser: `http://localhost:3000`
3. **Mobile App:**
   ```bash
   cd "customer_support_platform/Mobile app"
   flutter run -d chrome --web-port=8080
   ```
   Or on Android Emulator / Web Server at `http://127.0.0.1:8080`

---

## Step-by-Step Presentation Walkthrough

### Phase 1: Customer Mobile Experience & AI Grounding (2 Minutes)

1. **Customer Registration & Sign In:**
   - Open Mobile App. Tap **Create an Account**.
   - Enter Name (`Demo Customer`), Email (`demo@example.com`), Password (`secret123`).
   - Notice immediate JWT authentication and transition to the personalized Customer Dashboard displaying greeting and active ticket tiles.

2. **AI Support Chat with RAG Grounding:**
   - Tap **Ask AI Now**.
   - Type query: `"How do I reset my password?"`
   - **Showcase to Evaluator:**
     - The AI replies within seconds using verified company policy: *"To reset your password, navigate to Settings -> Security..."*
     - Highlight the **Intent Badge**: `account_issue`
     - Highlight the **Confidence Score**: `94%`
     - Highlight the **Source Citation Chip**: `Resetting a Forgotten Computer Password (Score: 0.84)`

3. **Multi-Turn Context & Escalation Trigger:**
   - Type follow-up query: `"I tried that already but I am locked out, I need to speak to a human manager immediately!"`
   - **Showcase to Evaluator:**
     - The system detects high emotional urgency and `complaint` intent.
     - The AI politely acknowledges the handoff: *"I've connected you with our human support team."*
     - The AI is automatically disabled (`ai_active: false`), and an urgent support ticket is automatically opened in the system.

---

### Phase 2: Staff Web Dashboard & Real-Time Triage (2 Minutes)

1. **Staff Sign In:**
   - Navigate to Web Dashboard `http://localhost:3000`.
   - Log in as Support Agent: `agent@laurel.test` / `agent1234`.

2. **Unified Operations Dashboard:**
   - Point out the metrics: Open Tickets, Resolved Tickets, Pending Tickets, and AI Resolution Rate.
   - Show the interactive tickets-by-status breakdown and AI performance cards.

3. **Review AI Conversation & Takeover:**
   - Click on **Conversations** in the sidebar.
   - Open the conversation just initiated by `Demo Customer`.
   - Point out that the agent sees the full transcript, customer queries, AI generated answers, confidence scores, and RAG sources used.
   - Demonstrate the **Take Over** button, showing how human agents smoothly assume ownership of the customer dialog.

4. **Ticket Management & Internal Collaboration:**
   - Click on **Tickets** in the sidebar.
   - Open the ticket created for `Demo Customer`.
   - Change Status from `Open` to `In Progress`.
   - Add a public reply: *"Hello Demo Customer, I am reviewing your account lock right now."*
   - Add an **Internal Note**: *"Checked auth logs, user had 5 failed attempts. Cleared lock."*
   - Switch back to the Mobile App to demonstrate that the customer receives the agent reply, while the **Internal Note is completely hidden from the customer view**.

---

### Phase 3: Administration, Knowledge Base & AI Analytics (1.5 Minutes)

1. **Admin Login:**
   - Log in as Administrator: `admin@laurel.test` / `admin1234`.
   - Show access to the **Administration** navigation section (hidden from regular agents).

2. **Dynamic Knowledge Base Upload & Chunking:**
   - Navigate to **Knowledge Base**.
   - Show the 115 indexed documents derived from Kaggle datasets.
   - Click **Add FAQ** or **Upload Document** to add a new company policy (e.g., Return window update).
   - Show that the document is instantly chunked and embedded via FastEmbed, immediately available to answer customer queries.

3. **AI Performance Analytics:**
   - Navigate to **AI Analytics**.
   - Show the breakdown of customer inquiry intents, average AI confidence, and the automated escalation distribution.

---

## Conclusion Statement for Evaluators
> *"The platform delivers a complete, cohesive support ecosystem: customers enjoy instant 24/7 AI assistance backed by strict RAG grounding and citations, while support agents and administrators possess centralized tooling to triage, collaborate, and take over seamlessly."*
