"use client";

import { Loader2 } from "lucide-react";
import type { TicketPriority, TicketStatus } from "@/lib/types";
import { PRIORITY_LABEL, STATUS_LABEL, initials } from "@/lib/format";

/* -------------------------------------------------------------- cn */
export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(" ");
}

/* -------------------------------------------------------------- Button */
type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "ghost" | "danger" | "outline";
  size?: "sm" | "md";
  loading?: boolean;
};

export function Button({
  variant = "secondary",
  size = "md",
  loading,
  className,
  children,
  disabled,
  ...rest
}: ButtonProps) {
  const base =
    "inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-55 focus-visible:outline-2";
  const sizes = {
    sm: "h-8 px-2.5 text-[12.5px]",
    md: "h-9 px-3.5 text-[13px]",
  };
  const variants = {
    primary: "bg-brand text-brand-ink hover:bg-brand-hover",
    secondary:
      "border border-border-strong bg-surface text-ink hover:bg-surface-2",
    outline: "border border-border bg-transparent text-ink hover:bg-surface-2",
    ghost: "text-ink-soft hover:bg-surface-2 hover:text-ink",
    danger: "border border-danger/40 bg-danger-wash text-danger hover:bg-danger/15",
  };
  return (
    <button
      className={cn(base, sizes[size], variants[variant], className)}
      disabled={disabled || loading}
      {...rest}
    >
      {loading && <Loader2 size={14} className="animate-spin" />}
      {children}
    </button>
  );
}

/* -------------------------------------------------------------- Panel / Card */
export function Panel({
  className,
  children,
}: {
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className={cn(
        "rounded-xl border border-border bg-surface shadow-card",
        className,
      )}
    >
      {children}
    </div>
  );
}

export function PanelHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-3 border-b border-border px-4 py-3">
      <div>
        <h2 className="text-[13px] font-semibold text-ink">{title}</h2>
        {subtitle && (
          <p className="mt-0.5 text-[12px] text-ink-faint">{subtitle}</p>
        )}
      </div>
      {action}
    </div>
  );
}

/* -------------------------------------------------------------- Badges */
const STATUS_CLASS: Record<TicketStatus, string> = {
  open: "bg-st-open-wash text-st-open",
  in_progress: "bg-st-progress-wash text-st-progress",
  waiting_for_customer: "bg-st-waiting-wash text-st-waiting",
  resolved: "bg-st-resolved-wash text-st-resolved",
  closed: "bg-st-closed-wash text-st-closed",
};

export function StatusBadge({ status }: { status: TicketStatus }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] font-medium whitespace-nowrap",
        STATUS_CLASS[status],
      )}
    >
      <span className="size-1.5 rounded-full bg-current" />
      {STATUS_LABEL[status]}
    </span>
  );
}

const PRIORITY_CLASS: Record<TicketPriority, string> = {
  urgent: "text-pr-urgent border-pr-urgent/35",
  high: "text-pr-high border-pr-high/35",
  medium: "text-pr-medium border-pr-medium/35",
  low: "text-pr-low border-pr-low/35",
};

export function PriorityBadge({ priority }: { priority: TicketPriority }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-md border px-1.5 py-0.5 text-[11px] font-medium whitespace-nowrap",
        PRIORITY_CLASS[priority],
      )}
    >
      {PRIORITY_LABEL[priority]}
    </span>
  );
}

export function Tag({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-md bg-surface-2 px-1.5 py-0.5 text-[11px] font-medium text-ink-soft",
        className,
      )}
    >
      {children}
    </span>
  );
}

/* -------------------------------------------------------------- Avatar */
export function Avatar({
  name,
  size = 28,
}: {
  name: string;
  size?: number;
}) {
  return (
    <span
      className="inline-grid shrink-0 place-content-center rounded-full bg-brand-wash font-semibold text-brand"
      style={{ width: size, height: size, fontSize: size * 0.38 }}
    >
      {initials(name)}
    </span>
  );
}

/* -------------------------------------------------------------- Form controls */
export const inputClass =
  "h-9 w-full rounded-md border border-border-strong bg-surface px-3 text-[13px] text-ink placeholder:text-ink-faint focus-visible:border-brand focus-visible:outline-2 focus-visible:outline-focus";

export function Input(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={cn(inputClass, props.className)} />;
}

export function Textarea(
  props: React.TextareaHTMLAttributes<HTMLTextAreaElement>,
) {
  return (
    <textarea
      {...props}
      className={cn(
        "w-full rounded-md border border-border-strong bg-surface px-3 py-2 text-[13px] text-ink placeholder:text-ink-faint focus-visible:border-brand focus-visible:outline-2 focus-visible:outline-focus",
        props.className,
      )}
    />
  );
}

export function Select(props: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      {...props}
      className={cn(
        inputClass,
        "cursor-pointer appearance-none bg-[length:16px] bg-[right_0.5rem_center] bg-no-repeat pr-8",
        props.className,
      )}
      style={{
        backgroundImage:
          "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%238592a8' stroke-width='2'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E\")",
      }}
    />
  );
}

