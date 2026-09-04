import 'package:flutter/material.dart';
import '../../auth/data/user_model.dart';
import '../data/chat_model.dart';
import '../data/chat_repository.dart';

class AIChatScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onBack;
  final VoidCallback onLogTicket;
  final bool isLiveAgent; // <-- Add this field

  const AIChatScreen({
    super.key,
    this.user,
    required this.onBack,
    required this.onLogTicket,
    this.isLiveAgent = false, // <-- Add this parameter with default false
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final ChatRepository _repository = ChatRepository(useMock: true);
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _status = 'active'; // 'active' or 'agent_takeover'
  final String _assignedAgent = 'Hammad Don';

  final List<String> _quickPrompts = [
    'How can I reset my password?',
    'Why are my Flutter mobile appointments not syncing?',
    'How can I view my billing invoices?',
    'Connect me to a human support agent',
  ];

  @override
  void initState() {
    super.initState();
    _messages = _repository.getInitialMessages(widget.user?.name ?? 'Customer');
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? promptText]) async {
    final text = promptText ?? _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _textController.clear();

    final userMsg = ChatMessage(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      sender: 'customer',
      senderName: widget.user?.name ?? 'Customer',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    final botReply = await _repository.sendUserMessage(text);

    setState(() {
      _messages.add(botReply);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _handleEscalateToHuman() async {
    setState(() => _isLoading = true);
    final agentMsg = await _repository.triggerAgentTakeover();
    setState(() {
      _status = 'agent_takeover';
      _messages.add(agentMsg);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF4F46E5);
    const bgColor = Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF0F172A),
            size: 28,
          ),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _status == 'agent_takeover'
                        ? const Color(0xFFD97706)
                        : primaryIndigo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _status == 'agent_takeover'
                        ? Icons.headset_mic_rounded
                        : Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _status == 'agent_takeover'
                          ? 'Live Support Agent'
                          : 'Laurel AI Assistant',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (_status == 'agent_takeover') ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Live Agent',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _status == 'agent_takeover'
                      ? 'Care of $_assignedAgent'
                      : 'RAG Grounded in KB',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: widget.onLogTicket,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      color: primaryIndigo,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Log Ticket',
                      style: TextStyle(
                        color: primaryIndigo,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Agent takeover banner
          if (_status == 'agent_takeover')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(
                    Icons.headset_mic_rounded,
                    color: Color(0xFFD97706),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Human Agent $_assignedAgent has taken over.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.sender == 'customer';
                final isAgent = msg.sender == 'agent';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isAgent
                                  ? const Color(0xFFD97706)
                                  : primaryIndigo,
                              child: Icon(
                                isAgent
                                    ? Icons.headset_mic_rounded
                                    : Icons.smart_toy_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? primaryIndigo
                                    : isAgent
                                    ? const Color(0xFFFEF3C7)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: isMe
                                    ? null
                                    : Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // RAG Citations & Action buttons
                      if (!isMe) ...[
                        if (msg.intent != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, top: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Intent: ${msg.intent}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                if (msg.confidenceScore != null) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${(msg.confidenceScore! * 100).toInt()}% Conf',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        if (msg.kbSources != null && msg.kbSources!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, top: 4),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.menu_book_rounded,
                                    size: 12,
                                    color: primaryIndigo,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Source: ${msg.kbSources![0].title}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (msg.suggestedAction == 'contact_agent' &&
                            _status != 'agent_takeover')
                          Padding(
                            padding: const EdgeInsets.only(left: 30, top: 6),
                            child: InkWell(
                              onTap: _handleEscalateToHuman,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.headset_mic_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Connect with Live Support Agent',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],

                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2,
                          right: 4,
                          left: 32,
                        ),
                        child: Text(
                          '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Typing indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryIndigo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _status == 'agent_takeover'
                        ? 'Hammad is typing...'
                        : 'Searching KB & Generating...',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Prompts row
          if (_messages.length <= 2)
            Container(
              height: 36,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickPrompts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  return ActionChip(
                    label: Text(_quickPrompts[index]),
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF334155),
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onPressed: () => _handleSendMessage(_quickPrompts[index]),
                  );
                },
              ),
            ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: _status == 'agent_takeover'
                          ? 'Reply to live agent...'
                          : 'Ask AI support question...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _handleSendMessage(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryIndigo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
