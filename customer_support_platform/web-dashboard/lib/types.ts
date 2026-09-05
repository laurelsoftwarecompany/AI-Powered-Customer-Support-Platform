export type Role = "customer" | "agent" | "admin";

export type TicketStatus =
  | "open"
  | "in_progress"
  | "waiting_for_customer"
  | "resolved"
  | "closed";

export type TicketPriority = "low" | "medium" | "high" | "urgent";

export type SenderType = "customer" | "ai" | "agent" | "admin";

export interface User {
  id: number;
  name: string;
  email: string;
  role: Role;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface Ticket {
  id: number;
  customer_id: number;
  conversation_id?: number | null;
  assigned_agent_id: number | null;
  subject: string;
  description: string;
  category: string;
  priority: TicketPriority;
  status: TicketStatus;
  created_at: string;
  updated_at: string;
}

export interface TicketMessage {
  id: number;
  ticket_id: number;
  sender_id: number;
  sender_type: SenderType;
  content: string;
  is_internal: boolean;
  created_at: string;
}

export interface Conversation {
  id: number;
  customer_id: number;
  status: string;
  ai_active: boolean;
  ticket_id?: number | null;
  created_at: string;
  updated_at: string;
}

export interface MessageSource {
  document_id: number;
  title: string;
  score: number;
  snippet: string;
}

export interface Message {
  id: number;
  conversation_id: number;
  sender_type: SenderType;
  sender_name?: string | null;
  content: string;
  intent: string | null;
  confidence: number | null;
  sources: MessageSource[] | null;
  created_at: string;
}

export interface AdminStats {
  users: { total: number; customers: number; agents: number; active: number; inactive: number };
  tickets: {
    total: number;
    open: number;
    in_progress: number;
    waiting_for_customer: number;
    resolved: number;
    closed: number;
  };
  conversations: { total: number; ai_active: number; human_support: number };
}

export interface AiAnalytics {
  ai_messages: { total: number; average_confidence: number; low_confidence: number };
  intent_distribution: Record<string, number>;
  conversations: {
    total: number;
    ai_active: number;
    human_support: number;
    escalation_rate: number;
  };
}

export interface AgentWorkloadRow {
  agent_id: number;
  name: string;
  email: string;
  assigned_tickets: number;
}
