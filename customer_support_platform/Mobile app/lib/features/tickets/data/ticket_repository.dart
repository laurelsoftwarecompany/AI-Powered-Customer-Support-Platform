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

  TicketRepository({required this.apiClient, this.useMock = true});

  Future<List<TicketModel>> fetchTickets() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return List.from(_mockTickets);
    }

    try {
      final response = await apiClient.dio.get('/tickets');
      final List data = response.data['tickets'] ?? [];
      return data.map((json) => TicketModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to load tickets');
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
        '/tickets',
        data: {
          'subject': subject,
          'category': category,
          'priority': priority,
          'description': description,
        },
      );
      return TicketModel.fromJson(response.data['ticket']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to create ticket');
    }
  }

  Future<TicketModel> addComment({
    required String ticketId,
    required String commentText,
    required String authorName,
  }) async {
    final ticket = _mockTickets.firstWhere((t) => t.id == ticketId);
    final newComment = TicketComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName,
      authorRole: 'customer',
      message: commentText,
      timestamp: DateTime.now(),
    );
    ticket.comments.add(newComment);
    return ticket;
  }
}
