# Laurel Support Console (web dashboard)

Agent + admin web dashboard for the AI-Powered Customer Support Platform.
Built with Next.js (App Router) + TypeScript + Tailwind + TanStack Query.

## What it does

| Area | Screens |
|---|---|
| **Overview** | Dashboard — ticket counts, tickets-by-status, AI performance, recent activity |
| **Tickets** | List (search + filter by status / priority / category / assignee), detail (change status/priority/assignee, reply to customer, add internal notes) |
| **Conversations** | List (AI-handled vs agent-handled), transcript with intent + confidence badges, **take over from the AI**, reply as an agent |
| **Customers** | Directory + search, per-customer detail (their tickets, conversations, activity) |
| **Knowledge Base** | List documents, upload PDF / TXT / Markdown, add FAQ, archive, delete (admin only) |
| **Administration** | Users (activate/deactivate, change role), Agents (workload), AI Analytics |

Agents and admins see the operational screens; the Administration section is admin-only.
Customer accounts are rejected at login (they use the mobile app).

## Run it

```bash
# 1. start the backend first (see ../backend/README or below)
cd ../backend
python -m venv .venv && .venv/Scripts/activate      # or source .venv/bin/activate
pip install -r requirements.txt
python -m app.seed --fresh                            # demo data
uvicorn app.main:app --reload                         # http://localhost:8000

# 2. start the dashboard
cd ../web-dashboard
npm install
npm run dev                                           # http://localhost:3000
```

Sign in with `admin@laurel.test` / `admin1234` (admin) or `agent@laurel.test` / `agent1234` (agent).

## Configuration

`.env.local`:

```
NEXT_PUBLIC_API_BASE=http://localhost:8000/api/v1
```

Defaults to `http://localhost:8000/api/v1` if unset.

## Project layout

```
app/
  login/                     public sign-in
  (app)/                     authenticated shell (sidebar + top bar)
    dashboard/  tickets/  conversations/  customers/  knowledge/  admin/
lib/
  api.ts        typed fetch client (bearer token, error normalization)
  auth.tsx      session context (login / logout / current user)
  queries.ts    TanStack Query hooks — one per backend endpoint
  format.ts     ids, dates, labels
  nav.ts        sidebar config + role filtering
components/
  ui.tsx        buttons, badges, inputs, panels, states
  shell.tsx     app frame
  toast.tsx     notifications
  count-bars.tsx  lightweight CSS charts
```

## Build

```bash
npm run build     # production build; also runs the TypeScript check
```
