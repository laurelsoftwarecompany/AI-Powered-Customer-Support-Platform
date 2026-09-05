import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';
import '../../tickets/data/ticket_model.dart';
import 'chat_model.dart';

/// Talks to the AI support assistant.
///
/// Live mode drives the backend RAG pipeline: a conversation is opened on the
/// first message, then every message goes to
/// `POST /conversations/{id}/messages`, which retrieves knowledge-base
/// passages, answers from them, and hands off to a human when the assistant
/// isn't confident. Mock mode keeps canned answers so the UI can be demoed
/// with no backend running.
class ChatRepository {
  final ApiClient? apiClient;
  final WebSocketService? wsService;
  final bool useMock;

  int? _conversationId;
  int? _linkedTicketId;
  bool _handedToHuman = false;

  /// Stream controller for real-time message updates via WebSocket.
  final _messageStreamController =
      StreamController<List<ChatMessage>>.broadcast();

  /// The current full message list (welcome + history + live).
  List<ChatMessage> _currentMessages = [];

  StreamSubscription? _wsSubscription;

  ChatRepository({this.apiClient, this.wsService, this.useMock = false});

  /// True once the assistant has escalated and a human owns the conversation.
  bool get handedToHuman => _handedToHuman;
  bool get isAiActive => !_handedToHuman;
  int? get linkedTicketId => _linkedTicketId;
  int? get conversationId => _conversationId;

  /// Real-time message stream — UI subscribes to this instead of polling.
  Stream<List<ChatMessage>> get messageStream => _messageStreamController.stream;

  void reset() {
    _conversationId = null;
    _linkedTicketId = null;
    _handedToHuman = false;
    _currentMessages = [];
    _disconnectWs();
  }

  /// Load the customer's standalone Ask AI conversation and its messages.
  Future<List<ChatMessage>> loadAskAiHistory(String userName) async {
    if (useMock || apiClient == null) return getInitialMessages(userName);

    try {
      final dio = _requireClient();
      final res = await dio.get('/conversations/ask-ai');
      final data = Map<String, dynamic>.from(res.data as Map);
      final id = data['id'] as int;

      _conversationId = id;
      _linkedTicketId = null;
      _handedToHuman = false;

      final history = await dio.get('/conversations/$id/messages');
      final rows = history.data;
      if (rows is! List || rows.isEmpty) {
        _currentMessages = getInitialMessages(userName);
      } else {
        final messages = rows
            .map((r) => _historyMessage(Map<String, dynamic>.from(r)))
            .toList();
        _currentMessages = [...getInitialMessages(userName), ...messages];
      }

      _connectWs();
      return _currentMessages;
    } on DioException {
      return getInitialMessages(userName);
    }
  }

  /// Start a brand new standalone Ask AI conversation (New Chat).
  Future<List<ChatMessage>> startNewAskAiChat(String userName) async {
    if (useMock || apiClient == null) {
      _currentMessages = getInitialMessages(userName);
      return _currentMessages;
    }

    try {
      final dio = _requireClient();
      final res = await dio.post('/conversations/ask-ai/new');
      final data = Map<String, dynamic>.from(res.data as Map);
      final id = data['id'] as int;

      _conversationId = id;
      _linkedTicketId = null;
      _handedToHuman = false;
      _currentMessages = getInitialMessages(userName);

      _connectWs();
      return _currentMessages;
    } catch (_) {
      _currentMessages = getInitialMessages(userName);
      return _currentMessages;
    }
  }

  /// Load a ticket's dedicated live chat conversation and messages.
  Future<List<ChatMessage>> loadTicketChat(
    int ticketId,
    String userName,
  ) async {
    if (useMock || apiClient == null) return [];

    try {
      final dio = _requireClient();
      final res = await dio.get('/conversations/ticket/$ticketId');
      final body = Map<String, dynamic>.from(res.data as Map);
      final conv = Map<String, dynamic>.from(body['conversation'] as Map);
      final id = conv['id'] as int;

      _conversationId = id;
      _linkedTicketId = ticketId;
      _handedToHuman = conv['ai_active'] == false;

      final history = await dio.get('/conversations/$id/messages');
      final rows = history.data;
      if (rows is! List || rows.isEmpty) {
        _currentMessages = [];
      } else {
        _currentMessages = rows
            .map((r) => _historyMessage(Map<String, dynamic>.from(r)))
            .toList();
      }

      _connectWs();
      return _currentMessages;
    } on DioException {
      return [];
    }
  }

  /// Resume the customer's standalone Ask AI conversation.
  Future<List<ChatMessage>> loadHistory(String userName) async {
    return loadAskAiHistory(userName);
  }

