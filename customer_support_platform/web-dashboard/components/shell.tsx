"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { LogOut, Menu, X } from "lucide-react";
import { useAuth } from "@/lib/auth";
import { visibleSections } from "@/lib/nav";
import { Avatar, cn } from "@/components/ui";
import { titleCase } from "@/lib/format";
import { ThemeToggle } from "@/components/theme-toggle";

export function Shell({ children }: { children: React.ReactNode }) {
  const { user, logout } = useAuth();
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  if (!user) return null;
  const sections = visibleSections(user.role);

  const nav = (
    <nav className="flex flex-1 flex-col gap-6 overflow-y-auto px-3 py-4 scroll-thin">
      {sections.map((section, i) => (
        <div key={i} className="flex flex-col gap-0.5">
          {section.heading && (
            <p className="mb-1 px-2.5 text-[10.5px] font-semibold uppercase tracking-wider text-ink-faint">
              {section.heading}
            </p>
          )}
          {section.items.map((item) => {
            const active =
              pathname === item.href || pathname.startsWith(item.href + "/");
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setMobileOpen(false)}
                className={cn(
                  "flex items-center gap-2.5 rounded-md px-2.5 py-1.5 text-[13px] font-medium transition-colors",
                  active
                    ? "bg-brand-wash text-brand"
                    : "text-ink-soft hover:bg-surface-2 hover:text-ink",
                )}
              >
                <item.icon size={16} className="shrink-0" />
                {item.label}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );

  const sidebarInner = (
    <>
      <div className="flex h-14 items-center justify-between border-b border-border px-4">
        <div className="flex items-center gap-2.5">
          <div className="grid size-7 place-content-center rounded-md bg-brand font-mono text-[13px] font-semibold text-brand-ink">
            L
          </div>
          <span className="text-[13.5px] font-semibold text-ink">Support Console</span>
        </div>
      </div>
      {nav}
      <div className="border-t border-border p-3">
        <div className="flex items-center gap-2 rounded-md px-1.5 py-1.5">
          <Avatar name={user.name} size={30} />
          <div className="min-w-0 flex-1 leading-tight">
            <p className="truncate text-[12.5px] font-medium text-ink">{user.name}</p>
            <p className="truncate text-[11px] text-ink-faint">{titleCase(user.role)}</p>
          </div>
          <ThemeToggle className="shrink-0 p-1.5" />
          <button
            onClick={logout}
            className="shrink-0 rounded p-1.5 text-ink-faint hover:bg-surface-2 hover:text-ink"
            aria-label="Sign out"
            title="Sign out"
          >
            <LogOut size={15} />
          </button>
        </div>
      </div>
    </>
  );

  return (
    <div className="flex min-h-dvh bg-ground text-ink">
      {/* Desktop sidebar */}
      <aside className="sticky top-0 hidden h-dvh w-[228px] shrink-0 flex-col border-r border-border bg-surface md:flex">
        {sidebarInner}
      </aside>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-40 md:hidden">
          <div
            className="absolute inset-0 bg-black/30"
            onClick={() => setMobileOpen(false)}
          />
          <aside className="absolute left-0 top-0 flex h-full w-[248px] flex-col border-r border-border bg-surface">
            {sidebarInner}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-border bg-surface/85 px-4 backdrop-blur md:px-6">
          <button
            className="rounded p-1.5 text-ink-soft hover:bg-surface-2 md:hidden"
            onClick={() => setMobileOpen((v) => !v)}
            aria-label="Toggle navigation"
          >
            {mobileOpen ? <X size={18} /> : <Menu size={18} />}
          </button>
          <div className="flex-1" />
          <ThemeToggle className="hidden sm:inline-flex" />
          <span className="hidden text-[12px] text-ink-faint sm:block">
            {user.email}
          </span>
          <Avatar name={user.name} size={28} />
        </header>

        <main className="min-w-0 flex-1 px-4 py-5 md:px-6 md:py-6">{children}</main>
      </div>
    </div>
  );
}
