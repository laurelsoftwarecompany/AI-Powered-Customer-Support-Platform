"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api, apiFetch } from "./api";
import type {
  AdminStats,
  AiAnalytics,
  AgentWorkloadRow,
  Conversation,
  Message,
  Ticket,
  TicketMessage,
  TicketPriority,
  TicketStatus,
  User,
} from "./types";

/* ------------------------------------------------------------------ users */
export function useDirectory() {
  return useQuery({
    queryKey: ["directory"],
    queryFn: () => api.get<User[]>("/users/directory"),
    staleTime: 60_000,
  });
}

/** id -> User lookup built from the directory */
export function useUserMap() {
  const { data } = useDirectory();
  const map = new Map<number, User>();
  (data ?? []).forEach((u) => map.set(u.id, u));
  return map;
}

/* ---------------------------------------------------------------- tickets */
export function useTickets() {
  return useQuery({
    queryKey: ["tickets"],
    queryFn: () => api.get<Ticket[]>("/tickets/"),
  });
}

export function useTicket(id: number) {
  return useQuery({
    queryKey: ["ticket", id],
    queryFn: () => api.get<Ticket>(`/tickets/${id}`),
    enabled: Number.isFinite(id),
  });
}

export function useTicketMessages(id: number) {
  return useQuery({
    queryKey: ["ticket", id, "messages"],
    queryFn: () => api.get<TicketMessage[]>(`/tickets/${id}/messages`),
    enabled: Number.isFinite(id),
  });
}

export function useUpdateTicket(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (patch: {
      status?: TicketStatus;
      priority?: TicketPriority;
      assigned_agent_id?: number | null;
    }) => api.patch<Ticket>(`/tickets/${id}`, patch),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ticket", id] });
      qc.invalidateQueries({ queryKey: ["tickets"] });
    },
  });
}

export function useReplyToTicket(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (content: string) =>
      api.post<TicketMessage>(`/tickets/${id}/messages`, { content }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ticket", id, "messages"] });
      qc.invalidateQueries({ queryKey: ["ticket", id] });
    },
  });
}

export function useAddInternalNote(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (content: string) =>
      api.post<TicketMessage>(`/tickets/${id}/internal-notes`, { content }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ticket", id, "messages"] });
    },
  });
}

export function useTakeoverTicket(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () =>
      api.post<{ message: string; ticket: Ticket }>(`/tickets/${id}/takeover`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ticket", id] });
      qc.invalidateQueries({ queryKey: ["ticket", id, "messages"] });
      qc.invalidateQueries({ queryKey: ["tickets"] });
      qc.invalidateQueries({ queryKey: ["conversations"] });
    },
  });
}

export function useHandbackTicket(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () =>
      api.post<{ message: string; ticket: Ticket }>(`/tickets/${id}/handback`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ticket", id] });
      qc.invalidateQueries({ queryKey: ["ticket", id, "messages"] });
      qc.invalidateQueries({ queryKey: ["tickets"] });
      qc.invalidateQueries({ queryKey: ["conversations"] });
    },
  });
}

/* ----------------------------------------------------------- conversations */
export function useConversations() {
  return useQuery({
    queryKey: ["conversations"],
    queryFn: () => api.get<Conversation[]>("/conversations/"),
  });
}

export function useConversation(id: number) {
  return useQuery({
    queryKey: ["conversation", id],
    queryFn: () => api.get<Conversation>(`/conversations/${id}`),
    enabled: Number.isFinite(id),
  });
}

export function useConversationMessages(id: number) {
  return useQuery({
    queryKey: ["conversation", id, "messages"],
    queryFn: () => api.get<Message[]>(`/conversations/${id}/messages`),
    enabled: Number.isFinite(id),
  });
}

export function useTakeoverConversation(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => api.patch(`/conversations/${id}/takeover`, {}),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["conversation", id] });
      qc.invalidateQueries({ queryKey: ["conversation", id, "messages"] });
      qc.invalidateQueries({ queryKey: ["conversations"] });
      qc.invalidateQueries({ queryKey: ["tickets"] });
    },
  });
}

export function useHandbackConversation(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => api.patch(`/conversations/${id}/handback`, {}),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["conversation", id] });
      qc.invalidateQueries({ queryKey: ["conversation", id, "messages"] });
      qc.invalidateQueries({ queryKey: ["conversations"] });
      qc.invalidateQueries({ queryKey: ["tickets"] });
    },
  });
}

export function useSendConversationMessage(id: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (content: string) =>
      api.post(`/conversations/${id}/messages`, { content }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["conversation", id, "messages"] });
      qc.invalidateQueries({ queryKey: ["conversation", id] });
    },
  });
}

/* ------------------------------------------------------------- admin / stats */
export function useAdminStats() {
  return useQuery({
    queryKey: ["admin", "stats"],
    queryFn: () => api.get<AdminStats>("/admin/dashboard/stats"),
  });
}

export function useAiAnalytics() {
  return useQuery({
    queryKey: ["admin", "ai-analytics"],
    queryFn: () => api.get<AiAnalytics>("/admin/ai/analytics"),
  });
}

export function useAgentStats() {
  return useQuery({
    queryKey: ["agent", "stats"],
    queryFn: () =>
      api.get<{
        tickets: Record<string, number>;
        priority: Record<string, number>;
      }>("/agents/dashboard/stats"),
  });
}

export function useAgentWorkload() {
  return useQuery({
    queryKey: ["agents", "workload"],
    queryFn: () => api.get<AgentWorkloadRow[]>("/agents/workload"),
  });
}

/* ------------------------------------------------------------- admin / users */
export function useAdminUsers() {
  return useQuery({
    queryKey: ["admin", "users"],
    queryFn: () => api.get<User[]>("/admin/users"),
  });
}

export function useSetUserStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, active }: { id: number; active: boolean }) =>
      api.patch(`/admin/users/${id}/status`, { is_active: active }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["directory"] });
    },
  });
}

export function useSetUserRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, role }: { id: number; role: string }) =>
      api.patch(`/admin/users/${id}/role`, { role }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["directory"] });
    },
  });
}

/* --------------------------------------------------------- knowledge base */
export interface KnowledgeDoc {
  id: number;
  title: string;
  filename: string;
  file_type: string;
  status: "active" | "archived";
  chunk_count: number;
  embedded_chunks: number;
  indexed: boolean;
  char_count: number;
  created_at: string;
  updated_at: string;
}

export function useKnowledgeDocs() {
  return useQuery({
    queryKey: ["knowledge"],
    queryFn: () => api.get<KnowledgeDoc[]>("/knowledge/documents"),
  });
}

export function useUploadKnowledge() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ file, title }: { file: File; title?: string }) => {
      const fd = new FormData();
      fd.append("file", file);
      if (title) fd.append("title", title);
      return apiFetch<KnowledgeDoc>("/knowledge/documents", {
        method: "POST",
        body: fd,
      });
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["knowledge"] }),
  });
}

export function useAddFaq() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { question: string; answer: string }) =>
      api.post<KnowledgeDoc>("/knowledge/faqs", body),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["knowledge"] }),
  });
}

export function useDeleteKnowledge() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.del(`/knowledge/documents/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["knowledge"] }),
  });
}

export function useSetKnowledgeStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, status }: { id: number; status: "active" | "archived" }) =>
      api.patch(`/knowledge/documents/${id}`, { status }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["knowledge"] }),
  });
}
