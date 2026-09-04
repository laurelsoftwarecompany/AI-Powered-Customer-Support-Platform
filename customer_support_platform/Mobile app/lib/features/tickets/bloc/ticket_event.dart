import 'package:equatable/equatable.dart';

abstract class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object?> get props => [];
}

// Fetch all tickets for the user
class LoadTicketsEvent extends TicketEvent {}

// Submit a new ticket
class CreateTicketSubmittedEvent extends TicketEvent {
  final String subject;
  final String category;
  final String priority;
  final String description;

  const CreateTicketSubmittedEvent({
    required this.subject,
    required this.category,
    required this.priority,
    required this.description,
  });

  @override
  List<Object?> get props => [subject, category, priority, description];
}