  /// The backend stores naive UTC (`2026-09-05T08:17:38`, no zone marker),
  /// which `DateTime.parse` would read as *local* time - showing every server
  /// message hours off, and breaking any time-based comparison against
  /// locally created messages. Treat a zone-less stamp as UTC.
  static DateTime _parseServerTime(dynamic raw, {DateTime? fallback}) {
    final text = raw?.toString();
    if (text == null || text.isEmpty) return fallback ?? DateTime.now();

    final hasZone = text.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
    final parsed = DateTime.tryParse(hasZone ? text : '${text}Z');
    return parsed?.toLocal() ?? fallback ?? DateTime.now();
  }

  /// Append a message the UI created locally (an optimistic echo of what the
  /// customer just sent, or a reply already returned over HTTP) so the
  /// repository list stays the single source of truth. Without this the WS
  /// echo of the same message has nothing to reconcile against and renders
  /// a second copy.
  List<ChatMessage> addLocalMessage(ChatMessage message) {
    final alreadyThere = _currentMessages.any((m) => m.id == message.id);
    if (!alreadyThere) {
      _currentMessages = [..._currentMessages, message];
      _messageStreamController.add(_currentMessages);
    }
    return _currentMessages;
  }

  ChatMessage _historyMessage(Map<String, dynamic> m) {
    final senderType = (m['sender_type'] ?? 'ai').toString();
    final isCustomer = senderType == 'customer';
    final isAi = senderType == 'ai';
    final confidence = m['confidence'];
    final rawSenderName = m['sender_name']?.toString();

    final senderName = isCustomer
        ? 'You'
        : (rawSenderName != null && rawSenderName.isNotEmpty
            ? rawSenderName
            : (isAi ? 'Laurel AI Assistant' : 'Support Specialist'));

    return ChatMessage(
      id: m['id']?.toString() ?? '',
      sender: isCustomer ? 'customer' : (isAi ? 'ai' : 'agent'),
      senderName: senderName,
      text: (m['content'] ?? '').toString(),
      timestamp: _parseServerTime(m['created_at']),
      intent: isAi ? _prettyIntent(m['intent']) : null,
      confidenceScore: isAi && confidence is num ? confidence.toDouble() : null,
      kbSources: isAi ? _sourcesFrom(m['sources']) : null,
    );
  }

  List<ChatMessage> getInitialMessages(String userName) {
    final firstName = userName.trim().isEmpty
        ? 'there'
        : userName.trim().split(' ').first;
    return [
      ChatMessage(
        id: 'welcome-1',
        sender: 'ai',
        senderName: 'Laurel AI Assistant',
        text:
            'Hi $firstName! I am your AI support assistant. I answer from '
            'Laurel Software\'s knowledge base — ask me about your account, '
            'an order, billing, or a technical problem.',
        timestamp: DateTime.now(),
      ),
    ];
  }

