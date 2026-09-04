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
    this.assignedAgentName = 'Marcus Vance',
    required this.createdAt,
    required this.updatedAt,
    List<TicketTimelineEvent>? timeline,
    List<TicketComment>? comments,
  }) : timeline = timeline ?? [],
       comments = comments ?? [];

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id']?.toString() ?? '',
      ticketNumber: json['ticket_number'] ?? 'TICK-000',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'General',
      priority: json['priority'] ?? 'Medium',
      status: json['status'] ?? 'Open',
      assignedAgentName: json['assigned_agent_name'] ?? 'Marcus Vance',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
    };
  }
}
