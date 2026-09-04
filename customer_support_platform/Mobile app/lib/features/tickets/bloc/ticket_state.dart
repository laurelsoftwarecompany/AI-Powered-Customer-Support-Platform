import 'package:equatable/equatable.dart';
import '../data/ticket_model.dart';

abstract class TicketState extends Equatable {
  const TicketState();

  @override
  List<Object?> get props => [];
}

class TicketInitial extends TicketState {}

// Showing spinner when fetching tickets
class TicketLoading extends TicketState {}

// Successfully fetched tickets
class TicketLoaded extends TicketState {
  final List<TicketModel> tickets;

  const TicketLoaded(this.tickets);

  @override
  List<Object?> get props => [tickets];
}

// Creating ticket loading indicator
class TicketSubmitting extends TicketState {}

// Successfully created ticket
class TicketCreateSuccess extends TicketState {
  final TicketModel newTicket;

  const TicketCreateSuccess(this.newTicket);

  @override
  List<Object?> get props => [newTicket];
}

// Error state with message
class TicketFailure extends TicketState {
  final String message;

  const TicketFailure(this.message);

  @override
  List<Object?> get props => [message];
}