  /// Poll new messages without replacing greeting or throwing errors.
  /// Kept as a fallback but WebSocket is the primary real-time channel.
  Future<List<ChatMessage>?> pollMessages(String userName) async {
    if (useMock || apiClient == null || _conversationId == null) return null;
    try {
      final dio = _requireClient();
      final history = await dio.get('/conversations/$_conversationId/messages');
      final rows = history.data;
      if (rows is! List) return null;
      final messages = rows
          .map((r) => _historyMessage(Map<String, dynamic>.from(r)))
          .toList();
      _currentMessages = [...getInitialMessages(userName), ...messages];
      return _currentMessages;
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------- WebSocket

  void _connectWs() {
    if (useMock || wsService == null || _conversationId == null) return;

    _wsSubscription?.cancel();
    _wsSubscription = wsService!.events.listen(_onWsEvent);
    wsService!.connect('/ws/conversations/$_conversationId');
  }

  void _disconnectWs() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    wsService?.disconnect();
  }

  void _onWsEvent(Map<String, dynamic> event) {
    final type = event['event'];

    if (type == 'new_message') {
      final msgData = event['message'];
      if (msgData is Map<String, dynamic>) {
        final msg = _historyMessage(msgData);

        // Already have the server copy - nothing to do.
        if (_currentMessages.any((m) => m.id == msg.id)) return;

        // The sender shows its own message immediately, before the server has
        // given it an id, so the echo arrives with a different id. Reconcile
        // that optimistic entry in place instead of appending a second copy.
        final pending = _currentMessages.indexWhere((m) =>
            m.id.startsWith('temp-') &&
            m.sender == msg.sender &&
            m.text == msg.text);

        if (pending != -1) {
          final merged = [..._currentMessages];
          merged[pending] = msg;
          _currentMessages = merged;
        } else {
          _currentMessages = [..._currentMessages, msg];
        }
        _messageStreamController.add(_currentMessages);
      }
    } else if (type == 'status_change') {
      final aiActive = event['ai_active'];
      if (aiActive != null) {
        _handedToHuman = (aiActive == false);
        // Notify UI about the status change
        _messageStreamController.add(_currentMessages);
      }
    }
  }

  // ---------------------------------------------------------------- sending

  Future<ChatMessage> sendUserMessage(String query) async {
    if (useMock) return _mockReply(query);

    final dio = _requireClient();

    try {
      final conversationId = await _ensureConversation();

      final response = await dio.post(
        '/conversations/$conversationId/messages',
        data: {'content': query},
      );

      final result = _messageFromResponse(
        Map<String, dynamic>.from(response.data as Map),
      );

      // Ensure WebSocket is connected for follow-up messages
      _connectWs();

      return result;
    } on DioException catch (e) {
      throw Exception(
        _errorMessage(e, 'The assistant is unavailable right now.'),
      );
    }
  }

  /// Explicitly transition to live agent support via the backend handoff endpoint.
  Future<ChatMessage> requestHumanHandoff() async {
    if (useMock) {
      _handedToHuman = true;
      return ChatMessage(
        id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'agent',
        senderName: 'Support Team',
        text:
            'A support agent has been notified and will pick up this '
            'conversation shortly.',
        timestamp: DateTime.now(),
      );
    }

    final dio = _requireClient();
    try {
      final convId = await _ensureConversation();
      final resp = await dio.post('/conversations/$convId/request-agent');
      final body = Map<String, dynamic>.from(resp.data as Map);

      // Live support runs in its own conversation so the Ask AI thread stays
      // pure AI - switch to whichever conversation the backend handed back.
      final conv = body['conversation'];
      if (conv is Map && conv['id'] is int) {
        _conversationId = conv['id'] as int;
      }

      _handedToHuman = true;
      final ticket = body['ticket'];
      if (ticket is Map) {
        _linkedTicketId = ticket['id'] as int?;
      }
      final ticketNum =
          _linkedTicketId != null ? TicketModel.numberFor(_linkedTicketId!) : '';

      // Ensure WebSocket is connected for live agent replies
      _connectWs();

      return ChatMessage(
        id: 'handoff_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'agent',
        senderName: 'Support Team',
        text:
            'You have been connected with our live support team. '
            '${ticketNum.isNotEmpty ? 'Ticket $ticketNum is open for this request. ' : ''}'
            'An agent will reply to your messages directly here.',
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return sendUserMessage(
        'I would like to speak with a human support agent about this.',
      );
    }
  }

  /// Connect or resume a live agent session directly from the Live Agent nav pill.
  Future<ChatMessage> requestLiveAgentSession() async {
    if (useMock) {
      _handedToHuman = true;
      return ChatMessage(
        id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'agent',
        senderName: 'Support Team',
        text:
            'Connected to live agent support. An agent will assist you shortly.',
        timestamp: DateTime.now(),
      );
    }

    final dio = _requireClient();
    try {
      final resp = await dio.post('/conversations/live-agent/session');
      final body = Map<String, dynamic>.from(resp.data as Map);
      final conv = Map<String, dynamic>.from(body['conversation'] as Map);
      _conversationId = conv['id'] as int;
      _handedToHuman = conv['ai_active'] == false;
      final ticket = body['ticket'];
      if (ticket is Map) {
        _linkedTicketId = ticket['id'] as int?;
      }
      final ticketNum =
          _linkedTicketId != null ? TicketModel.numberFor(_linkedTicketId!) : '';

      // Connect WebSocket for live agent replies
      _connectWs();

      if (!_handedToHuman) {
        return ChatMessage(
          id: 'live_ai_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'ai',
          senderName: 'Laurel AI Assistant',
          text:
              'You are connected to Live Support! ${ticketNum.isNotEmpty ? 'Ticket $ticketNum is assigned. ' : ''}'
              'I am answering as your first responder while a human specialist prepares to connect.',
          timestamp: DateTime.now(),
        );
      }

      return ChatMessage(
        id: 'live_agent_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'agent',
        senderName: 'Support Specialist',
        text:
            'You are connected to our Live Support Team. '
            '${ticketNum.isNotEmpty ? 'Ticket $ticketNum is active. ' : ''}'
            'A human specialist has control of this session.',
        timestamp: DateTime.now(),
      );
    } on DioException catch (e) {
      throw Exception(
        _errorMessage(e, 'Failed to connect to live support agent.'),
      );
    }
  }

  // ---------------------------------------------------------------- helpers

  Dio _requireClient() {
    final client = apiClient;
    if (client == null) {
      throw Exception('Chat is not configured to reach the server.');
    }
    return client.dio;
  }

  Future<int> _ensureConversation() async {
    final existing = _conversationId;
    if (existing != null) return existing;

    final response = await _requireClient().post('/conversations/');
    final body = Map<String, dynamic>.from(response.data as Map);
    final id = body['id'] as int;
    _conversationId = id;
    return id;
  }

  ChatMessage _messageFromResponse(Map<String, dynamic> body) {
    final now = DateTime.now();
    final ai = body['ai_message'];

    // The assistant already handed off - a human owns the thread now, so the
    // message was queued for them rather than answered by the AI.
    if (ai == null) {
      _handedToHuman = true;
      return ChatMessage(
        id: 'system_${now.millisecondsSinceEpoch}',
        sender: 'system',
        senderName: 'System Notice',
        text:
            body['message'] ??
            'Message delivered to support specialists. An agent will reply here shortly.',
        timestamp: now,
      );
    }

    final aiMessage = Map<String, dynamic>.from(ai as Map);
    final escalated = body['escalated'] == true;
    if (escalated) _handedToHuman = true;

    var text = (aiMessage['content'] ?? '').toString();

    final ticket = body['ticket'];
    if (ticket != null) {
      final ticketMap = Map<String, dynamic>.from(ticket as Map);
      _linkedTicketId = ticketMap['id'] as int?;
      final number = TicketModel.numberFor(ticketMap['id']);
      text =
          '$text\n\nI\'ve passed this to our support team — ticket $number is '
          'now open and an agent will follow up.';
    }

    final confidence = aiMessage['confidence'];

    return ChatMessage(
      id: aiMessage['id']?.toString() ?? 'ai_${now.millisecondsSinceEpoch}',
      sender: 'ai',
      senderName: 'Laurel AI Assistant',
      text: text,
      timestamp: _parseServerTime(aiMessage['created_at'], fallback: now),
      intent: _prettyIntent(aiMessage['intent']),
      confidenceScore: confidence is num ? confidence.toDouble() : null,
      kbSources: _sourcesFrom(body['sources'] ?? aiMessage['sources']),
      // Offer the escalate button only while the AI still owns the thread.
      suggestedAction: escalated ? null : 'contact_agent',
    );
  }

  List<KnowledgeBaseSource>? _sourcesFrom(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final seen = <String>{};
    final sources = <KnowledgeBaseSource>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final title = (item['title'] ?? '').toString();
      if (title.isEmpty || !seen.add(title)) continue;
      sources.add(
        KnowledgeBaseSource(
          title: title,
          snippet: (item['snippet'] ?? '').toString(),
        ),
      );
    }
    return sources.isEmpty ? null : sources;
  }

  /// order_tracking -> "Order Tracking"
  String? _prettyIntent(dynamic intent) {
    if (intent == null) return null;
    final raw = intent.toString().trim();
    if (raw.isEmpty) return null;
    return raw
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the support server. Is the backend running?';
    }
    return fallback;
  }

