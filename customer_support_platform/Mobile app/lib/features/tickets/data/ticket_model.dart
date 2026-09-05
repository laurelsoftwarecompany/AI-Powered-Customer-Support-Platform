class TicketTimelineEvent {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;

  TicketTimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}

class TicketComment {
  final String id;
  final String authorName;
  final String authorRole;
  final String message;
  final DateTime timestamp;

  TicketComment({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.message,
    required this.timestamp,
  });
}

class TicketModel {
  final String id;
  final String ticketNumber;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String assignedAgentName;
  final int? assignedAgentId;
  final int? conversationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketTimelineEvent> timeline;
  final List<TicketComment> comments;

  TicketModel({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.assignedAgentName = 'Unassigned',
    this.assignedAgentId,
    this.conversationId,
    required this.createdAt,
    required this.updatedAt,
    List<TicketTimelineEvent>? timeline,
    List<TicketComment>? comments,
  }) : timeline = timeline ?? [],
       comments = comments ?? [];

  /// The API stores status/priority as lowercase enum values
  /// (`in_progress`, `high`); the UI shows and switches on display labels.
  static const Map<String, String> _statusLabels = {
    'open': 'Open',
    'in_progress': 'In Progress',
    'waiting_for_customer': 'Waiting for Customer',
    'resolved': 'Resolved',
    'closed': 'Closed',
  };

  static const Map<String, String> _priorityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'urgent': 'Urgent',
  };

  static String statusToApi(String label) => _statusLabels.entries
      .firstWhere(
        (e) => e.value.toLowerCase() == label.toLowerCase(),
        orElse: () => const MapEntry('open', 'Open'),
      )
      .key;

  static String priorityToApi(String label) => _priorityLabels.entries
      .firstWhere(
        (e) => e.value.toLowerCase() == label.toLowerCase(),
        orElse: () => const MapEntry('medium', 'Medium'),
      )
      .key;

  /// Display reference the customer can quote, derived from the id the same
  /// way the agent web dashboard derives it (TICK-0007).
  static String numberFor(Object? id) {
    final parsed = int.tryParse('$id');
    if (parsed == null) return 'TICK-0000';
    return 'TICK-${parsed.toString().padLeft(4, '0')}';
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? 'open').toString().toLowerCase();
    final rawPriority = (json['priority'] ?? 'medium').toString().toLowerCase();
    final agentId = json['assigned_agent_id'];
    final convId = json['conversation_id'];

    return TicketModel(
      id: json['id']?.toString() ?? '',
      ticketNumber: json['ticket_number'] ?? numberFor(json['id']),
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'General',
      priority: _priorityLabels[rawPriority] ?? 'Medium',
      status: _statusLabels[rawStatus] ?? 'Open',
      // Ticket payloads carry the agent's id, not their name, and the user
      // directory is staff-only - so show assignment state, not a fake name.
      assignedAgentName: json['assigned_agent_name'] ??
          (agentId == null ? 'Unassigned' : 'Support Team'),
      assignedAgentId: agentId is int ? agentId : int.tryParse('$agentId'),
      conversationId: convId is int ? convId : int.tryParse('$convId'),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priorityToApi(priority),
      'status': statusToApi(status),
    };
  }
}
