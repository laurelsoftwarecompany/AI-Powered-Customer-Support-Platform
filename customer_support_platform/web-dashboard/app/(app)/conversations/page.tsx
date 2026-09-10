"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Bot, Headphones, MessagesSquare } from "lucide-react";
import { useConversations, useUserMap } from "@/lib/queries";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  Spinner,
  ErrorState,
  EmptyState,
  Avatar,
  TableSkeleton,
  cn,
} from "@/components/ui";
import { convNo, relativeTime } from "@/lib/format";

type Filter = "all" | "ask_ai" | "tickets" | "ai" | "human";

export default function ConversationsPage() {
  const { data, isLoading, isError, error } = useConversations();
  const userMap = useUserMap();
  const [filter, setFilter] = useState<Filter>("all");

  const rows = useMemo(() => {
    let list = data ?? [];
    if (filter === "ask_ai") list = list.filter((c) => !c.ticket_id);
    if (filter === "tickets") list = list.filter((c) => !!c.ticket_id);
    if (filter === "ai") list = list.filter((c) => c.ai_active);
    if (filter === "human") list = list.filter((c) => !c.ai_active);
    return [...list].sort(
      (a, b) => +new Date(b.updated_at) - +new Date(a.updated_at),
    );
  }, [data, filter]);

  const askAiCount = (data ?? []).filter((c) => !c.ticket_id).length;
  const ticketCount = (data ?? []).filter((c) => !!c.ticket_id).length;
  const aiCount = (data ?? []).filter((c) => c.ai_active).length;
  const humanCount = (data ?? []).filter((c) => !c.ai_active).length;

  const tabs: { key: Filter; label: string; count: number }[] = [
    { key: "all", label: "All", count: data?.length ?? 0 },
    { key: "ask_ai", label: "Ask AI (General)", count: askAiCount },
    { key: "tickets", label: "Ticket Live Chats", count: ticketCount },
    { key: "ai", label: "With AI", count: aiCount },
    { key: "human", label: "With Agent", count: humanCount },
  ];

  return (
    <>
      <PageHeader title="Conversations" subtitle="Customer chats with the AI assistant and support team" />

      <div className="mb-3 flex flex-wrap gap-1">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setFilter(t.key)}
            className={cn(
              "rounded-md px-3 py-1.5 text-[12.5px] font-medium transition-colors",
              filter === t.key
                ? "bg-brand-wash text-brand"
                : "text-ink-soft hover:bg-surface-2",
            )}
          >
            {t.label}{" "}
            <span className="tnum text-ink-faint">({t.count})</span>
          </button>
        ))}
      </div>

      <Panel className="overflow-hidden">
        {isLoading ? (
          <TableSkeleton rows={6} />
        ) : isError ? (
          <ErrorState message={(error as Error).message} />
        ) : rows.length === 0 ? (
          <EmptyState
            icon={<MessagesSquare size={22} />}
            title="No conversations"
            body="Conversations appear here when customers chat with the AI assistant."
          />
        ) : (
          <div className="divide-y divide-border">
            {rows.map((c) => {
              const customer = userMap.get(c.customer_id);
              const isTicketChat = !!c.ticket_id;

              return (
                <Link
                  key={c.id}
                  href={`/conversations/${c.id}`}
                  className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-surface-2"
                >
                  <Avatar name={customer?.name ?? "?"} size={32} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="truncate text-[13px] font-medium text-ink">
                        {customer?.name ?? `Customer #${c.customer_id}`}
                      </p>
                      {isTicketChat ? (
                        <span className="inline-flex items-center rounded border border-brand/30 bg-brand-wash px-1.5 py-0.5 font-mono text-[10.5px] font-medium text-brand">
                          TCK-{String(c.ticket_id).padStart(5, "0")}
                        </span>
                      ) : (
                        <span className="inline-flex items-center rounded border border-purple-500/30 bg-purple-50 px-1.5 py-0.5 text-[10.5px] font-medium text-purple-700 dark:bg-purple-950/30 dark:text-purple-300">
                          Ask AI
                        </span>
                      )}
                    </div>
                    <p className="font-mono text-[11px] text-ink-faint">
                      {convNo(c.id)}
                      {isTicketChat && (
                        <span className="ml-2 font-sans font-normal text-ink-faint">
                          · Linked Live Support Chat
                        </span>
                      )}
                    </p>
                  </div>
                  <span
                    className={cn(
                      "inline-flex items-center gap-1 rounded-md px-2 py-0.5 text-[11px] font-medium",
                      c.ai_active
                        ? "bg-brand-wash text-brand"
                        : "bg-emerald-50 text-emerald-700 dark:bg-emerald-950/30 dark:text-emerald-300",
                    )}
                  >
                    {c.ai_active ? <Bot size={11} /> : <Headphones size={11} />}
                    {c.ai_active ? (isTicketChat ? "AI First Responder" : "AI handling") : "Agent handling"}
                  </span>
                  <span className="tnum hidden w-[64px] shrink-0 text-right text-[11px] text-ink-faint sm:block">
                    {relativeTime(c.updated_at)}
                  </span>
                </Link>
              );
            })}
          </div>
        )}
      </Panel>
    </>
  );
}
