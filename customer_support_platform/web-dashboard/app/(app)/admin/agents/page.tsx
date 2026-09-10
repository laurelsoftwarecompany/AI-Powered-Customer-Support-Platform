"use client";

import { useMemo } from "react";
import dynamic from "next/dynamic";
import { Headphones } from "lucide-react";
import { useAgentWorkload, useTickets, useDirectory } from "@/lib/queries";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  Spinner,
  ErrorState,
  EmptyState,
  Avatar,
  ChartSkeleton,
} from "@/components/ui";

const CountBars = dynamic(
  () => import("@/components/count-bars").then((m) => m.CountBars),
  {
    ssr: false,
    loading: () => <ChartSkeleton />,
  },
);

export default function AdminAgentsPage() {
  const workload = useAgentWorkload();
  const tickets = useTickets();
  const directory = useDirectory();

  const openByAgent = useMemo(() => {
    const m = new Map<number, number>();
    (tickets.data ?? [])
      .filter((t) => t.status !== "resolved" && t.status !== "closed")
      .forEach((t) => {
        if (t.assigned_agent_id != null)
          m.set(t.assigned_agent_id, (m.get(t.assigned_agent_id) ?? 0) + 1);
      });
    return m;
  }, [tickets.data]);

  const agentEmail = useMemo(() => {
    const m = new Map<number, string>();
    (directory.data ?? []).forEach((u) => m.set(u.id, u.email));
    return m;
  }, [directory.data]);

  return (
    <>
      <PageHeader
        title="Agents"
        subtitle={
          workload.data
            ? `${workload.data.length} active support agents`
            : "Team workload"
        }
      />

      {workload.isLoading ? (
        <Spinner />
      ) : workload.isError ? (
        <ErrorState message={(workload.error as Error).message} />
      ) : (workload.data ?? []).length === 0 ? (
        <Panel>
          <EmptyState icon={<Headphones size={22} />} title="No agents yet" />
        </Panel>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          <Panel>
            <div className="border-b border-border px-4 py-3">
              <h2 className="text-[13px] font-semibold text-ink">
                Assigned tickets by agent
              </h2>
            </div>
            <CountBars
              rows={(workload.data ?? [])
                .slice()
                .sort((a, b) => b.assigned_tickets - a.assigned_tickets)
                .map((a) => ({ label: a.name, value: a.assigned_tickets }))}
            />
          </Panel>

          <Panel className="overflow-hidden">
            <div className="border-b border-border px-4 py-3">
              <h2 className="text-[13px] font-semibold text-ink">Team</h2>
            </div>
            <div className="divide-y divide-border">
              {(workload.data ?? []).map((a) => (
                <div key={a.agent_id} className="flex items-center gap-3 px-4 py-3">
                  <Avatar name={a.name} size={32} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[13px] font-medium text-ink">
                      {a.name}
                    </p>
                    <p className="truncate text-[11.5px] text-ink-faint">
                      {agentEmail.get(a.agent_id) ?? a.email}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="tnum text-[13px] font-semibold text-ink">
                      {a.assigned_tickets}
                    </p>
                    <p className="text-[10.5px] text-ink-faint">
                      {openByAgent.get(a.agent_id) ?? 0} open
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </Panel>
        </div>
      )}
    </>
  );
}
