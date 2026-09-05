"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Search, Inbox } from "lucide-react";
import { useTickets, useUserMap } from "@/lib/queries";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  Select,
  Input,
  Spinner,
  ErrorState,
  EmptyState,
  StatusBadge,
  PriorityBadge,
  Avatar,
} from "@/components/ui";
import {
  STATUS_LABEL,
  STATUS_ORDER,
  PRIORITY_LABEL,
  PRIORITY_ORDER,
  ticketNo,
  titleCase,
  relativeTime,
} from "@/lib/format";
import type { TicketPriority, TicketStatus } from "@/lib/types";

export default function TicketsPage() {
  const { data, isLoading, isError, error } = useTickets();
  const userMap = useUserMap();

  const [q, setQ] = useState("");
  const [status, setStatus] = useState<TicketStatus | "">("");
  const [priority, setPriority] = useState<TicketPriority | "">("");
  const [assignee, setAssignee] = useState<string>("");

  const categories = useMemo(
    () => [...new Set((data ?? []).map((t) => t.category))].sort(),
    [data],
  );
  const [category, setCategory] = useState("");

  const rows = useMemo(() => {
    let list = data ?? [];
    if (status) list = list.filter((t) => t.status === status);
    if (priority) list = list.filter((t) => t.priority === priority);
    if (category) list = list.filter((t) => t.category === category);
    if (assignee === "unassigned")
      list = list.filter((t) => t.assigned_agent_id == null);
    else if (assignee)
      list = list.filter((t) => String(t.assigned_agent_id) === assignee);
    if (q.trim()) {
      const needle = q.toLowerCase();
      list = list.filter(
        (t) =>
          t.subject.toLowerCase().includes(needle) ||
          t.description.toLowerCase().includes(needle) ||
          ticketNo(t.id).toLowerCase().includes(needle),
      );
    }
    return [...list].sort(
      (a, b) => +new Date(b.updated_at) - +new Date(a.updated_at),
    );
  }, [data, status, priority, category, assignee, q]);

  const agents = [...userMap.values()].filter(
    (u) => u.role === "agent" || u.role === "admin",
  );

  return (
    <>
      <PageHeader
        title="Tickets"
        subtitle={
          data ? `${rows.length} of ${data.length} shown` : "Support queue"
        }
      />

      <Panel className="mb-3 flex flex-wrap items-center gap-2 p-3">
        <div className="relative min-w-[200px] flex-1">
          <Search
            size={15}
            className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-ink-faint"
          />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search subject, description, ID…"
            className="pl-8"
          />
        </div>
        <Select
          value={status}
          onChange={(e) => setStatus(e.target.value as TicketStatus | "")}
          className="w-[150px] shrink-0"
        >
          <option value="">All statuses</option>
          {STATUS_ORDER.map((s) => (
            <option key={s} value={s}>
              {STATUS_LABEL[s]}
            </option>
          ))}
        </Select>
        <Select
          value={priority}
          onChange={(e) => setPriority(e.target.value as TicketPriority | "")}
          className="w-[140px] shrink-0"
        >
          <option value="">All priorities</option>
          {PRIORITY_ORDER.map((p) => (
            <option key={p} value={p}>
              {PRIORITY_LABEL[p]}
            </option>
          ))}
        </Select>
        <Select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="w-[150px] shrink-0"
        >
          <option value="">All categories</option>
          {categories.map((c) => (
            <option key={c} value={c}>
              {titleCase(c)}
            </option>
          ))}
        </Select>
        <Select
          value={assignee}
          onChange={(e) => setAssignee(e.target.value)}
          className="w-[150px] shrink-0"
        >
          <option value="">Any assignee</option>
          <option value="unassigned">Unassigned</option>
          {agents.map((a) => (
            <option key={a.id} value={String(a.id)}>
              {a.name}
            </option>
          ))}
        </Select>
      </Panel>

      <Panel className="overflow-hidden">
        {isLoading ? (
          <Spinner />
        ) : isError ? (
          <ErrorState message={(error as Error).message} />
        ) : rows.length === 0 ? (
          <EmptyState
            icon={<Inbox size={22} />}
            title="No tickets match"
            body="Try clearing a filter or adjusting your search."
          />
        ) : (
          <div className="overflow-x-auto scroll-thin">
            <table className="w-full min-w-[720px] text-[13px]">
              <thead>
                <tr className="border-b border-border text-left text-[11px] uppercase tracking-wide text-ink-faint">
                  <th className="px-4 py-2.5 font-medium">ID</th>
                  <th className="px-3 py-2.5 font-medium">Subject</th>
                  <th className="px-3 py-2.5 font-medium">Customer</th>
                  <th className="px-3 py-2.5 font-medium">Priority</th>
                  <th className="px-3 py-2.5 font-medium">Status</th>
                  <th className="px-3 py-2.5 font-medium">Assignee</th>
                  <th className="px-4 py-2.5 text-right font-medium">Updated</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {rows.map((t) => {
                  const customer = userMap.get(t.customer_id);
                  const agent = t.assigned_agent_id
                    ? userMap.get(t.assigned_agent_id)
                    : null;
                  return (
                    <tr
                      key={t.id}
                      className="group relative cursor-pointer transition-colors hover:bg-surface-2"
                    >
                      <td className="px-4 py-2.5">
                        <Link
                          href={`/tickets/${t.id}`}
                          aria-label={`Open ticket ${ticketNo(t.id)}: ${t.subject}`}
                          className="font-mono text-[11.5px] text-ink-faint after:absolute after:inset-0 after:content-[''] group-hover:text-brand"
                        >
                          {ticketNo(t.id)}
                        </Link>
                      </td>
                      <td className="max-w-[260px] px-3 py-2.5">
                        <span className="block truncate text-ink group-hover:text-brand">
                          {t.subject}
                        </span>
                        <span className="text-[11px] text-ink-faint">
                          {titleCase(t.category)}
                          {t.conversation_id && (
                            <span className="ml-2 font-sans font-medium text-brand">
                              · Chat #{t.conversation_id}
                            </span>
                          )}
                        </span>
                      </td>
                      <td className="px-3 py-2.5 text-ink-soft">
                        {customer?.name ?? `#${t.customer_id}`}
                      </td>
                      <td className="px-3 py-2.5">
                        <PriorityBadge priority={t.priority} />
                      </td>
                      <td className="px-3 py-2.5">
                        <StatusBadge status={t.status} />
                      </td>
                      <td className="px-3 py-2.5">
                        {agent ? (
                          <span className="flex items-center gap-1.5 text-ink-soft">
                            <Avatar name={agent.name} size={20} />
                            <span className="text-[12px]">{agent.name}</span>
                          </span>
                        ) : (
                          <span className="text-[12px] text-ink-faint">
                            Unassigned
                          </span>
                        )}
                      </td>
                      <td className="tnum px-4 py-2.5 text-right text-[11.5px] text-ink-faint">
                        {relativeTime(t.updated_at)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
    </>
  );
}
