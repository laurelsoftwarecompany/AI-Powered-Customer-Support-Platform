import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
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
  final bool useMock;

  int? _conversationId;
  int? _linkedTicketId;
  bool _handedToHuman = false;

  ChatRepository({this.apiClient, this.useMock = false});

  /// True once the assistant has escalated and a human owns the conversation.
  bool get handedToHuman => _handedToHuman;
  int? get linkedTicketId => _linkedTicketId;
  int? get conversationId => _conversationId;

  void reset() {
    _conversationId = null;
    _linkedTicketId = null;
    _handedToHuman = false;
  }

  /// Resume the customer's most recent conversation and replay its history.
  ///
  /// Without this the app opened a brand-new conversation on every launch, so
  /// the customer never saw their own history - or any reply an agent posted
  /// from the web dashboard after the AI handed off.
  Future<List<ChatMessage>> loadHistory(String userName) async {
    if (useMock || apiClient == null) return getInitialMessages(userName);

    try {
      final dio = _requireClient();

      final list = await dio.get('/conversations/my');
      final raw = list.data;
      if (raw is! List || raw.isEmpty) return getInitialMessages(userName);

      // /conversations/my comes back newest-first.
      final latest = Map<String, dynamic>.from(raw.first as Map);
      final id = latest['id'] as int;
      _conversationId = id;
      _handedToHuman = latest['ai_active'] == false;
      _linkedTicketId = latest['ticket_id'] as int?;

      final history = await dio.get('/conversations/$id/messages');
      final rows = history.data;
      if (rows is! List || rows.isEmpty) return getInitialMessages(userName);

      final messages = rows
          .map((r) => _historyMessage(Map<String, dynamic>.from(r)))
          .toList();
      return [...getInitialMessages(userName), ...messages];
    } on DioException {
      // Offline or server down - still show the greeting rather than a blank
      // screen; the error surfaces when they actually send something.
      return getInitialMessages(userName);
    }
  }

  ChatMessage _historyMessage(Map<String, dynamic> m) {
    final senderType = (m['sender_type'] ?? 'ai').toString();
    final isCustomer = senderType == 'customer';
    final isAi = senderType == 'ai';
    final confidence = m['confidence'];

    return ChatMessage(
      id: m['id']?.toString() ?? '',
      sender: isCustomer ? 'customer' : (isAi ? 'ai' : 'agent'),
      senderName: isCustomer
          ? 'You'
          : (isAi ? 'Laurel AI Assistant' : 'Support Team'),
      text: (m['content'] ?? '').toString(),
      timestamp: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
      return [...getInitialMessages(userName), ...messages];
    } catch (_) {
      return null;
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

      return _messageFromResponse(
        Map<String, dynamic>.from(response.data as Map),
      );
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
      _handedToHuman = true;
      final ticket = body['ticket'];
      if (ticket is Map) {
        _linkedTicketId = ticket['id'] as int?;
      }
      final ticketNum =
          _linkedTicketId != null ? TicketModel.numberFor(_linkedTicketId!) : '';

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
      _handedToHuman = true;
      final ticket = body['ticket'];
      if (ticket is Map) {
        _linkedTicketId = ticket['id'] as int?;
      }
      final ticketNum =
          _linkedTicketId != null ? TicketModel.numberFor(_linkedTicketId!) : '';

      return ChatMessage(
        id: 'live_agent_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'agent',
        senderName: 'Support Team',
        text:
            'You are connected to our Live Support Team. '
            '${ticketNum.isNotEmpty ? 'Ticket $ticketNum is open for this session. ' : ''}'
            'A specialist will assist you shortly.',
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
        id: 'handoff_${now.millisecondsSinceEpoch}',
        sender: 'agent',
        senderName: 'Support Team',
        text:
            body['message'] ??
            'Your message has been sent to the support team. An agent will '
                'reply here shortly.',
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
      timestamp: aiMessage['created_at'] != null
          ? DateTime.tryParse(aiMessage['created_at'].toString()) ?? now
          : now,
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
