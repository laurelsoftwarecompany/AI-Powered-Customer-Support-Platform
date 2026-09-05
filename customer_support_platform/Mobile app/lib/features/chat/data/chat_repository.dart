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
  bool _handedToHuman = false;

  ChatRepository({this.apiClient, this.useMock = true});

  /// True once the assistant has escalated and a human owns the conversation.
  bool get handedToHuman => _handedToHuman;

  void reset() {
    _conversationId = null;
    _handedToHuman = false;
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

  /// Ask for a person. There is no customer-initiated takeover endpoint - the
  /// assistant escalates on its own - so this sends an explicit request
  /// through the normal pipeline and reports what actually happened.
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

    return sendUserMessage(
      'I would like to speak with a human support agent about this.',
    );
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
      final number = TicketModel.numberFor(
        Map<String, dynamic>.from(ticket as Map)['id'],
      );
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
