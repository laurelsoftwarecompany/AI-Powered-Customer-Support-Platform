"use client";

import { cn } from "@/components/ui";

export interface CountRow {
  label: string;
  value: number;
  /** css color for the bar; defaults to brand */
  color?: string;
}

export function CountBars({ rows }: { rows: CountRow[] }) {
  const max = Math.max(1, ...rows.map((r) => r.value));

  return (
    <div className="flex flex-col gap-2.5 px-4 py-4">
      {rows.map((r, idx) => (
        <div key={`${r.label}-${idx}`} className="grid grid-cols-[128px_1fr_2.5rem] items-center gap-3">
          <span className="truncate text-[12px] text-ink-soft" title={r.label}>
            {r.label}
          </span>
          <span className="h-2 overflow-hidden rounded-full bg-surface-2">
            <span
              className="block h-full rounded-full transition-[width] duration-500"
              style={{
                width: `${(r.value / max) * 100}%`,
                background: r.color ?? "var(--brand)",
              }}
            />
          </span>
          <span className="tnum text-right text-[12.5px] font-medium text-ink">
            {r.value}
          </span>
        </div>
      ))}
      {rows.length === 0 && (
        <p className="py-4 text-center text-[12.5px] text-ink-faint">No data yet.</p>
      )}
    </div>
  );
}

export function Donut({
  value,
  label,
  sublabel,
}: {
  value: number; // 0..1
  label: string;
  sublabel?: string;
}) {
  const pct = Math.round(value * 100);
  const deg = value * 360;
  return (
    <div className="flex items-center gap-4 px-4 py-4">
      <div
        className="grid size-[92px] shrink-0 place-content-center rounded-full"
        style={{
          background: `conic-gradient(var(--brand) ${deg}deg, var(--surface-2) 0)`,
        }}
      >
        <div className="grid size-[68px] place-content-center rounded-full bg-surface">
          <span className="tnum text-[18px] font-semibold text-ink">{pct}%</span>
        </div>
      </div>
      <div>
        <p className="text-[13px] font-medium text-ink">{label}</p>
        {sublabel && (
          <p className={cn("mt-0.5 text-[12px] text-ink-faint")}>{sublabel}</p>
        )}
      </div>
    </div>
  );
}
