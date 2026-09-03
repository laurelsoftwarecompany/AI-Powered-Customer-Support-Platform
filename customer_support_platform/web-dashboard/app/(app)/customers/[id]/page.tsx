"use client";

import { use, useMemo } from "react";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { useTickets, useConversations, useDirectory } from "@/lib/queries";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  PanelHeader,
  DetailSkeleton,
  ErrorState,
  Avatar,
  StatusBadge,
  PriorityBadge,
  cn,
} from "@/components/ui";
import { ticketNo, convNo, dateTime, relativeTime, titleCase } from "@/lib/format";

export default function CustomerDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: idParam } = use(params);
  const id = Number(idParam);

  const directory = useDirectory();
  const tickets = useTickets();
  const conversations = useConversations();

  const customer = (directory.data ?? []).find((u) => u.id === id);

  const theirTickets = useMemo(
    () =>
      (tickets.data ?? [])
        .filter((t) => t.customer_id === id)
        .sort((a, b) => +new Date(b.updated_at) - +new Date(a.updated_at)),
    [tickets.data, id],
  );
  const theirConvs = useMemo(
    () =>
      (conversations.data ?? [])
        .filter((c) => c.customer_id === id)
        .sort((a, b) => +new Date(b.updated_at) - +new Date(a.updated_at)),
    [conversations.data, id],
  );

  const activity = useMemo(() => {
    const items: { when: string; text: string; href?: string }[] = [];
    theirTickets.forEach((t) =>
      items.push({
        when: t.created_at,
        text: `Opened ticket ${ticketNo(t.id)} — ${t.subject}`,
        href: `/tickets/${t.id}`,
      }),
    );
    theirConvs.forEach((c) =>
      items.push({
        when: c.created_at,
        text: `Started conversation ${convNo(c.id)}`,
        href: `/conversations/${c.id}`,
      }),
    );
    return items.sort((a, b) => +new Date(b.when) - +new Date(a.when)).slice(0, 12);
  }, [theirTickets, theirConvs]);

  if (directory.isLoading) return <DetailSkeleton />;
  if (directory.isError)
    return <ErrorState message={(directory.error as Error).message} />;
  if (!customer)
    return <ErrorState message="Customer not found in the directory." />;

  return (
    <>
      <Link
        href="/customers"
        className="mb-3 inline-flex items-center gap-1 text-[12.5px] text-ink-faint hover:text-ink"
      >
        <ArrowLeft size={14} /> Back to customers
      </Link>

      <PageHeader title={customer.name} subtitle={customer.email} />

      <div className="grid gap-4 lg:grid-cols-[1fr_300px]">
        <div className="flex flex-col gap-3">
          <Panel>
            <PanelHeader
              title="Tickets"
              subtitle={`${theirTickets.length} total`}
            />
            <div className="divide-y divide-border">
              {theirTickets.map((t) => (
                <Link
                  key={t.id}
                  href={`/tickets/${t.id}`}
                  className="flex items-center gap-3 px-4 py-2.5 hover:bg-surface-2"
                >
                  <span className="w-[76px] shrink-0 font-mono text-[11.5px] text-ink-faint">
                    {ticketNo(t.id)}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-[13px] text-ink">
                    {t.subject}
                  </span>
                  <PriorityBadge priority={t.priority} />
                  <StatusBadge status={t.status} />
                </Link>
              ))}
              {theirTickets.length === 0 && (
                <p className="px-4 py-6 text-center text-[12.5px] text-ink-faint">
                  No tickets from this customer.
                </p>
              )}
            </div>
          </Panel>

          <Panel>
            <PanelHeader
              title="Conversations"
              subtitle={`${theirConvs.length} total`}
            />
            <div className="divide-y divide-border">
              {theirConvs.map((c) => (
                <Link
                  key={c.id}
                  href={`/conversations/${c.id}`}
                  className="flex items-center gap-3 px-4 py-2.5 hover:bg-surface-2"
                >
                  <span className="w-[76px] shrink-0 font-mono text-[11.5px] text-ink-faint">
                    {convNo(c.id)}
                  </span>
                  <span
                    className={cn(
                      "rounded-md px-1.5 py-0.5 text-[11px] font-medium",
                      c.ai_active
                        ? "bg-brand-wash text-brand"
                        : "bg-st-waiting-wash text-st-waiting",
                    )}
                  >
                    {c.ai_active ? "AI handling" : "Agent handling"}
                  </span>
                  <span className="ml-auto text-[11px] text-ink-faint">
                    {relativeTime(c.updated_at)}
                  </span>
                </Link>
              ))}
              {theirConvs.length === 0 && (
                <p className="px-4 py-6 text-center text-[12.5px] text-ink-faint">
                  No conversations from this customer.
                </p>
              )}
            </div>
          </Panel>
        </div>

        <div className="flex flex-col gap-3">
          <Panel className="p-4">
            <div className="flex items-center gap-3">
              <Avatar name={customer.name} size={40} />
              <div className="min-w-0">
                <p className="truncate text-[14px] font-semibold text-ink">
                  {customer.name}
                </p>
                <span
                  className={cn(
                    "mt-0.5 inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[11px] font-medium",
                    customer.is_active
                      ? "bg-st-resolved-wash text-st-resolved"
                      : "bg-st-closed-wash text-st-closed",
                  )}
                >
                  {customer.is_active ? "Active" : "Inactive"}
                </span>
              </div>
            </div>
            <dl className="mt-4 flex flex-col gap-2 text-[12.5px]">
              <div className="flex justify-between">
                <dt className="text-ink-faint">Email</dt>
                <dd className="text-ink">{customer.email}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-ink-faint">Role</dt>
                <dd className="text-ink">{titleCase(customer.role)}</dd>
              </div>
              {customer.created_at && (
                <div className="flex justify-between">
                  <dt className="text-ink-faint">Joined</dt>
                  <dd className="text-ink">
                    {dateTime(customer.created_at).split(",")[0]}
                  </dd>
                </div>
              )}
              <div className="flex justify-between">
                <dt className="text-ink-faint">Tickets</dt>
                <dd className="tnum text-ink">{theirTickets.length}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-ink-faint">Conversations</dt>
                <dd className="tnum text-ink">{theirConvs.length}</dd>
              </div>
            </dl>
          </Panel>

          <Panel>
            <PanelHeader title="Activity" />
            <ul className="flex flex-col gap-3 p-4">
              {activity.map((a, i) => (
                <li key={i} className="flex gap-2.5 text-[12px]">
                  <span className="mt-1 size-1.5 shrink-0 rounded-full bg-brand" />
                  <div>
                    {a.href ? (
                      <Link href={a.href} className="text-ink hover:text-brand">
                        {a.text}
                      </Link>
                    ) : (
                      <span className="text-ink">{a.text}</span>
                    )}
                    <span className="block text-[11px] text-ink-faint">
                      {relativeTime(a.when)}
                    </span>
                  </div>
                </li>
              ))}
              {activity.length === 0 && (
                <li className="text-[12px] text-ink-faint">No activity yet.</li>
              )}
            </ul>
          </Panel>
        </div>
      </div>
    </>
  );
}