  // ---------------------------------------------------------------- mock

  Future<ChatMessage> _mockReply(String query) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final lower = query.toLowerCase();

    if (lower.contains('password') || lower.contains('reset')) {
      return ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        senderName: 'Laurel AI Assistant',
        text:
            'To reset your password, go to Settings → Security → Reset '
            'Password and use the emailed link (valid 30 minutes).',
        timestamp: DateTime.now(),
        intent: 'Account Issue',
        confidenceScore: 0.9,
        kbSources: [
          KnowledgeBaseSource(
            title: 'Account Management - Support Guide',
            snippet: 'Password resets are verified by email.',
          ),
        ],
        suggestedAction: 'contact_agent',
      );
    }

    if (lower.contains('refund') || lower.contains('money back')) {
      return ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        senderName: 'Laurel AI Assistant',
        text:
            'Refunds return to your original payment method within 5–7 '
            'business days once the return is approved.',
        timestamp: DateTime.now(),
        intent: 'Refund Request',
        confidenceScore: 0.88,
        kbSources: [
          KnowledgeBaseSource(
            title: 'Refunds - Support Guide',
            snippet: 'Approved refunds settle in 5-7 business days.',
          ),
        ],
        suggestedAction: 'contact_agent',
      );
    }

    return ChatMessage(
      id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'ai',
      senderName: 'Laurel AI Assistant',
      text:
          'Thanks for reaching out. Could you tell me a bit more about what '
          'you need help with — an order, a refund, your account, or '
          'something else?',
      timestamp: DateTime.now(),
      intent: 'General Support',
      confidenceScore: 0.55,
      suggestedAction: 'contact_agent',
    );
  }
}
