"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { getToken } from "./api";

/**
 * The base URL for WebSocket connections.
 * Derives from the API base URL by swapping the protocol scheme.
 */
function getWsBase(): string {
  const apiBase =
    process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000/api/v1";
  return apiBase
    .replace(/^https:/, "wss:")
    .replace(/^http:/, "ws:");
}

export type WsEvent = {
  event: string;
  message?: Record<string, unknown>;
  [key: string]: unknown;
};

export type WsStatus = "connecting" | "connected" | "disconnected";

/**
 * React hook for subscribing to a WebSocket channel.
 *
 * @param path - WebSocket path, e.g. `/ws/conversations/5`
 * @param onEvent - Callback invoked for every parsed JSON event from the server
 * @returns Connection status
 *
 * @example
 * ```tsx
 * useWebSocket(`/ws/conversations/${id}`, (event) => {
 *   if (event.event === "new_message") {
 *     queryClient.invalidateQueries(["conversation", id, "messages"]);
 *   }
 * });
 * ```
 */
export function useWebSocket(
  path: string | null,
  onEvent: (event: WsEvent) => void,
): WsStatus {
  const [status, setStatus] = useState<WsStatus>("disconnected");
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reconnectAttempts = useRef(0);
  const onEventRef = useRef(onEvent);
  onEventRef.current = onEvent;

  const connect = useCallback(() => {
    if (!path) return;

    const token = getToken();
    if (!token) return;

    const wsBase = getWsBase();
    const separator = path.includes("?") ? "&" : "?";
    const url = `${wsBase}${path}${separator}token=${token}`;

    setStatus("connecting");

    try {
      const ws = new WebSocket(url);
      wsRef.current = ws;

      ws.onopen = () => {
        setStatus("connected");
        reconnectAttempts.current = 0;
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data) as WsEvent;
          onEventRef.current(data);
        } catch {
          // Not valid JSON — ignore
        }
      };

      ws.onclose = () => {
        setStatus("disconnected");
        wsRef.current = null;
        scheduleReconnect();
      };

      ws.onerror = () => {
        // onclose will fire after onerror, which handles reconnection
      };
    } catch {
      setStatus("disconnected");
      scheduleReconnect();
    }
  }, [path]);

  const scheduleReconnect = useCallback(() => {
    if (reconnectTimer.current) {
      clearTimeout(reconnectTimer.current);
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, … capped at 30s
    const delay = Math.min(
      30_000,
      Math.pow(2, reconnectAttempts.current) * 1000,
    );
    reconnectAttempts.current += 1;

    reconnectTimer.current = setTimeout(() => {
      connect();
    }, delay);
  }, [connect]);

  useEffect(() => {
    connect();

    return () => {
      if (reconnectTimer.current) {
        clearTimeout(reconnectTimer.current);
        reconnectTimer.current = null;
      }
      if (wsRef.current) {
        // Prevent reconnect on intentional unmount
        wsRef.current.onclose = null;
        wsRef.current.close();
        wsRef.current = null;
      }
      setStatus("disconnected");
    };
  }, [connect]);

  return status;
}