export function Field({
  label,
  children,
  hint,
}: {
  label: string;
  children: React.ReactNode;
  hint?: string;
}) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-[12px] font-medium text-ink-soft">{label}</span>
      {children}
      {hint && <span className="text-[11px] text-ink-faint">{hint}</span>}
    </label>
  );
}

/* -------------------------------------------------------------- States */
export function Spinner({ label }: { label?: string }) {
  return (
    <div className="flex items-center justify-center gap-2 py-12 text-[13px] text-ink-faint">
      <Loader2 size={16} className="animate-spin" />
      {label ?? "Loading…"}
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon?: React.ReactNode;
  title: string;
  body?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-14 text-center">
      {icon && <div className="text-ink-faint">{icon}</div>}
      <p className="text-[13px] font-semibold text-ink">{title}</p>
      {body && <p className="max-w-sm text-[12.5px] text-ink-faint">{body}</p>}
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="m-4 rounded-lg border border-danger/30 bg-danger-wash px-4 py-3 text-[13px] text-danger">
      {message}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn("animate-pulse rounded bg-surface-2", className)}
      aria-hidden
    />
  );
}

/* Shown while a detail page loads - keeps the page shape so navigation
   doesn't flash a bare spinner or shift the layout when data arrives. */
export function DetailSkeleton() {
  return (
    <div className="animate-pulse" aria-hidden>
      <div className="mb-3 h-3.5 w-28 rounded bg-surface-3" />
      <div className="mb-5 flex items-end justify-between gap-3">
        <div className="space-y-2.5">
          <div className="h-5 w-52 rounded bg-surface-3" />
          <div className="h-3 w-36 rounded bg-surface-3" />
        </div>
        <div className="h-8 w-28 rounded-md bg-surface-3" />
      </div>
      <div className="grid gap-4 lg:grid-cols-[1fr_18rem]">
        <div className="space-y-4">
          <div className="h-72 rounded-xl bg-surface-3" />
          <div className="h-32 rounded-xl bg-surface-3" />
        </div>
        <div className="hidden space-y-4 lg:block">
          <div className="h-44 rounded-xl bg-surface-3" />
          <div className="h-28 rounded-xl bg-surface-3" />
        </div>
      </div>
    </div>
  );
}

export function TableSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="divide-y divide-border animate-pulse" aria-hidden>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-3 px-4 py-3">
          <div className="h-3.5 w-14 rounded bg-surface-3" />
          <div className="h-4 flex-1 rounded bg-surface-3" />
          <div className="hidden h-3.5 w-20 rounded bg-surface-3 sm:block" />
          <div className="h-5 w-16 rounded-md bg-surface-3" />
          <div className="h-5 w-16 rounded-md bg-surface-3" />
          <div className="hidden h-3.5 w-12 rounded bg-surface-3 md:block" />
        </div>
      ))}
    </div>
  );
}

export function ChartSkeleton() {
  return (
    <div className="flex flex-col gap-3 p-4 animate-pulse" aria-hidden>
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="grid grid-cols-[120px_1fr_2.5rem] items-center gap-3">
          <div className="h-3 w-20 rounded bg-surface-3" />
          <div className="h-2 w-full rounded-full bg-surface-3" />
          <div className="h-3 w-6 rounded bg-surface-3 ml-auto" />
        </div>
      ))}
    </div>
  );
}

export function DonutSkeleton() {
  return (
    <div className="flex items-center gap-4 p-4 animate-pulse" aria-hidden>
      <div className="size-[92px] rounded-full bg-surface-3 shrink-0" />
      <div className="space-y-2 flex-1">
        <div className="h-4 w-32 rounded bg-surface-3" />
        <div className="h-3 w-48 rounded bg-surface-3" />
      </div>
    </div>
  );
}

export function DashboardSkeleton() {
  return (
    <div className="space-y-4 animate-pulse" aria-hidden>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="rounded-xl border border-border bg-surface p-4 space-y-2">
            <div className="h-3 w-20 rounded bg-surface-3" />
            <div className="h-7 w-14 rounded bg-surface-3" />
            <div className="h-2.5 w-28 rounded bg-surface-3" />
          </div>
        ))}
      </div>
      <div className="grid gap-3 lg:grid-cols-2">
        <div className="rounded-xl border border-border bg-surface p-4">
          <div className="h-4 w-32 mb-4 rounded bg-surface-3" />
          <ChartSkeleton />
        </div>
        <div className="rounded-xl border border-border bg-surface p-4">
          <div className="h-4 w-32 mb-4 rounded bg-surface-3" />
          <ChartSkeleton />
        </div>
      </div>
      <div className="rounded-xl border border-border bg-surface overflow-hidden">
        <div className="h-10 border-b border-border bg-surface-2/40 px-4 py-3" />
        <TableSkeleton rows={5} />
      </div>
    </div>
  );
}

