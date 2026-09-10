# Database schema exports

Two different things live here. Pick the one that matches what you want.

## `database_tables.xlsx` — the visual schema

One workbook, one sheet per database table. **This is the file to load if you
want the tables drawn as connected boxes in Power BI.**

Get Data → Excel workbook → pick the file → **tick all 7 sheets** → Load.
Each sheet becomes its own table in Model view.

| Sheet | Rows |
|---|---|
| users | 6 |
| tickets | 10 |
| conversations | 72 |
| messages | 199 |
| ticket_messages | 86 |
| knowledge_documents | 115 |
| knowledge_chunks | 417 |

Two columns are deliberately excluded: `users.password_hash` (Argon2 hashes —
secret, and useless in a report) and `knowledge_chunks.embedding` (417 × 384
floats, replaced by an `embedding_dimensions` count). Long text is truncated to
500 characters to stay under Excel's cell limit.

### Relationships to create

Power BI's autodetect will not find these — a foreign key is named
`customer_id` while the key it points at is called `id`, and autodetect matches
on names. Create them once in **Model view → Manage relationships → New**.
All are **Many to one (\*:1)**, single direction, from the first column to the
second:

| From | To |
|---|---|
| `tickets[customer_id]` | `users[id]` |
| `tickets[assigned_agent_id]` | `users[id]` |
| `conversations[customer_id]` | `users[id]` |
| `messages[conversation_id]` | `conversations[id]` |
| `ticket_messages[ticket_id]` | `tickets[id]` |
| `ticket_messages[sender_id]` | `users[id]` |
| `knowledge_chunks[document_id]` | `knowledge_documents[id]` |
| `conversations[ticket_id]` | `tickets[id]` |
| `tickets[conversation_id]` | `conversations[id]` |

Power BI allows only one **active** relationship along a path. `users` is
referenced four times and `conversations` ↔ `tickets` is a two-way link, so
Power BI will mark some of them inactive (dashed line). That is expected —
they still draw on the diagram, and `USERELATIONSHIP()` activates one in a
measure when you need it.

The last two rows are **not enforced by the database**: `conversations.ticket_id`
and `tickets.conversation_id` are plain integer columns the application keeps in
sync by hand, with no `FOREIGN KEY` constraint. They are real relationships —
just unprotected.

## `schema_columns.csv`, `schema_tables.csv`, `schema_relationships.csv` — the data dictionary

Metadata *about* the database: every table, column, type, nullability, key,
index and relationship. Loading these gives you **one** table called
`schema_columns` — a searchable dictionary, not a diagram. Use it to document
the design or to drive a table-and-matrix page.

## Regenerating

```bash
backend/.venv/Scripts/python.exe backend/scripts/export_data_workbook.py   # xlsx
backend/.venv/Scripts/python.exe backend/scripts/export_schema.py          # csvs
```

Both read the live database and honour `DATABASE_URL`, so pointing them at the
Postgres container exports from there instead of the local SQLite file.

## One thing you will notice in the data

Enum columns store the Python enum **name**, not its value — `users.role` reads
`ADMIN`, `tickets.status` reads `IN_PROGRESS`. The API serialises them to
lowercase (`admin`, `in_progress`) correctly, so the apps are unaffected, but
anything reading the tables directly — Power BI included — sees uppercase.
