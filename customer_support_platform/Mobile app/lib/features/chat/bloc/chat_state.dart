import 'package:equatable/equatable.dart';
import '../data/chat_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final bool isBotTyping;

  const ChatLoaded({required this.messages, this.isBotTyping = false});

  @override
  List<Object?> get props => [messages, isBotTyping];
}
