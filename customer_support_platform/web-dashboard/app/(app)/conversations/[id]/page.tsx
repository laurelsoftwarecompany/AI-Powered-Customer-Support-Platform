"use client";

import { use, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { ArrowLeft, Bot, FileText, Headphones, Send, Sparkles } from "lucide-react";
import {
  useConversation,
  useConversationMessages,
  useTakeoverConversation,
  useSendConversationMessage,
  useUserMap,
} from "@/lib/queries";
import { useToast } from "@/components/toast";
import { useWebSocket } from "@/lib/useWebSocket";
import type { WsEvent } from "@/lib/useWebSocket";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  Button,
  Textarea,
  Spinner,
  DetailSkeleton,
  ErrorState,
  Avatar,
  cn,
} from "@/components/ui";
import { convNo, dateTime, pct, titleCase } from "@/lib/format";
import type { MessageSource } from "@/lib/types";

// Retrieval returns several chunks per document; show each document once,
// keeping its best-scoring chunk.
function dedupeSources(sources: MessageSource[]): MessageSource[] {
  const best = new Map<number, MessageSource>();
  for (const s of sources) {
    const seen = best.get(s.document_id);
    if (!seen || s.score > seen.score) best.set(s.document_id, s);
  }
  return [...best.values()].sort((a, b) => b.score - a.score);
}

