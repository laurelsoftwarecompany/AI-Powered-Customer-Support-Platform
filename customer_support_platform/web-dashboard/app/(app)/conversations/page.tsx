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
  cn,
} from "@/components/ui";
import { convNo, relativeTime } from "@/lib/format";

type Filter = "all" | "ai" | "human";

export default function ConversationsPage() {
  const { data, isLoading, isError, error } = useConversations();
  const userMap = useUserMap();
  const [filter, setFilter] = useState<Filter>("all");

  const rows = useMemo(() => {
    let list = data ?? [];
    if (filter === "ai") list = list.filter((c) => c.ai_active);
    if (filter === "human") list = list.filter((c) => !c.ai_active);
    return [...list].sort(
      (a, b) => +new Date(b.updated_at) - +new Date(a.updated_at),
    );
  }, [data, filter]);

  const aiCount = (data ?? []).filter((c) => c.ai_active).length;
  const humanCount = (data ?? []).filter((c) => !c.ai_active).length;

  const tabs: { key: Filter; label: string; count: number }[] = [
    { key: "all", label: "All", count: data?.length ?? 0 },
    { key: "ai", label: "With AI", count: aiCount },
    { key: "human", label: "With an agent", count: humanCount },
  ];

  return (
    <>
      <PageHeader title="Conversations" subtitle="Customer chats with the AI assistant and support team" />

      <div className="mb-3 flex gap-1">
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
          <Spinner />
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
              return (
                <Link
                  key={c.id}
                  href={`/conversations/${c.id}`}
                  className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-surface-2"
                >
                  <Avatar name={customer?.name ?? "?"} size={32} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[13px] font-medium text-ink">
                      {customer?.name ?? `Customer #${c.customer_id}`}
                    </p>
                    <p className="font-mono text-[11px] text-ink-faint">
                      {convNo(c.id)}
                      {c.ticket_id && (
                        <span className="ml-2 font-sans font-medium text-brand">
                          · Ticket TCK-{String(c.ticket_id).padStart(5, "0")}
                        </span>
                      )}
                    </p>
                  </div>
                  <span
                    className={cn(
                      "inline-flex items-center gap-1 rounded-md px-2 py-0.5 text-[11px] font-medium",
                      c.ai_active
                        ? "bg-brand-wash text-brand"
                        : "bg-st-waiting-wash text-st-waiting",
                    )}
                  >
                    {c.ai_active ? <Bot size={11} /> : <Headphones size={11} />}
                    {c.ai_active ? "AI handling" : "Agent handling"}
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
