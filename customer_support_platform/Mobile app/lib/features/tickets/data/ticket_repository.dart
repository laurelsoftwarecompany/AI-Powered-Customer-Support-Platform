import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'ticket_model.dart';

class TicketRepository {
  final ApiClient apiClient;
  final bool useMock;

  final List<TicketModel> _mockTickets = [
    TicketModel(
      id: '1',
      ticketNumber: 'TICK-802',
      subject: 'Unable to access my account after password reset',
      description:
          'I have tried resetting my password but still cannot access my account. The page keeps reloading.',
      category: 'Account',
      priority: 'High',
      status: 'In Progress',
      assignedAgentName: 'Marcus Vance',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      timeline: [
        TicketTimelineEvent(
          id: 't1',
          title: 'Ticket Submitted',
          description: 'Ticket created via customer portal',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
        ),
        TicketTimelineEvent(
          id: 't2',
          title: 'Assigned to Support Agent',
          description: 'Marcus Vance picked up the ticket',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
      comments: [
        TicketComment(
          id: 'c1',
          authorName: 'Marcus Vance',
          authorRole: 'agent',
          message:
              'Hello! We have reviewed your account and noticed an active session lock. Let us clear that for you.',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ],
    ),
    TicketModel(
      id: '2',
      ticketNumber: 'TICK-803',
      subject: 'FastAPI appointment sync webhook failing',
      description:
          'The appointment sync endpoint returns 500 status on update.',
      category: 'Appointment Sync',
      priority: 'Urgent',
      status: 'Open',
      assignedAgentName: 'Marcus Vance',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      timeline: [
        TicketTimelineEvent(
          id: 't1',
          title: 'Ticket Submitted',
          description: 'Ticket created via customer portal',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
      comments: [],
    ),
    TicketModel(
      id: '3',
      ticketNumber: 'TICK-799',
      subject: 'Billing discrepancy for enterprise plan',
      description: 'Charged twice on the monthly subscription invoice.',
      category: 'Billing',
      priority: 'Medium',
      status: 'Resolved',
      assignedAgentName: 'Marcus Vance',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      timeline: [
        TicketTimelineEvent(
          id: 't1',
          title: 'Ticket Resolved',
          description: 'Duplicate invoice refunded',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
      comments: [
        TicketComment(
          id: 'c1',
          authorName: 'Marcus Vance',
          authorRole: 'agent',
          message:
              'The duplicate transaction has been refunded back to your account.',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    ),
  ];

  TicketRepository({required this.apiClient, this.useMock = false});

  Future<List<TicketModel>> fetchTickets() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return List.from(_mockTickets);
    }

    try {
      // /tickets is agent+admin only; customers read their own queue here.
      final response = await apiClient.dio.get('/tickets/my');
      final data = response.data;
      final List raw = data is List ? data : (data['tickets'] ?? []);
      return raw
          .map((json) => TicketModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load tickets'));
    }
  }

  Future<TicketModel> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String description,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      final newTicket = TicketModel(
        id: '${_mockTickets.length + 1}',
        ticketNumber: 'TICK-80${_mockTickets.length + 4}',
        subject: subject,
        description: description,
        category: category,
        priority: priority,
        status: 'Open',
        assignedAgentName: 'Marcus Vance',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        timeline: [
          TicketTimelineEvent(
            id: 't_init',
            title: 'Ticket Submitted',
            description: 'Ticket created via customer portal',
            timestamp: DateTime.now(),
          ),
        ],
        comments: [],
      );
      _mockTickets.insert(0, newTicket);
      return newTicket;
    }

    try {
      final response = await apiClient.dio.post(
        '/tickets/',
        data: {
          'subject': subject,
          'category': category,
          // The API takes the lowercase enum value ("high"), not the label.
          'priority': TicketModel.priorityToApi(priority),
          'description': description,
        },
      );
      final body = Map<String, dynamic>.from(response.data as Map);
      return TicketModel.fromJson(
        Map<String, dynamic>.from(body['ticket'] ?? body),
      );
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to create ticket'));
    }
  }

  Future<TicketModel> addComment({
    required String ticketId,
    required String commentText,
    required String authorName,
  }) async {
    if (useMock) {
      final ticket = _mockTickets.firstWhere((t) => t.id == ticketId);
      ticket.comments.add(
        TicketComment(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          authorName: authorName,
          authorRole: 'customer',
          message: commentText,
          timestamp: DateTime.now(),
        ),
      );
      return ticket;
    }

    try {
      await apiClient.dio.post(
        '/tickets/$ticketId/messages',
        data: {'content': commentText},
      );
      final refreshed = await apiClient.dio.get('/tickets/$ticketId');
      return TicketModel.fromJson(
        Map<String, dynamic>.from(refreshed.data as Map),
      );
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to post your reply'));
    }
  }

  /// Messages on a ticket, oldest first. Internal agent notes are filtered
  /// out by the backend for customers.
  Future<List<TicketComment>> fetchComments(String ticketId) async {
    if (useMock) {
      return _mockTickets.firstWhere((t) => t.id == ticketId).comments;
    }

    try {
      final response = await apiClient.dio.get('/tickets/$ticketId/messages');
      final List raw = response.data is List ? response.data : [];
      return raw.map((json) {
        final m = Map<String, dynamic>.from(json);
        final senderType = (m['sender_type'] ?? 'agent').toString();
        return TicketComment(
          id: m['id']?.toString() ?? '',
          authorName: senderType == 'customer' ? 'You' : 'Support Team',
          authorRole: senderType,
          message: m['content'] ?? '',
          timestamp: m['created_at'] != null
              ? DateTime.parse(m['created_at'])
              : DateTime.now(),
        );
      }).toList();
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load ticket replies'));
    }
  }

  String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'];
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the support server. Is the backend running?';
    }
    return fallback;
  }
}
