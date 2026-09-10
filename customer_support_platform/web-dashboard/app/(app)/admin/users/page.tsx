"use client";

import { useMemo, useState } from "react";
import { Search, UserCog } from "lucide-react";
import { useAdminUsers, useSetUserRole, useSetUserStatus } from "@/lib/queries";
import { useToast } from "@/components/toast";
import { PageHeader } from "@/components/page-header";
import {
  Panel,
  Input,
  Select,
  Button,
  Spinner,
  ErrorState,
  EmptyState,
  Avatar,
  TableSkeleton,
  cn,
} from "@/components/ui";
import { titleCase } from "@/lib/format";
import type { Role } from "@/lib/types";

export default function AdminUsersPage() {
  const users = useAdminUsers();
  const setRole = useSetUserRole();
  const setStatus = useSetUserStatus();
  const { notify } = useToast();

  const [q, setQ] = useState("");
  const [role, setRoleFilter] = useState<Role | "">("");

  const rows = useMemo(() => {
    let list = users.data ?? [];
    if (role) list = list.filter((u) => u.role === role);
    if (q.trim()) {
      const n = q.toLowerCase();
      list = list.filter(
        (u) =>
          u.name.toLowerCase().includes(n) || u.email.toLowerCase().includes(n),
      );
    }
    return [...list].sort((a, b) => a.name.localeCompare(b.name));
  }, [users.data, role, q]);

  async function changeRole(id: number, newRole: string) {
    try {
      await setRole.mutateAsync({ id, role: newRole });
      notify("Role updated.");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  async function toggle(id: number, active: boolean) {
    try {
      await setStatus.mutateAsync({ id, active });
      notify(active ? "Account activated." : "Account deactivated.");
    } catch (e) {
      notify((e as Error).message, "error");
    }
  }

  return (
    <>
      <PageHeader
        title="Users"
        subtitle={users.data ? `${users.data.length} accounts` : "Account management"}
      />

      <Panel className="mb-3 flex flex-wrap items-center gap-2 p-3">
        <div className="relative min-w-[220px] flex-1">
          <Search
            size={15}
            className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-ink-faint"
          />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search name or email…"
            className="pl-8"
          />
        </div>
        <Select
          value={role}
          onChange={(e) => setRoleFilter(e.target.value as Role | "")}
          className="w-[160px]"
        >
          <option value="">All roles</option>
          <option value="customer">Customers</option>
          <option value="agent">Agents</option>
          <option value="admin">Admins</option>
        </Select>
      </Panel>

      <Panel className="overflow-hidden">
        {users.isLoading ? (
          <TableSkeleton rows={6} />
        ) : users.isError ? (
          <ErrorState message={(users.error as Error).message} />
        ) : rows.length === 0 ? (
          <EmptyState icon={<UserCog size={22} />} title="No users found" />
        ) : (
          <div className="overflow-x-auto scroll-thin">
            <table className="w-full min-w-[680px] text-[13px]">
              <thead>
                <tr className="border-b border-border text-left text-[11px] uppercase tracking-wide text-ink-faint">
                  <th className="px-4 py-2.5 font-medium">Name</th>
                  <th className="px-3 py-2.5 font-medium">Email</th>
                  <th className="px-3 py-2.5 font-medium">Role</th>
                  <th className="px-4 py-2.5 text-right font-medium">Account</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {rows.map((u) => (
                  <tr key={u.id} className="hover:bg-surface-2">
                    <td className="px-4 py-2.5">
                      <span className="flex items-center gap-2.5">
                        <Avatar name={u.name} size={26} />
                        <span className="font-medium text-ink">{u.name}</span>
                      </span>
                    </td>
                    <td className="px-3 py-2.5 text-ink-soft">{u.email}</td>
                    <td className="px-3 py-2.5">
                      <Select
                        value={u.role}
                        onChange={(e) => changeRole(u.id, e.target.value)}
                        className="h-8 w-[120px] text-[12px]"
                      >
                        <option value="customer">Customer</option>
                        <option value="agent">Agent</option>
                        <option value="admin">Admin</option>
                      </Select>
                    </td>
                    <td className="px-4 py-2.5">
                      <div className="flex items-center justify-end gap-2">
                        <span
                          className={cn(
                            "text-[11px] font-medium",
                            u.is_active ? "text-st-resolved" : "text-ink-faint",
                          )}
                        >
                          {u.is_active ? "Active" : "Inactive"}
                        </span>
                        <Button
                          size="sm"
                          variant={u.is_active ? "danger" : "secondary"}
                          onClick={() => toggle(u.id, !u.is_active)}
                        >
                          {u.is_active ? "Deactivate" : "Activate"}
                        </Button>
                      </div>
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
