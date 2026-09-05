import 'package:flutter_test/flutter_test.dart';
import 'package:customer_support_app/features/tickets/data/ticket_model.dart';

void main() {
  group('TicketModel Tests', () {
    test('Correctly deserializes valid JSON payload', () {
      final json = {
        'id': 42,
        'subject': 'Billing inquiry',
        'description': 'Invoice question',
        'category': 'Billing',
        'priority': 'high',
        'status': 'in_progress',
        'assigned_agent_id': 5,
        'assigned_agent_name': 'Marcus Vance',
        'created_at': '2026-09-05T10:00:00Z',
        'updated_at': '2026-09-05T11:00:00Z',
      };

      final ticket = TicketModel.fromJson(json);

      expect(ticket.id, '42');
      expect(ticket.subject, 'Billing inquiry');
      expect(ticket.priority, 'High');
      expect(ticket.status, 'In Progress');
      expect(ticket.assignedAgentName, 'Marcus Vance');
      expect(ticket.assignedAgentId, 5);
      expect(ticket.createdAt, isA<DateTime>());
      expect(ticket.updatedAt, isA<DateTime>());
    });

    test('Gracefully handles malformed or missing timestamps without throwing', () {
      final json = {
        'id': '99',
        'subject': 'Edge case ticket',
        'description': 'Timestamp test',
        'category': 'General',
        'priority': 'urgent',
        'status': 'open',
        'created_at': 'invalid-date-string-abc',
        'updated_at': null,
      };

      final ticket = TicketModel.fromJson(json);

      expect(ticket.id, '99');
      expect(ticket.createdAt, isA<DateTime>());
      expect(ticket.updatedAt, isA<DateTime>());
      expect(ticket.status, 'Open');
      expect(ticket.priority, 'Urgent');
    });

    test('Maps priority and status correctly between API enums and display labels', () {
      expect(TicketModel.priorityToApi('Urgent'), 'urgent');
      expect(TicketModel.priorityToApi('High'), 'high');
      expect(TicketModel.priorityToApi('Medium'), 'medium');
      expect(TicketModel.priorityToApi('Low'), 'low');

      expect(TicketModel.statusToApi('Open'), 'open');
      expect(TicketModel.statusToApi('In Progress'), 'in_progress');
      expect(TicketModel.statusToApi('Waiting for Customer'), 'waiting_for_customer');
      expect(TicketModel.statusToApi('Resolved'), 'resolved');
      expect(TicketModel.statusToApi('Closed'), 'closed');
    });

    test('Generates standard formatted ticket number', () {
      expect(TicketModel.numberFor(1), 'TICK-0001');
      expect(TicketModel.numberFor(123), 'TICK-0123');
      expect(TicketModel.numberFor('not-a-number'), 'TICK-0000');
    });
  });
}
