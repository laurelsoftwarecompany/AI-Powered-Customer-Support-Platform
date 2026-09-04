class KnowledgeBaseSource {
  final String title;
  final String snippet;

  KnowledgeBaseSource({required this.title, required this.snippet});
}

class ChatMessage {
  final String id;
  final String sender; // 'customer', 'ai', or 'agent'
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String? intent;
  final double? confidenceScore;
  final List<KnowledgeBaseSource>? kbSources;
  final String? suggestedAction; // e.g. 'contact_agent'

  ChatMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.intent,
    this.confidenceScore,
    this.kbSources,
    this.suggestedAction,
  });
}
