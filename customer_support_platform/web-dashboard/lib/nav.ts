import {
  LayoutDashboard,
  Ticket,
  MessagesSquare,
  Users,
  BookOpen,
  UserCog,
  Headphones,
  ChartNoAxesColumn,
  type LucideIcon,
} from "lucide-react";
import type { Role } from "./types";

export interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
  /** roles allowed to see this item; omit = all staff */
  roles?: Role[];
}

export interface NavSection {
  heading?: string;
  items: NavItem[];
}

export const NAV: NavSection[] = [
  {
    items: [
      { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
      { href: "/tickets", label: "Tickets", icon: Ticket },
      { href: "/conversations", label: "Conversations", icon: MessagesSquare },
      { href: "/customers", label: "Customers", icon: Users },
      { href: "/knowledge", label: "Knowledge Base", icon: BookOpen },
    ],
  },
  {
    heading: "Administration",
    items: [
      { href: "/admin/users", label: "Users", icon: UserCog, roles: ["admin"] },
      { href: "/admin/agents", label: "Agents", icon: Headphones, roles: ["admin"] },
      {
        href: "/admin/analytics",
        label: "AI Analytics",
        icon: ChartNoAxesColumn,
        roles: ["admin"],
      },
    ],
  },
];

export function visibleSections(role: Role): NavSection[] {
  return NAV.map((section) => ({
    ...section,
    items: section.items.filter((it) => !it.roles || it.roles.includes(role)),
  })).filter((section) => section.items.length > 0);
}
