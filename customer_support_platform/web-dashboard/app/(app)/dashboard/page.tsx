"use client";

import Link from "next/link";
import { useMemo } from "react";
import dynamic from "next/dynamic";
import { Ticket as TicketIcon, MessagesSquare, Users, Bot } from "lucide-react";
import { useAuth } from "@/lib/auth";
import {
  useTickets,
  useConversations,
  useAiAnalytics,
  useUserMap,
} from "@/lib/queries";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  PanelHeader,
  Spinner,
  ErrorState,
  StatusBadge,
  PriorityBadge,
  DashboardSkeleton,
  ChartSkeleton,
  DonutSkeleton,
} from "@/components/ui";
import {
  STATUS_LABEL,
  STATUS_ORDER,
  ticketNo,
  titleCase,
  relativeTime,
} from "@/lib/format";
import type { TicketStatus } from "@/lib/types";

const CountBars = dynamic(
  () => import("@/components/count-bars").then((mod) => mod.CountBars),
  {
    ssr: false,
    loading: () => <ChartSkeleton />,
  },
);

const Donut = dynamic(
  () => import("@/components/count-bars").then((mod) => mod.Donut),
  {
    ssr: false,
    loading: () => <DonutSkeleton />,
  },
);

const STATUS_COLOR: Record<TicketStatus, string> = {
  open: "var(--st-open)",
  in_progress: "var(--st-progress)",
  waiting_for_customer: "var(--st-waiting)",
  resolved: "var(--st-resolved)",
  closed: "var(--st-closed)",
};

function StatTile({
  icon,
  label,
  value,
  hint,
}: {
  icon: React.ReactNode;
  label: string;
  value: string | number;
  hint?: string;
}) {
  return (
    <Panel className="p-4">
      <div className="flex items-center gap-2 text-ink-faint">
        {icon}
        <span className="text-[11.5px] font-medium uppercase tracking-wide">
          {label}
        </span>
      </div>
      <p className="tnum mt-2 text-[24px] font-semibold leading-none text-ink">
        {value}
      </p>
      {hint && <p className="mt-1.5 text-[11.5px] text-ink-faint">{hint}</p>}
    </Panel>
  );
}

export default function DashboardPage() {
  const { user } = useAuth();
  const tickets = useTickets();
  const conversations = useConversations();
  const analytics = useAiAnalytics(); // admin only; errors are ignored below
  const userMap = useUserMap();

  const t = tickets.data ?? [];
  const c = conversations.data ?? [];

  const byStatus = useMemo(() => {
    const counts = Object.fromEntries(
      STATUS_ORDER.map((s) => [s, 0]),
    ) as Record<TicketStatus, number>;
    t.forEach((x) => (counts[x.status] += 1));
    return counts;
  }, [t]);

  const openish = byStatus.open + byStatus.in_progress + byStatus.waiting_for_customer;
  const aiActive = c.filter((x) => x.ai_active).length;
  const humanActive = c.filter((x) => !x.ai_active).length;
  const customers = new Set(t.map((x) => x.customer_id)).size;

  const recent = [...t]
    .sort((a, b) => +new Date(b.updated_at) - +new Date(a.updated_at))
    .slice(0, 6);

  const resolutionRate =
    analytics.data && analytics.data.conversations.total > 0
      ? 1 - analytics.data.conversations.escalation_rate
      : null;

  if (tickets.isLoading || conversations.isLoading) {
    return (
      <>
        <PageHeader title="Dashboard" subtitle={`Welcome back, ${user?.name.split(" ")[0] ?? ""}`} />
        <DashboardSkeleton />
      </>
    );
  }

  if (tickets.isError) {
    return (
      <>
        <PageHeader title="Dashboard" />
        <ErrorState message={(tickets.error as Error).message} />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle={`Welcome back, ${user?.name.split(" ")[0]} · ${titleCase(user?.role ?? "")}`}
      />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile
          icon={<TicketIcon size={15} />}
          label="Open tickets"
          value={openish}
          hint={`${byStatus.open} new · ${byStatus.in_progress} in progress`}
        />
        <StatTile
          icon={<TicketIcon size={15} />}
          label="Resolved"
          value={byStatus.resolved + byStatus.closed}
          hint={`${byStatus.resolved} resolved · ${byStatus.closed} closed`}
        />
        <StatTile
          icon={<MessagesSquare size={15} />}
          label="Conversations"
          value={c.length}
          hint={`${aiActive} with AI · ${humanActive} with an agent`}
        />
        <StatTile
          icon={<Users size={15} />}
          label="Customers"
          value={customers}
          hint="with an open case"
        />
      </div>

      <div className="mt-4 grid gap-3 lg:grid-cols-2">
        <Panel>
          <PanelHeader title="Tickets by status" subtitle={`${t.length} total`} />
          <CountBars
            rows={STATUS_ORDER.map((s) => ({
              label: STATUS_LABEL[s],
              value: byStatus[s],
              color: STATUS_COLOR[s],
            }))}
          />
        </Panel>

        {user?.role === "admin" && analytics.data ? (
          <Panel>
            <PanelHeader
              title="AI performance"
              subtitle={`${analytics.data.ai_messages.total} AI replies`}
            />
            <Donut
              value={resolutionRate ?? 0}
              label="Resolved without escalation"
              sublabel={`Avg confidence ${Math.round(
                analytics.data.ai_messages.average_confidence * 100,
              )}% · ${analytics.data.ai_messages.low_confidence} low-confidence replies`}
            />
          </Panel>
        ) : (
          <Panel>
            <PanelHeader title="Conversation load" subtitle="Live" />
            <CountBars
              rows={[
                { label: "Handled by AI", value: aiActive, color: "var(--brand)" },
                {
                  label: "With an agent",
                  value: humanActive,
                  color: "var(--st-waiting)",
                },
              ]}
            />
          </Panel>
        )}
      </div>

      <Panel className="mt-4">
        <PanelHeader
          title="Recently updated tickets"
          action={
            <Link
              href="/tickets"
              className="text-[12px] font-medium text-brand hover:underline"
            >
              View all
            </Link>
          }
        />
        <div className="divide-y divide-border">
          {recent.map((tk) => (
            <Link
              key={tk.id}
              href={`/tickets/${tk.id}`}
              className="flex items-center gap-3 px-4 py-2.5 transition-colors hover:bg-surface-2"
            >
              <span className="tnum w-[76px] shrink-0 font-mono text-[11.5px] text-ink-faint">
                {ticketNo(tk.id)}
              </span>
              <span className="min-w-0 flex-1 truncate text-[13px] text-ink">
                {tk.subject}
              </span>
              <span className="hidden text-[11.5px] text-ink-faint sm:block">
                {userMap.get(tk.customer_id)?.name ?? `Customer #${tk.customer_id}`}
              </span>
              <PriorityBadge priority={tk.priority} />
              <StatusBadge status={tk.status} />
              <span className="hidden w-[60px] shrink-0 text-right text-[11px] text-ink-faint md:block">
                {relativeTime(tk.updated_at)}
              </span>
            </Link>
          ))}
          {recent.length === 0 && (
            <p className="px-4 py-8 text-center text-[12.5px] text-ink-faint">
              No tickets yet.
            </p>
          )}
        </div>
      </Panel>
    </>
  );
}
