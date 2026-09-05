import 'package:flutter_test/flutter_test.dart';
import 'package:customer_support_app/features/tickets/bloc/ticket_bloc.dart';
import 'package:customer_support_app/features/tickets/bloc/ticket_event.dart';
import 'package:customer_support_app/features/tickets/bloc/ticket_state.dart';
import 'package:customer_support_app/features/tickets/data/ticket_repository.dart';
import 'package:customer_support_app/features/tickets/data/ticket_model.dart';
import 'package:customer_support_app/core/network/api_client.dart';
import 'package:customer_support_app/core/storage/token_storage.dart';

class FakeTicketRepo extends TicketRepository {
  final List<TicketModel> stubTickets;
  final bool shouldFail;

  FakeTicketRepo({this.stubTickets = const [], this.shouldFail = false})
      : super(apiClient: ApiClient(tokenStorage: TokenStorage()), useMock: false);

  @override
  Future<List<TicketModel>> fetchTickets() async {
    if (shouldFail) throw Exception('Server unreachable');
    return stubTickets;
  }

  @override
  Future<TicketModel> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String description,
  }) async {
    if (shouldFail) throw Exception('Failed to create ticket');
    return TicketModel(
      id: '101',
      ticketNumber: 'TICK-0101',
      subject: subject,
      description: description,
      category: category,
      priority: priority,
      status: 'Open',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  group('TicketBloc State Transitions', () {
    test('Initial state is TicketInitial', () {
      final repo = FakeTicketRepo();
      final bloc = TicketBloc(ticketRepository: repo);
      expect(bloc.state, isA<TicketInitial>());
    });

    test('LoadTicketsEvent emits [TicketLoading, TicketLoaded] on success', () async {
      final tickets = [
        TicketModel(
          id: '1',
          ticketNumber: 'TICK-0001',
          subject: 'Account issue',
          description: 'Cannot login',
          category: 'Account',
          priority: 'High',
          status: 'Open',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeTicketRepo(stubTickets: tickets);
      final bloc = TicketBloc(ticketRepository: repo);

      final states = <TicketState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(LoadTicketsEvent());
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<TicketLoading>());
      expect(states[1], isA<TicketLoaded>());
      expect((states[1] as TicketLoaded).tickets.length, 1);

      await subscription.cancel();
    });

    test('LoadTicketsEvent emits [TicketLoading, TicketFailure] on error', () async {
      final repo = FakeTicketRepo(shouldFail: true);
      final bloc = TicketBloc(ticketRepository: repo);

      final states = <TicketState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(LoadTicketsEvent());
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<TicketLoading>());
      expect(states[1], isA<TicketFailure>());
      expect((states[1] as TicketFailure).message, contains('Server unreachable'));

      await subscription.cancel();
    });

    test('CreateTicketSubmittedEvent emits [TicketSubmitting, TicketCreateSuccess, TicketLoaded]', () async {
      final repo = FakeTicketRepo();
      final bloc = TicketBloc(ticketRepository: repo);

      final states = <TicketState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(CreateTicketSubmittedEvent(
        subject: 'New issue',
        category: 'Billing',
        priority: 'High',
        description: 'Detail about billing',
      ));
      await pumpEventQueue();

      expect(states.length, 3);
      expect(states[0], isA<TicketSubmitting>());
      expect(states[1], isA<TicketCreateSuccess>());
      expect(states[2], isA<TicketLoaded>());

      await subscription.cancel();
    });
  });
}
