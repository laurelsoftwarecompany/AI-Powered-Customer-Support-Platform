"use client";

import { use, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { ArrowLeft, BookOpen, Bot, Headphones, Lock, Send, Sparkles, StickyNote } from "lucide-react";
import {
  useTicket,
  useTicketMessages,
  useUpdateTicket,
  useReplyToTicket,
  useAddInternalNote,
  useTakeoverTicket,
  useHandbackTicket,
  useConversation,
  useUserMap,
} from "@/lib/queries";
import { useToast } from "@/components/toast";
import { useWebSocket } from "@/lib/useWebSocket";
import type { WsEvent } from "@/lib/useWebSocket";
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
  const takeover = useTakeoverTicket(id);
  const handback = useHandbackTicket(id);

  const convId = ticket.data?.conversation_id;
  const conversation = useConversation(convId ?? 0);
  const isAiActive = conversation.data?.ai_active ?? false;

  const [draft, setDraft] = useState("");
  const [noteDraft, setNoteDraft] = useState("");
  const [mode, setMode] = useState<"reply" | "note">("reply");
  const qc = useQueryClient();

  // WebSocket: live updates for this ticket
  useWebSocket(
    Number.isFinite(id) ? `/ws/tickets/${id}` : null,
    (event: WsEvent) => {
      if (event.event === "new_message") {
        qc.invalidateQueries({ queryKey: ["ticket", id, "messages"] });
        qc.invalidateQueries({ queryKey: ["ticket", id] });
        if (convId) {
          qc.invalidateQueries({ queryKey: ["conversation", convId, "messages"] });
        }
      } else if (event.event === "status_change") {
        qc.invalidateQueries({ queryKey: ["ticket", id] });
        qc.invalidateQueries({ queryKey: ["tickets"] });
        if (convId) {
          qc.invalidateQueries({ queryKey: ["conversation", convId] });
        }
      }
    },
  );

  if (ticket.isLoading) return <DetailSkeleton />;
  if (ticket.isError)
    return <ErrorState message={(ticket.error as Error).message} />;
  const t = ticket.data!;

  const customer = userMap.get(t.customer_id);
  const agents = [...userMap.values()].filter(
    (u) => u.role === "agent" || u.role === "admin",
  );

  async function handleTakeover() {
    try {
      await takeover.mutateAsync();
      notify("You have taken over this ticket live chat.");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  async function handleHandback() {
    try {
      await handback.mutateAsync();
      notify("Ticket chat returned to AI assistant.");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

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
        actions={
          t.conversation_id ? (
            <Link
              href={`/conversations/${t.conversation_id}`}
              className="inline-flex items-center gap-1 rounded-md border border-brand/30 bg-brand-wash px-2.5 py-1 text-[12px] font-medium text-brand hover:bg-brand/15"
            >
              Originated from Live Chat #{t.conversation_id} →
            </Link>
          ) : undefined
        }
      />

      <div className="grid gap-4 lg:grid-cols-[1fr_280px]">
        {/* thread */}
        <div className="flex flex-col gap-3">
          {t.conversation_id && (
            <div className="flex flex-col gap-2">
              {isAiActive ? (
                <div className="flex items-center justify-between gap-3 rounded-lg border border-brand/35 bg-brand-wash px-4 py-3">
                  <div className="flex items-center gap-2.5">
                    <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-brand/15 text-brand">
                      <Bot size={16} />
                    </span>
                    <div>
                      <p className="text-[12.5px] font-semibold text-ink">
                        AI First Responder Active
                      </p>
                      <p className="text-[11.5px] text-ink-faint">
                        The AI is handling responses on this ticket. Click "Take Over" or reply below to take over as human agent.
                      </p>
                    </div>
                  </div>
                  <Button
                    variant="primary"
                    onClick={handleTakeover}
                    loading={takeover.isPending}
                    className="shrink-0 text-[12px]"
                  >
                    Take Over Live Chat
                  </Button>
                </div>
              ) : (
                <div className="flex items-center justify-between gap-3 rounded-lg border border-emerald-500/30 bg-emerald-50/40 px-4 py-2.5 text-[12px] dark:bg-emerald-950/20">
                  <div className="flex items-center gap-2 text-ink">
                    <span className="flex size-2 rounded-full bg-emerald-500" />
                    <span className="font-semibold text-emerald-700 dark:text-emerald-300">
                      Live Agent Connected:
                    </span>
                    <span>Human support specialist has control of this ticket session.</span>
                  </div>
                  <div className="flex items-center gap-2.5 shrink-0">
                    <Button
                      variant="outline"
                      onClick={handleHandback}
                      loading={handback.isPending}
                      className="text-[11.5px] py-1 px-2.5 h-auto"
                    >
                      <Bot size={13} className="mr-1.5" />
                      Hand back to AI
                    </Button>
                    <Link
                      href={`/conversations/${t.conversation_id}`}
                      className="font-medium text-brand hover:underline text-[12px]"
                    >
                      View Live Chat #{t.conversation_id} →
                    </Link>
                  </div>
                </div>
              )}
            </div>
          )}
          <Panel>
            <PanelHeader title="Conversation" />
            <div className="flex flex-col gap-3 p-4">
              {messages.isLoading ? (
                <Spinner />
              ) : (
                (messages.data ?? []).map((m) => {
                  const isAi = m.sender_type === "ai";
                  const sender = userMap.get(m.sender_id);
                  const isStaff =
                    m.sender_type === "agent" || m.sender_type === "admin";
                  const senderName = isAi
                    ? "Laurel AI Assistant"
                    : sender?.name ?? titleCase(m.sender_type);

                  return (
                    <div
                      key={m.id}
                      className={cn(
                        "rounded-lg border px-3.5 py-2.5",
                        m.is_internal
                          ? "border-st-progress/30 bg-st-progress-wash"
                          : isAi
                            ? "border-brand/35 bg-brand-wash"
                            : isStaff
                              ? "border-emerald-500/25 bg-emerald-50/40 dark:bg-emerald-950/20"
                              : "border-border bg-surface-2",
                      )}
                    >
                      <div className="mb-1 flex items-center gap-2 text-[11.5px]">
                        {isAi ? (
                          <span className="flex size-[18px] items-center justify-center rounded-full bg-brand text-white">
                            <Bot size={11} />
                          </span>
                        ) : (
                          <Avatar name={senderName} size={18} />
                        )}
                        <span className="font-medium text-ink">
                          {senderName}
                        </span>
                        {isAi && (
                          <span className="inline-flex items-center gap-1 rounded bg-brand/15 px-1.5 py-0.5 text-[10px] font-semibold text-brand">
                            <Sparkles size={9} /> First Responder
                          </span>
                        )}
                        {isStaff && (
                          <span className="inline-flex items-center gap-1 rounded bg-emerald-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-emerald-600 dark:text-emerald-400">
                            <Headphones size={9} /> Support Agent
                          </span>
                        )}
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
                      {m.sources && m.sources.length > 0 && (
                        <div className="mt-2.5 flex flex-wrap items-center gap-1.5 border-t border-brand/15 pt-2 text-[11px] text-brand">
                          <BookOpen size={12} />
                          <span className="font-medium">KB Sources:</span>
                          {m.sources.map((s: { title: string }, idx: number) => (
                            <span
                              key={idx}
                              className="rounded bg-brand/10 px-1.5 py-0.5 font-mono text-[10px]"
                            >
                              {s.title}
                            </span>
                          ))}
                        </div>
                      )}
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
