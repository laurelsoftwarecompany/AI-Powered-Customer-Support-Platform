class DashboardStats {
  final int totalTickets;
  final int activeTickets;
  final int resolvedTickets;

  DashboardStats({
    required this.totalTickets,
    required this.activeTickets,
    required this.resolvedTickets,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalTickets: json['total_tickets'] ?? 0,
      activeTickets: json['active_tickets'] ?? 0,
      resolvedTickets: json['resolved_tickets'] ?? 0,
    );
  }
}

class RecentConversation {
  final String id;
  final String lastMessage;
  final String timestamp;

  RecentConversation({
    required this.id,
    required this.lastMessage,
    required this.timestamp,
  });

  factory RecentConversation.fromJson(Map<String, dynamic> json) {
    return RecentConversation(
      id: json['id'] ?? '',
      lastMessage: json['last_message'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}
