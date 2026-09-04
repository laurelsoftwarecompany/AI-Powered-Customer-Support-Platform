import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/ticket_repository.dart';
import 'ticket_event.dart';
import 'ticket_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final TicketRepository ticketRepository;

  TicketBloc({required this.ticketRepository}) : super(TicketInitial()) {
    on<LoadTicketsEvent>(_onLoadTickets);
    on<CreateTicketSubmittedEvent>(_onCreateTicketSubmitted);
  }

  Future<void> _onLoadTickets(
    LoadTicketsEvent event,
    Emitter<TicketState> emit,
  ) async {
    emit(TicketLoading());
    try {
      final tickets = await ticketRepository.fetchTickets();
      emit(TicketLoaded(tickets));
    } catch (e) {
      emit(TicketFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateTicketSubmitted(
    CreateTicketSubmittedEvent event,
    Emitter<TicketState> emit,
  ) async {
    emit(TicketSubmitting());
    try {
      final created = await ticketRepository.createTicket(
        subject: event.subject,
        category: event.category,
        priority: event.priority,
        description: event.description,
      );
      emit(TicketCreateSuccess(created));

      // Reload tickets immediately so the new item shows up in list
      final tickets = await ticketRepository.fetchTickets();
      emit(TicketLoaded(tickets));
    } catch (e) {
      emit(TicketFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
