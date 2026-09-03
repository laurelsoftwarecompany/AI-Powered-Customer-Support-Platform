"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { Shell } from "@/components/shell";
import { Spinner } from "@/components/ui";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, loading } = useAuth();

  useEffect(() => {
    if (!loading && !user) router.replace("/login");
  }, [loading, user, router]);

  if (loading || !user) {
    return (
      <div className="grid min-h-dvh place-items-center bg-ground">
        <Spinner label="Loading workspace…" />
      </div>
    );
  }

  if (user.role === "customer") {
    return (
      <div className="grid min-h-dvh place-items-center bg-ground px-4">
        <div className="max-w-sm rounded-xl border border-border bg-surface p-6 text-center shadow-panel">
          <p className="text-[14px] font-semibold text-ink">Not authorized</p>
          <p className="mt-1.5 text-[12.5px] text-ink-faint">
            This console is for support agents and administrators. Customer
            accounts use the mobile app.
          </p>
        </div>
      </div>
    );
  }

  return <Shell>{children}</Shell>;
}