export default function ConversationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: idParam } = use(params);
  const id = Number(idParam);
  const { notify } = useToast();

  const conv = useConversation(id);
  const messages = useConversationMessages(id);
  const userMap = useUserMap();
  const takeover = useTakeoverConversation(id);
  const handback = useHandbackConversation(id);
  const send = useSendConversationMessage(id);
  const [draft, setDraft] = useState("");
  const qc = useQueryClient();

  // WebSocket: live updates for this conversation
  useWebSocket(
    Number.isFinite(id) ? `/ws/conversations/${id}` : null,
    (event: WsEvent) => {
      if (event.event === "new_message") {
        qc.invalidateQueries({ queryKey: ["conversation", id, "messages"] });
        qc.invalidateQueries({ queryKey: ["conversation", id] });
      } else if (event.event === "status_change") {
        qc.invalidateQueries({ queryKey: ["conversation", id] });
        qc.invalidateQueries({ queryKey: ["conversations"] });
      }
    },
  );

  if (conv.isLoading) return <DetailSkeleton />;
  if (conv.isError) return <ErrorState message={(conv.error as Error).message} />;
  const c = conv.data!;
  const customer = userMap.get(c.customer_id);

  async function onTakeover() {
    try {
      await takeover.mutateAsync();
      notify("You've taken over this conversation from the AI.");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  async function onHandback() {
    try {
      await handback.mutateAsync();
      notify("Conversation returned to AI assistant.");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  async function onSend() {
    if (!draft.trim()) return;
    try {
      await send.mutateAsync(draft.trim());
      setDraft("");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  return (
    <>
      <Link
        href="/conversations"
        className="mb-3 inline-flex items-center gap-1 text-[12.5px] text-ink-faint hover:text-ink"
      >
        <ArrowLeft size={14} /> Back to conversations
      </Link>

      <PageHeader
        title={customer?.name ?? `Customer #${c.customer_id}`}
        subtitle={`${convNo(c.id)} · started ${dateTime(c.created_at)}`}
        actions={
          <div className="flex items-center gap-2">
            {c.ticket_id && (
              <Link
                href={`/tickets/${c.ticket_id}`}
                className="inline-flex items-center gap-1 rounded-md border border-brand/30 bg-brand-wash px-2.5 py-1 text-[12px] font-medium text-brand hover:bg-brand/15"
              >
                Linked Ticket TCK-{String(c.ticket_id).padStart(5, "0")} →
              </Link>
            )}
            <span
              className={cn(
                "inline-flex items-center gap-1.5 rounded-md px-2.5 py-1 text-[12px] font-medium",
                c.ai_active
                  ? "bg-brand-wash text-brand"
                  : "bg-st-waiting-wash text-st-waiting",
              )}
            >
              {c.ai_active ? <Bot size={13} /> : <Headphones size={13} />}
              {c.ai_active ? "AI handling" : "Agent handling"}
            </span>
          </div>
        }
      />

      <div className="mx-auto max-w-[760px]">
        {c.ai_active ? (
          <div className="mb-3 flex items-center justify-between gap-3 rounded-lg border border-brand/25 bg-brand-wash px-4 py-3">
            <p className="text-[12.5px] text-ink">
              The AI assistant is handling this conversation. You can monitor the chat in real-time or take over whenever you wish.
            </p>
            <Button variant="primary" onClick={onTakeover} loading={takeover.isPending}>
              Take over
            </Button>
          </div>
        ) : (
          <div className="mb-3 flex items-center justify-between gap-3 rounded-lg border border-emerald-500/25 bg-emerald-500/10 px-4 py-3">
            <div className="flex items-center gap-2 text-ink text-[12.5px]">
              <span className="flex size-2 rounded-full bg-emerald-500" />
              <span className="font-semibold text-emerald-700 dark:text-emerald-300">
                You are in control:
              </span>
              <span>Replies are delivered live to customer mobile app.</span>
            </div>
            <Button
              variant="outline"
              onClick={onHandback}
              loading={handback.isPending}
              className="text-[12px]"
            >
              <Bot size={13} className="mr-1.5" />
              Hand back to AI
            </Button>
          </div>
        )}

        <Panel className="flex flex-col">
          <div className="flex flex-col gap-3 p-4">
            {messages.isLoading ? (
              <Spinner />
            ) : (
              (messages.data ?? []).map((m) => {
                const mine = m.sender_type === "agent" || m.sender_type === "admin";
                const isAI = m.sender_type === "ai";
                const sender =
                  m.sender_name ??
                  (m.sender_type === "customer"
                    ? (customer?.name ?? "Customer")
                    : isAI
                      ? "Laurel AI Assistant"
                      : "Support Specialist");
                return (
                  <div
                    key={m.id}
                    className={cn(
                      "flex flex-col gap-1",
                      mine ? "items-end" : "items-start",
                    )}
                  >
                    <div
                      className={cn(
                        "max-w-[78%] rounded-2xl px-3.5 py-2 text-[13px]",
                        m.sender_type === "customer" &&
                          "rounded-bl-sm bg-surface-2 text-ink",
                        isAI && "rounded-bl-sm bg-brand-wash text-ink",
                        mine && "rounded-br-sm bg-brand text-brand-ink",
                      )}
                    >
                      <p className="whitespace-pre-wrap">{m.content}</p>
                    </div>
                    <div className="flex items-center gap-1.5 px-1 text-[10.5px] text-ink-faint">
                      {isAI && <Sparkles size={10} />}
                      <span>{sender}</span>
                      <span>·</span>
                      <span>{dateTime(m.created_at)}</span>
                      {isAI && m.intent && (
                        <>
                          <span>·</span>
                          <span className="rounded bg-surface-2 px-1 py-px font-medium">
                            {titleCase(m.intent)}
                          </span>
                        </>
                      )}
                      {isAI && m.confidence != null && (
                        <span
                          className={cn(
                            "rounded px-1 py-px font-medium",
                            m.confidence < 0.7
                              ? "bg-st-progress-wash text-st-progress"
                              : "bg-st-resolved-wash text-st-resolved",
                          )}
                        >
                          {pct(m.confidence)} confident
                        </span>
                      )}
                    </div>

                    {isAI && m.sources && m.sources.length > 0 && (
                      <div className="flex max-w-[78%] flex-wrap gap-1 px-1 pt-0.5">
                        <span className="text-[10px] uppercase tracking-wide text-ink-faint">
                          Sources
                        </span>
                        {dedupeSources(m.sources).map((s) => (
                          <span
                            key={s.document_id}
                            title={`${s.snippet}\n\nrelevance ${pct(s.score)}`}
                            className="inline-flex items-center gap-1 rounded bg-surface-2 px-1.5 py-0.5 text-[10.5px] text-ink-soft"
                          >
                            <FileText size={9} />
                            {s.title}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>

          {!c.ai_active && (
            <div className="border-t border-border p-4">
              <div className="mb-2 flex items-center justify-between text-[11px] text-ink-faint">
                <span>
                  {c.ticket_id
                    ? `Replies deliver live to customer app & mirror to Ticket #${c.ticket_id}`
                    : "Replies deliver live to the customer's mobile app"}
                </span>
                {c.ticket_id && (
                  <Link
                    href={`/tickets/${c.ticket_id}`}
                    className="text-brand hover:underline font-medium"
                  >
                    Open Ticket View →
                  </Link>
                )}
              </div>
              <Textarea
                rows={3}
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                placeholder="Reply to the customer…"
              />
              <div className="mt-2 flex justify-end">
                <Button variant="primary" onClick={onSend} loading={send.isPending}>
                  <Send size={13} /> Send
                </Button>
              </div>
            </div>
          )}
        </Panel>
      </div>
    </>
  );
}
