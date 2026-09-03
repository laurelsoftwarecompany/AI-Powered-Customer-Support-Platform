"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { Button, Field, Input } from "@/components/ui";
import { ApiError } from "@/lib/api";
import { ThemeToggle } from "@/components/theme-toggle";

export default function LoginPage() {
  const router = useRouter();
  const { user, loading, login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!loading && user) router.replace("/dashboard");
  }, [loading, user, router]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const me = await login(email.trim(), password);
      if (me.role === "customer") {
        setError(
          "This console is for support agents and administrators. Customer accounts use the mobile app.",
        );
        setSubmitting(false);
        return;
      }
      router.replace("/dashboard");
    } catch (err) {
      setError(
        err instanceof ApiError ? err.message : "Something went wrong. Try again.",
      );
      setSubmitting(false);
    }
  }

  return (
    <main className="relative grid min-h-dvh place-items-center bg-ground px-4">
      <div className="fixed top-4 right-4 z-20">
        <ThemeToggle variant="outline" />
      </div>

      <div className="w-full max-w-[380px]">
        <div className="mb-7 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="grid size-9 place-content-center rounded-lg bg-brand font-mono text-[15px] font-semibold text-brand-ink">
              L
            </div>
            <div className="leading-tight">
              <p className="text-[14px] font-semibold text-ink">Laurel Support Console</p>
              <p className="text-[12px] text-ink-faint">Agent &amp; admin workspace</p>
            </div>
          </div>
        </div>

        <div className="rounded-xl border border-border bg-surface p-6 shadow-panel">
          <h1 className="text-[15px] font-semibold text-ink">Sign in</h1>
          <p className="mt-1 text-[12.5px] text-ink-faint">
            Use your support team credentials.
          </p>

          <form onSubmit={onSubmit} className="mt-5 flex flex-col gap-4">
            <Field label="Email">
              <Input
                type="email"
                autoComplete="username"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@laurel.test"
              />
            </Field>
            <Field label="Password">
              <Input
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </Field>

            {error && (
              <p className="rounded-md border border-danger/30 bg-danger-wash px-3 py-2 text-[12.5px] text-danger">
                {error}
              </p>
            )}

            <Button type="submit" variant="primary" loading={submitting} className="mt-1 w-full">
              Sign in
            </Button>
          </form>
        </div>

        <div className="mt-4 flex flex-col items-center gap-2 text-center text-[12px] text-ink-faint">
          <span>Click to fill demo account:</span>
          <div className="flex flex-wrap justify-center gap-2">
            <button
              type="button"
              onClick={() => {
                setEmail("admin@laurel.test");
                setPassword("admin1234");
                setError(null);
              }}
              className="rounded-md border border-border bg-surface px-2.5 py-1 font-mono text-[11.5px] font-medium text-ink transition-colors hover:border-brand hover:text-brand"
            >
              admin@laurel.test
            </button>
            <button
              type="button"
              onClick={() => {
                setEmail("agent@laurel.test");
                setPassword("agent1234");
                setError(null);
              }}
              className="rounded-md border border-border bg-surface px-2.5 py-1 font-mono text-[11.5px] font-medium text-ink transition-colors hover:border-brand hover:text-brand"
            >
              agent@laurel.test
            </button>
          </div>
        </div>
      </div>
    </main>
  );
}
