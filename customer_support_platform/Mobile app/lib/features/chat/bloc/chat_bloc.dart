import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/chat_model.dart';
import '../data/chat_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository chatRepository;
  final List<ChatMessage> _currentMessages = [];

  ChatBloc({required this.chatRepository}) : super(ChatInitial()) {
    on<InitChatEvent>(_onInitChat);
    on<SendMessageEvent>(_onSendMessage);
  }

  void _onInitChat(InitChatEvent event, Emitter<ChatState> emit) {
    if (_currentMessages.isEmpty) {
      _currentMessages.addAll(chatRepository.getInitialMessages('Customer'));
    }
    emit(ChatLoaded(messages: List.from(_currentMessages)));
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    final userMsg = ChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'customer',
      senderName: 'Customer',
      text: event.text,
      timestamp: DateTime.now(),
    );

    _currentMessages.add(userMsg);
    emit(ChatLoaded(messages: List.from(_currentMessages), isBotTyping: true));

    try {
      final botMsg = await chatRepository.sendUserMessage(event.text);
      _currentMessages.add(botMsg);
      emit(
        ChatLoaded(messages: List.from(_currentMessages), isBotTyping: false),
      );
    } catch (_) {
      emit(
        ChatLoaded(messages: List.from(_currentMessages), isBotTyping: false),
      );
    }
  }
}
