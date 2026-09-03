"use client";

import { Bot } from "lucide-react";
import { useAiAnalytics } from "@/lib/queries";
import { PageHeader } from "@/components/page-header";
import { Panel, PanelHeader, Spinner, ErrorState } from "@/components/ui";
import { CountBars, Donut } from "@/components/count-bars";
import { titleCase, pct } from "@/lib/format";

function Metric({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Panel className="p-4">
      <p className="text-[11.5px] font-medium uppercase tracking-wide text-ink-faint">
        {label}
      </p>
      <p className="tnum mt-1.5 text-[22px] font-semibold text-ink">{value}</p>
      {hint && <p className="mt-1 text-[11.5px] text-ink-faint">{hint}</p>}
    </Panel>
  );
}

export default function AdminAnalyticsPage() {
  const { data, isLoading, isError, error } = useAiAnalytics();

  if (isLoading)
    return (
      <>
        <PageHeader title="AI Analytics" />
        <Spinner />
      </>
    );
  if (isError)
    return (
      <>
        <PageHeader title="AI Analytics" />
        <ErrorState message={(error as Error).message} />
      </>
    );

  const a = data!;
  const resolutionRate =
    a.conversations.total > 0 ? 1 - a.conversations.escalation_rate : 0;

  const intents = Object.entries(a.intent_distribution)
    .map(([label, value]) => ({ label: titleCase(label), value }))
    .sort((x, y) => y.value - x.value);

  return (
    <>
      <PageHeader
        title="AI Analytics"
        subtitle="How the AI assistant is performing across all conversations"
      />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Metric label="AI replies" value={String(a.ai_messages.total)} />
        <Metric
          label="Avg confidence"
          value={pct(a.ai_messages.average_confidence)}
        />
        <Metric
          label="Low-confidence"
          value={String(a.ai_messages.low_confidence)}
          hint="below 70%"
        />
        <Metric
          label="Escalation rate"
          value={pct(a.conversations.escalation_rate)}
          hint={`${a.conversations.human_support} of ${a.conversations.total} conversations`}
        />
      </div>

      <div className="mt-4 grid gap-3 lg:grid-cols-2">
        <Panel>
          <PanelHeader title="Resolution without escalation" />
          <Donut
            value={resolutionRate}
            label={`${pct(resolutionRate)} handled by AI alone`}
            sublabel={`${a.conversations.ai_active} conversations still with the AI`}
          />
        </Panel>
        <Panel>
          <PanelHeader
            title="Intent distribution"
            subtitle={`${intents.length} intents seen`}
          />
          {intents.length ? (
            <CountBars rows={intents} />
          ) : (
            <div className="px-4 py-8 text-center text-[12.5px] text-ink-faint">
              <Bot size={20} className="mx-auto mb-2 opacity-60" />
              No AI messages classified yet.
            </div>
          )}
        </Panel>
      </div>
    </>
  );
}
