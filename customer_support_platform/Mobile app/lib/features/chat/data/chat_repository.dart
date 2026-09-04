import 'chat_model.dart';

class ChatRepository {
  final bool useMock;

  ChatRepository({this.useMock = true});

  List<ChatMessage> getInitialMessages(String userName) {
    return [
      ChatMessage(
        id: 'welcome-1',
        sender: 'ai',
        senderName: 'Laurel AI Assistant',
        text:
            'Hi ${userName.split(' ')[0]}! I am your AI support assistant powered by Laurel Software\'s knowledge base. How can I help you with your appointment system, mobile app, or account today?',
        timestamp: DateTime.now(),
        intent: 'Greeting',
        confidenceScore: 0.99,
      ),
    ];
  }

  Future<ChatMessage> sendUserMessage(String query) async {
    await Future.delayed(const Duration(milliseconds: 1100));

    final lower = query.toLowerCase();

    if (lower.contains('password') || lower.contains('reset')) {
      return ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        senderName: 'Laurel AI Assistant',
        text:
            'To reset your password:\n1. Open Portal Login.\n2. Tap "Forgot?" next to the password input.\n3. Enter your work email to receive a secure recovery code.',
        timestamp: DateTime.now(),
        intent: 'Account / Password Reset',
        confidenceScore: 0.96,
        kbSources: [
          KnowledgeBaseSource(
            title: 'KB-102: Authentication & Password Recovery Policies',
            snippet:
                'Users can request password resets via work email verification.',
          ),
        ],
      );
    } else if (lower.contains('sync') ||
        lower.contains('appointment') ||
        lower.contains('api')) {
      return ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        senderName: 'Laurel AI Assistant',
        text:
            'Appointment synchronization uses background workers. If sync fails, verify your FastAPI endpoint returns status code 200 and has mobile CORS origins configured properly.',
        timestamp: DateTime.now(),
        intent: 'Technical / Appointment Sync',
        confidenceScore: 0.92,
        kbSources: [
          KnowledgeBaseSource(
            title: 'KB-404: FastAPI & Flutter Webhook Sync Guide',
            snippet:
                'Mobile endpoints require CORS and valid Bearer auth tokens.',
          ),
        ],
        suggestedAction: 'contact_agent',
      );
    } else if (lower.contains('human') ||
        lower.contains('agent') ||
        lower.contains('connect')) {
      return ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        senderName: 'Laurel AI Assistant',
        text:
            'I can connect you to our support staff. Tap the button below to transfer this session.',
        timestamp: DateTime.now(),
        intent: 'Escalation / Human Support',
        confidenceScore: 0.98,
        suggestedAction: 'contact_agent',
      );
    }

    return ChatMessage(
      id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'ai',
      senderName: 'Laurel AI Assistant',
      text:
          'I searched our knowledge base for your inquiry. For specific technical issues, I recommend logging a support ticket or connecting with a live agent.',
      timestamp: DateTime.now(),
      intent: 'General Inquiry',
      confidenceScore: 0.81,
      suggestedAction: 'contact_agent',
    );
  }

  Future<ChatMessage> triggerAgentTakeover() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return ChatMessage(
      id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'agent',
      senderName: 'Hammad Don',
      text:
          'Hello, this is Hammad Don from customer support. I have taken over this session and reviewed your previous messages. How can I assist you?',
      timestamp: DateTime.now(),
    );
  }
}
