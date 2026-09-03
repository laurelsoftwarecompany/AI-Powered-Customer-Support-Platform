"use client";

import { use, useState } from "react";
import Link from "next/link";
import { ArrowLeft, Lock, Send, StickyNote } from "lucide-react";
import {
  useTicket,
  useTicketMessages,
  useUpdateTicket,
  useReplyToTicket,
  useAddInternalNote,
  useUserMap,
} from "@/lib/queries";
import { useToast } from "@/components/toast";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  PanelHeader,
  Button,
  Select,
  Textarea,
  Spinner,
  DetailSkeleton,
  ErrorState,
  StatusBadge,
  PriorityBadge,
  Avatar,
  Field,
  cn,
} from "@/components/ui";
import {
  STATUS_LABEL,
  STATUS_ORDER,
  PRIORITY_LABEL,
  PRIORITY_ORDER,
  ticketNo,
  titleCase,
  dateTime,
} from "@/lib/format";
import type { TicketPriority, TicketStatus } from "@/lib/types";

export default function TicketDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: idParam } = use(params);
  const id = Number(idParam);
  const { notify } = useToast();

  const ticket = useTicket(id);
  const messages = useTicketMessages(id);
  const userMap = useUserMap();
  const update = useUpdateTicket(id);
  const reply = useReplyToTicket(id);
  const note = useAddInternalNote(id);

  const [draft, setDraft] = useState("");
  const [noteDraft, setNoteDraft] = useState("");
  const [mode, setMode] = useState<"reply" | "note">("reply");

  if (ticket.isLoading) return <DetailSkeleton />;
  if (ticket.isError)
    return <ErrorState message={(ticket.error as Error).message} />;
  const t = ticket.data!;

  const customer = userMap.get(t.customer_id);
  const agents = [...userMap.values()].filter(
    (u) => u.role === "agent" || u.role === "admin",
  );

  async function patch(
    field: "status" | "priority" | "assigned_agent_id",
    value: string,
  ) {
    try {
      await update.mutateAsync({
        [field]:
          field === "assigned_agent_id"
            ? value === ""
              ? null
              : Number(value)
            : value,
      } as never);
      notify("Ticket updated.");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  async function submit() {
    try {
      if (mode === "reply") {
        if (!draft.trim()) return;
        await reply.mutateAsync(draft.trim());
        setDraft("");
        notify("Reply sent to customer.");
      } else {
        if (!noteDraft.trim()) return;
        await note.mutateAsync(noteDraft.trim());
        setNoteDraft("");
        notify("Internal note added.");
      }
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  return (
    <>
      <Link
        href="/tickets"
        className="mb-3 inline-flex items-center gap-1 text-[12.5px] text-ink-faint hover:text-ink"
      >
        <ArrowLeft size={14} /> Back to tickets
      </Link>

      <PageHeader
        title={t.subject}
        subtitle={`${ticketNo(t.id)} · ${titleCase(t.category)} · opened ${dateTime(t.created_at)}`}
      />

      <div className="grid gap-4 lg:grid-cols-[1fr_280px]">
        {/* thread */}
        <div className="flex flex-col gap-3">
          <Panel>
            <PanelHeader title="Conversation" />
            <div className="flex flex-col gap-3 p-4">
              {messages.isLoading ? (
                <Spinner />
              ) : (
                (messages.data ?? []).map((m) => {
                  const sender = userMap.get(m.sender_id);
                  const isStaff =
                    m.sender_type === "agent" || m.sender_type === "admin";
                  return (
                    <div
                      key={m.id}
                      className={cn(
                        "rounded-lg border px-3.5 py-2.5",
                        m.is_internal
                          ? "border-st-progress/30 bg-st-progress-wash"
                          : isStaff
                            ? "border-brand/20 bg-brand-wash"
                            : "border-border bg-surface-2",
                      )}
                    >
                      <div className="mb-1 flex items-center gap-2 text-[11.5px]">
                        <Avatar name={sender?.name ?? m.sender_type} size={18} />
                        <span className="font-medium text-ink">
                          {sender?.name ?? titleCase(m.sender_type)}
                        </span>
                        {m.is_internal && (
                          <span className="inline-flex items-center gap-1 rounded bg-st-progress/15 px-1.5 py-0.5 text-[10px] font-medium text-st-progress">
                            <Lock size={9} /> Internal note
                          </span>
                        )}
                        <span className="ml-auto text-ink-faint">
                          {dateTime(m.created_at)}
                        </span>
                      </div>
                      <p className="whitespace-pre-wrap text-[13px] text-ink">
                        {m.content}
                      </p>
                    </div>
                  );
                })
              )}
              {messages.data?.length === 0 && (
                <p className="py-6 text-center text-[12.5px] text-ink-faint">
                  No messages on this ticket yet.
                </p>
              )}
            </div>
          </Panel>

          {/* composer */}
          <Panel>
            <div className="flex border-b border-border">
              <button
                onClick={() => setMode("reply")}
                className={cn(
                  "flex items-center gap-1.5 px-4 py-2.5 text-[12.5px] font-medium",
                  mode === "reply"
                    ? "border-b-2 border-brand text-ink"
                    : "text-ink-faint hover:text-ink",
                )}
              >
                <Send size={13} /> Reply to customer
              </button>
              <button
                onClick={() => setMode("note")}
                className={cn(
                  "flex items-center gap-1.5 px-4 py-2.5 text-[12.5px] font-medium",
                  mode === "note"
                    ? "border-b-2 border-st-progress text-ink"
                    : "text-ink-faint hover:text-ink",
                )}
              >
                <StickyNote size={13} /> Internal note
              </button>
            </div>
            <div className="p-4">
              <Textarea
                rows={4}
                value={mode === "reply" ? draft : noteDraft}
                onChange={(e) =>
                  mode === "reply"
                    ? setDraft(e.target.value)
                    : setNoteDraft(e.target.value)
                }
                placeholder={
                  mode === "reply"
                    ? "Write a reply the customer will see…"
                    : "Add a note only the support team can see…"
                }
              />
              <div className="mt-2.5 flex justify-end">
                <Button
                  variant="primary"
                  onClick={submit}
                  loading={reply.isPending || note.isPending}
                >
                  {mode === "reply" ? "Send reply" : "Add note"}
                </Button>
              </div>
            </div>
          </Panel>
        </div>

        {/* sidebar */}
        <div className="flex flex-col gap-3">
          <Panel className="p-4">
            <div className="flex flex-wrap items-center gap-2">
              <StatusBadge status={t.status} />
              <PriorityBadge priority={t.priority} />
            </div>
            <div className="mt-4 flex flex-col gap-3">
              <Field label="Status">
                <Select
                  value={t.status}
                  onChange={(e) => patch("status", e.target.value as TicketStatus)}
                >
                  {STATUS_ORDER.map((s) => (
                    <option key={s} value={s}>
                      {STATUS_LABEL[s]}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label="Priority">
                <Select
                  value={t.priority}
                  onChange={(e) =>
                    patch("priority", e.target.value as TicketPriority)
                  }
                >
                  {PRIORITY_ORDER.map((p) => (
                    <option key={p} value={p}>
                      {PRIORITY_LABEL[p]}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label="Assigned agent">
                <Select
                  value={t.assigned_agent_id ?? ""}
                  onChange={(e) => patch("assigned_agent_id", e.target.value)}
                >
                  <option value="">Unassigned</option>
                  {agents.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.name}
                    </option>
                  ))}
                </Select>
              </Field>
            </div>
          </Panel>

          <Panel className="p-4">
            <p className="text-[11px] font-medium uppercase tracking-wide text-ink-faint">
              Customer
            </p>
            {customer ? (
              <div className="mt-2 flex items-center gap-2.5">
                <Avatar name={customer.name} size={34} />
                <div className="min-w-0">
                  <p className="truncate text-[13px] font-medium text-ink">
                    {customer.name}
                  </p>
                  <p className="truncate text-[11.5px] text-ink-faint">
                    {customer.email}
                  </p>
                </div>
              </div>
            ) : (
              <p className="mt-2 text-[12.5px] text-ink-faint">
                Customer #{t.customer_id}
              </p>
            )}
            {customer && (
              <Link
                href={`/customers/${customer.id}`}
                className="mt-3 inline-block text-[12px] font-medium text-brand hover:underline"
              >
                View customer →
              </Link>
            )}
          </Panel>
        </div>
      </div>
    </>
  );
}
