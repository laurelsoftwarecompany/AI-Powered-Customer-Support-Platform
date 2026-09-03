"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Search, Users } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { useTickets, useConversations } from "@/lib/queries";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  Input,
  Spinner,
  ErrorState,
  EmptyState,
  Avatar,
  cn,
} from "@/components/ui";
import { dateTime } from "@/lib/format";
import type { User } from "@/lib/types";

export default function CustomersPage() {
  const customers = useQuery({
    queryKey: ["directory", "customers"],
    queryFn: () => api.get<User[]>("/users/directory?role=customer"),
    staleTime: 60_000,
  });
  const tickets = useTickets();
  const conversations = useConversations();
  const [q, setQ] = useState("");

  const ticketsByCustomer = useMemo(() => {
    const m = new Map<number, number>();
    (tickets.data ?? []).forEach((t) =>
      m.set(t.customer_id, (m.get(t.customer_id) ?? 0) + 1),
    );
    return m;
  }, [tickets.data]);

  const convsByCustomer = useMemo(() => {
    const m = new Map<number, number>();
    (conversations.data ?? []).forEach((c) =>
      m.set(c.customer_id, (m.get(c.customer_id) ?? 0) + 1),
    );
    return m;
  }, [conversations.data]);

  const rows = useMemo(() => {
    let list = customers.data ?? [];
    if (q.trim()) {
      const needle = q.toLowerCase();
      list = list.filter(
        (u) =>
          u.name.toLowerCase().includes(needle) ||
          u.email.toLowerCase().includes(needle),
      );
    }
    return [...list].sort((a, b) => a.name.localeCompare(b.name));
  }, [customers.data, q]);

  return (
    <>
      <PageHeader
        title="Customers"
        subtitle={customers.data ? `${customers.data.length} total` : "Directory"}
      />

      <Panel className="mb-3 p-3">
        <div className="relative">
          <Search
            size={15}
            className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-ink-faint"
          />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search by name or email…"
            className="pl-8"
          />
        </div>
      </Panel>

      <Panel className="overflow-hidden">
        {customers.isLoading ? (
          <Spinner />
        ) : customers.isError ? (
          <ErrorState message={(customers.error as Error).message} />
        ) : rows.length === 0 ? (
          <EmptyState icon={<Users size={22} />} title="No customers found" />
        ) : (
          <div className="overflow-x-auto scroll-thin">
            <table className="w-full min-w-[640px] text-[13px]">
              <thead>
                <tr className="border-b border-border text-left text-[11px] uppercase tracking-wide text-ink-faint">
                  <th className="px-4 py-2.5 font-medium">Name</th>
                  <th className="px-3 py-2.5 font-medium">Email</th>
                  <th className="px-3 py-2.5 text-right font-medium">Tickets</th>
                  <th className="px-3 py-2.5 text-right font-medium">Chats</th>
                  <th className="px-3 py-2.5 font-medium">Joined</th>
                  <th className="px-4 py-2.5 font-medium">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {rows.map((u) => (
                  <tr
                    key={u.id}
                    className="group relative cursor-pointer transition-colors hover:bg-surface-2"
                  >
                    <td className="px-4 py-2.5">
                      <Link
                        href={`/customers/${u.id}`}
                        aria-label={`Open ${u.name}'s profile`}
                        className="flex items-center gap-2.5 after:absolute after:inset-0 after:content-['']"
                      >
                        <Avatar name={u.name} size={26} />
                        <span className="font-medium text-ink group-hover:text-brand">
                          {u.name}
                        </span>
                      </Link>
                    </td>
                    <td className="px-3 py-2.5 text-ink-soft">{u.email}</td>
                    <td className="tnum px-3 py-2.5 text-right text-ink-soft">
                      {ticketsByCustomer.get(u.id) ?? 0}
                    </td>
                    <td className="tnum px-3 py-2.5 text-right text-ink-soft">
                      {convsByCustomer.get(u.id) ?? 0}
                    </td>
                    <td className="px-3 py-2.5 text-ink-faint">
                      {u.created_at ? dateTime(u.created_at).split(",")[0] : "—"}
                    </td>
                    <td className="px-4 py-2.5">
                      <span
                        className={cn(
                          "inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] font-medium",
                          u.is_active
                            ? "bg-st-resolved-wash text-st-resolved"
                            : "bg-st-closed-wash text-st-closed",
                        )}
                      >
                        <span className="size-1.5 rounded-full bg-current" />
                        {u.is_active ? "Active" : "Inactive"}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
    </>
  );
}
