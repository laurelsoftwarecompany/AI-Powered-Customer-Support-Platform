import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/data/user_model.dart';
import '../../tickets/data/ticket_model.dart';
import '../data/chat_model.dart';
import '../data/chat_repository.dart';

class AIChatScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onBack;
  final VoidCallback onLogTicket;
  final Function(String ticketId)? onOpenTicket;
  final bool isLiveAgent;
  final TicketModel? ticket;
  final VoidCallback? onChangeTicket;

  const AIChatScreen({
    super.key,
    this.user,
    required this.onBack,
    required this.onLogTicket,
    this.onOpenTicket,
    this.isLiveAgent = false,
    this.ticket,
    this.onChangeTicket,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  late final ChatRepository _repository;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _status = 'active'; // 'active' or 'agent_takeover'
  StreamSubscription<List<ChatMessage>>? _wsSubscription;
  Timer? _fallbackPollTimer;

  final List<String> _quickPrompts = [
    'How can I reset my password?',
    'Why are my Flutter mobile appointments not syncing?',
    'How can I view my billing invoices?',
    'Connect me to a human support agent',
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<ChatRepository>();
    _messages = _repository.getInitialMessages(widget.user?.name ?? 'Customer');
    if (widget.isLiveAgent) {
      if (widget.ticket != null) {
        _connectTicketLiveAgent(widget.ticket!);
      } else {
        _connectLiveAgent();
      }
    } else {
      _restoreHistory();
    }
  }

  @override
  void didUpdateWidget(AIChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool modeBecameLive = widget.isLiveAgent && !oldWidget.isLiveAgent;
    final bool ticketChanged =
        widget.isLiveAgent && widget.ticket?.id != oldWidget.ticket?.id;

    if (modeBecameLive || ticketChanged) {
      if (widget.ticket != null) {
        _connectTicketLiveAgent(widget.ticket!);
      } else {
        _connectLiveAgent();
      }
    }
  }

  /// Replay the existing conversation (including anything an agent replied
  /// with after a handoff) instead of starting from a blank screen.
  Future<void> _restoreHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _repository.loadHistory(
        widget.user?.name ?? 'Customer',
      );
      if (!mounted) return;
      setState(() {
        _messages = history;
        _isLoading = false;
        _status = _repository.handedToHuman ? 'agent_takeover' : 'active';
      });
      // Subscribe to WebSocket stream for real-time updates
      _subscribeToWs();
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToWs() {
    _wsSubscription?.cancel();
    _wsSubscription = _repository.messageStream.listen((messages) {
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _status = _repository.handedToHuman ? 'agent_takeover' : 'active';
      });
      _scrollToBottom();
    });
  }

  /// Fallback polling at a much slower interval (30s) for resilience
  /// in case the WebSocket connection drops without triggering reconnect.
  void _startFallbackPolling() {
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted || _status != 'agent_takeover') return;
      final latest =
          await _repository.pollMessages(widget.user?.name ?? 'Customer');
      if (latest != null && latest.length > _messages.length && mounted) {
        setState(() {
          _messages = latest;
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _connectTicketLiveAgent(TicketModel ticket) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final ticketId = int.tryParse(ticket.id) ?? 0;
      final history = await _repository.loadTicketChat(
        ticketId,
        widget.user?.name ?? 'Customer',
      );
      if (!mounted) return;

      final messages = List<ChatMessage>.from(history);
      if (messages.isEmpty) {
        if (_repository.isAiActive) {
          messages.add(
            ChatMessage(
              id: 'ticket_intro_${DateTime.now().millisecondsSinceEpoch}',
              sender: 'ai',
              senderName: 'Laurel AI Assistant',
              text:
                  'Hello! Connected to Live Chat for Ticket ${ticket.ticketNumber}: "${ticket.subject}". I am your AI first responder and can help you right now while a specialist prepares to join.',
              timestamp: DateTime.now(),
            ),
          );
        } else {
          final agentName = (ticket.assignedAgentName.isNotEmpty &&
                  ticket.assignedAgentName != 'Unassigned')
              ? ticket.assignedAgentName
              : 'Support Specialist';

          messages.add(
            ChatMessage(
              id: 'ticket_intro_${DateTime.now().millisecondsSinceEpoch}',
              sender: 'agent',
              senderName: agentName,
              text:
                  'Hello! Connected with live support regarding Ticket ${ticket.ticketNumber}: "${ticket.subject}". An agent is here to help you.',
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
        _status = _repository.handedToHuman ? 'agent_takeover' : 'active';
      });
      _subscribeToWs();
      _startFallbackPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    _scrollToBottom();
  }

  Future<void> _connectLiveAgent() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final reply = await _repository.requestLiveAgentSession();
      if (!mounted) return;
      setState(() {
        _messages = _repository.addLocalMessage(reply);
        _isLoading = false;
        _status = _repository.handedToHuman ? 'agent_takeover' : 'active';
      });
      _subscribeToWs();
      _startFallbackPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _fallbackPollTimer?.cancel();
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
      _messages = _repository.addLocalMessage(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final botReply = await _repository.sendUserMessage(text);
      if (!mounted) return;
      setState(() {
        _messages = _repository.addLocalMessage(botReply);
        _isLoading = false;
        _status = _repository.handedToHuman ? 'agent_takeover' : 'active';
      });
      if (_repository.handedToHuman) {
        _startFallbackPolling();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _scrollToBottom();
  }

  Future<void> _handleEscalateToHuman() async {
    setState(() => _isLoading = true);
    try {
      final reply = await _repository.requestHumanHandoff();
      if (!mounted) return;
      setState(() {
        _messages = _repository.addLocalMessage(reply);
        _isLoading = false;
        _status = _repository.handedToHuman ? 'agent_takeover' : 'active';
      });
      if (_repository.handedToHuman) {
        _startFallbackPolling();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _scrollToBottom();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
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
          onPressed: widget.onBack,
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _status == 'agent_takeover'
                        ? const Color(0xFFD97706)
                        : primaryIndigo,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: (_status == 'agent_takeover'
                                ? const Color(0xFFD97706)
                                : primaryIndigo)
                            .withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _status == 'agent_takeover'
                        ? Icons.person_rounded
                        : Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _status == 'agent_takeover'
                              ? 'Live Support Specialist'
                              : 'Laurel AI Assistant',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _status == 'agent_takeover'
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _status == 'agent_takeover'
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFC7D2FE),
                          ),
                        ),
                        child: Text(
                          _status == 'agent_takeover'
                              ? '👤 Human Agent'
                              : (widget.isLiveAgent
                                  ? '🤖 AI Active'
                                  : '🤖 AI Assistant'),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: _status == 'agent_takeover'
                                ? const Color(0xFFB45309)
                                : primaryIndigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _status == 'agent_takeover'
                        ? 'Specialist has taken over this chat'
                        : (widget.isLiveAgent
                            ? 'AI answering until human specialist takes over'
                            : 'RAG Grounded in KB'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
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
          // Banner with linked ticket shortcut and current handler status
          if (widget.isLiveAgent || widget.ticket != null || _repository.linkedTicketId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _status == 'agent_takeover'
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFEEF2FF),
                border: Border(
                  bottom: BorderSide(
                    color: _status == 'agent_takeover'
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFC7D2FE),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _status == 'agent_takeover'
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _status == 'agent_takeover'
                          ? Icons.support_agent_rounded
                          : Icons.smart_toy_rounded,
                      color: _status == 'agent_takeover'
                          ? const Color(0xFFB45309)
                          : primaryIndigo,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.ticket != null
                                  ? 'Discussing ${widget.ticket!.ticketNumber}'
                                  : (_repository.linkedTicketId != null
                                      ? 'Ticket #${TicketModel.numberFor(_repository.linkedTicketId!)}'
                                      : 'Live Support Request'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _status == 'agent_takeover'
                                    ? const Color(0xFF92400E)
                                    : primaryIndigo,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: _status == 'agent_takeover'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _status == 'agent_takeover'
                                  ? 'Live Specialist'
                                  : 'AI First Responder',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _status == 'agent_takeover'
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _status == 'agent_takeover'
                              ? 'A human support specialist has taken control of this session.'
                              : 'AI is answering your questions until an agent joins.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _status == 'agent_takeover'
                                ? const Color(0xFFB45309)
                                : const Color(0xFF4338CA),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onChangeTicket != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: widget.onChangeTicket,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _status == 'agent_takeover'
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFC7D2FE),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 13,
                                color: _status == 'agent_takeover'
                                    ? const Color(0xFF92400E)
                                    : primaryIndigo,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Tickets',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _status == 'agent_takeover'
                                    ? const Color(0xFF92400E)
                                    : primaryIndigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if ((widget.ticket != null || _repository.linkedTicketId != null) &&
                      widget.onOpenTicket != null)
                    InkWell(
                      onTap: () => widget.onOpenTicket!(
                        widget.ticket?.id ?? _repository.linkedTicketId!.toString(),
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _status == 'agent_takeover'
                              ? const Color(0xFFD97706)
                              : primaryIndigo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Ticket',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ],
                        ),
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

                // 1. System notification / status message
                if (msg.sender == 'system') {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              msg.text,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final isMe = msg.sender == 'customer';
                final isAgent = msg.sender == 'agent';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Sender Badge Header for incoming messages
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5, left: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: isAgent
                                    ? const Color(0xFFD97706)
                                    : primaryIndigo,
                                child: Icon(
                                  isAgent
                                      ? Icons.person_rounded
                                      : Icons.smart_toy_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAgent
                                    ? (msg.senderName.isNotEmpty
                                        ? msg.senderName
                                        : 'Support Specialist')
                                    : 'Laurel AI Assistant',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isAgent
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isAgent
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFFC7D2FE),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isAgent
                                          ? Icons.verified_user_rounded
                                          : Icons.auto_awesome,
                                      size: 9,
                                      color: isAgent
                                          ? const Color(0xFFB45309)
                                          : primaryIndigo,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isAgent
                                          ? 'Human Agent'
                                          : 'AI Assistant',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: isAgent
                                            ? const Color(0xFFB45309)
                                            : primaryIndigo,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Message Bubble
                      Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? primaryIndigo
                                    : isAgent
                                        ? const Color(0xFFFFFBEB)
                                        : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMe ? 14 : 3),
                                  bottomRight: Radius.circular(isMe ? 3 : 14),
                                ),
                                border: isMe
                                    ? null
                                    : Border.all(
                                        color: isAgent
                                            ? const Color(0xFFFCD34D)
                                            : const Color(0xFFE2E8F0),
                                        width: isAgent ? 1.2 : 1,
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isAgent
                                        ? const Color(0xFFD97706).withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Footer & Citations
                      if (isAgent)
                        Padding(
                          padding: const EdgeInsets.only(top: 3, left: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 10,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Verified Specialist Response · ${_formatTime(msg.timestamp)}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!isMe) ...[
                        if (msg.intent != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4),
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
                            padding: const EdgeInsets.only(left: 4, top: 4),
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
                            padding: const EdgeInsets.only(left: 4, top: 6),
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

                        Padding(
                          padding: const EdgeInsets.only(
                            top: 3,
                            left: 4,
                          ),
                          child: Text(
                            'AI Assistant · ${_formatTime(msg.timestamp)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 4),
                          child: Text(
                            _formatTime(msg.timestamp),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
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
                        ? 'Forwarding to live support specialist...'
                        : 'Searching KB & Generating AI response...',
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
              height: 38,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickPrompts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  return ActionChip(
                    label: Text(_quickPrompts[index]),
                    labelStyle: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    onPressed: () => _handleSendMessage(_quickPrompts[index]),
                  );
                },
              ),
            ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: _status == 'agent_takeover'
                          ? 'Reply to live support specialist...'
                          : (widget.isLiveAgent
                              ? 'Ask AI (responding until agent joins)...'
                              : 'Ask AI support question...'),
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _handleSendMessage(),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: primaryIndigo,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 18,
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
