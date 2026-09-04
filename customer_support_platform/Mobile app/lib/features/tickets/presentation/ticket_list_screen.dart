import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import '../data/ticket_model.dart';

class TicketTimelineEvent {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;

  TicketTimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}

class TicketComment {
  final String id;
  final String authorName;
  final String authorRole; // 'customer' or 'agent'
  final String message;
  final DateTime timestamp;

  TicketComment({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.message,
    required this.timestamp,
  });
}

class TicketListScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  final String? initialTicketId;

  const TicketListScreen({super.key, this.onNavigateTab, this.initialTicketId});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _filterStatus = 'all';
  String _searchQuery = '';
  TicketModel? _activeTicket;

  final List<String> _statusFilters = [
    'all',
    'Open',
    'In Progress',
    'Waiting for Customer',
    'Resolved',
    'Closed',
  ];

  // In-memory conversation & timeline stores for interactive demo
  final Map<String, List<TicketComment>> _commentsMap = {};
  final Map<String, List<TicketTimelineEvent>> _timelineMap = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<TicketTimelineEvent> _getTimelineForTicket(TicketModel ticket) {
    return _timelineMap.putIfAbsent(ticket.id, () {
      return [
        TicketTimelineEvent(
          id: '1',
          title: 'Ticket Created',
          description:
              'Ticket logged by customer with priority ${ticket.priority}.',
          timestamp: ticket.createdAt,
        ),
        TicketTimelineEvent(
          id: '2',
          title: 'Agent Assigned',
          description: 'Assigned to Support Specialist Marcus Vance.',
          timestamp: ticket.createdAt.add(const Duration(minutes: 6)),
        ),
        if (ticket.status != 'Open')
          TicketTimelineEvent(
            id: '3',
            title: 'Under Investigation',
            description:
                'Agent initiated diagnostics and verified workspace logs.',
            timestamp: ticket.createdAt.add(const Duration(minutes: 24)),
          ),
        if (ticket.status == 'Resolved' || ticket.status == 'Closed')
          TicketTimelineEvent(
            id: '4',
            title: 'Issue Resolved',
            description:
                'Fix deployed and verified across synchronization services.',
            timestamp: ticket.updatedAt,
          ),
      ];
    });
  }

  List<TicketComment> _getCommentsForTicket(TicketModel ticket) {
    return _commentsMap.putIfAbsent(ticket.id, () {
      return [
        TicketComment(
          id: 'c1',
          authorName: 'Marcus Vance',
          authorRole: 'agent',
          message:
              'Hello! I have reviewed your submission regarding "${ticket.subject}". I am verifying the backend sync queue now.',
          timestamp: ticket.createdAt.add(const Duration(minutes: 10)),
        ),
      ];
    });
  }

  void _sendComment() {
    final text = _replyController.text.trim();
    if (text.isEmpty || _activeTicket == null) return;

    final comments = _getCommentsForTicket(_activeTicket!);
    setState(() {
      comments.add(
        TicketComment(
          id: 'c-${DateTime.now().millisecondsSinceEpoch}',
          authorName: 'You',
          authorRole: 'customer',
          message: text,
          timestamp: DateTime.now(),
        ),
      );
      _replyController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          List<TicketModel> allTickets = [];
          if (state is TicketLoaded) {
            allTickets = state.tickets;
          }

          // Check if initial ticket selection needs activation
          if (widget.initialTicketId != null &&
              _activeTicket == null &&
              allTickets.isNotEmpty) {
            final found = allTickets.where(
              (t) =>
                  t.id == widget.initialTicketId ||
                  t.ticketNumber == widget.initialTicketId,
            );
            if (found.isNotEmpty) {
              _activeTicket = found.first;
            }
          }

          if (_activeTicket != null) {
            return _buildDetailView(_activeTicket!);
          }

          return _buildListView(allTickets);
        },
      ),
    );
  }

  // ==========================================
  // 1. TICKET LIST VIEW
  // ==========================================
  Widget _buildListView(List<TicketModel> tickets) {
    const primaryIndigo = Color(0xFF4F46E5);

    final filtered = tickets.where((t) {
      final matchesStatus = _filterStatus == 'all' || t.status == _filterStatus;
      final matchesSearch =
          _searchQuery.isEmpty ||
          t.subject.toLowerCase().contains(_searchQuery) ||
          t.ticketNumber.toLowerCase().contains(_searchQuery) ||
          t.category.toLowerCase().contains(_searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Top Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Support Ticket History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          widget.onNavigateTab?.call(2), // Create Ticket
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryIndigo,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'New Ticket',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search tickets by ID, subject, category...',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal Status Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _statusFilters.map((st) {
                      final isSelected = _filterStatus == st;
                      final label = st == 'all' ? 'All' : st;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: InkWell(
                          onTap: () => setState(() => _filterStatus = st),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryIndigo
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // List Body
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 38,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No tickets found',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Try changing your search query or status filter.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ticket = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => setState(() => _activeTicket = ticket),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ticket.ticketNumber,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  _buildStatusBadge(ticket.status),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                ticket.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                ticket.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      ticket.category,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${ticket.updatedAt.month}/${ticket.updatedAt.day}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. TIMELINE & DETAIL VIEW
  // ==========================================
  Widget _buildDetailView(TicketModel ticket) {
    const primaryIndigo = Color(0xFF4F46E5);
    final timeline = _getTimelineForTicket(ticket);
    final comments = _getCommentsForTicket(ticket);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 26,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => setState(() => _activeTicket = null),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket.ticketNumber,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              ticket.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: Center(child: _buildStatusBadge(ticket.status)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(14.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetaItem(
                                'Category',
                                ticket.category,
                                isPill: true,
                              ),
                            ),
                            Expanded(
                              child: _buildMetaItem(
                                'Priority',
                                ticket.priority,
                                color: _getPriorityColor(ticket.priority),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetaItem(
                                'Assigned Agent',
                                'Marcus Vance',
                              ),
                            ),
                            Expanded(
                              child: _buildMetaItem(
                                'Last Updated',
                                '${ticket.updatedAt.month}/${ticket.updatedAt.day} ${ticket.updatedAt.hour}:${ticket.updatedAt.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 8),
                        const Text(
                          'Issue Description',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ticket.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Ticket Activity Timeline
                  Row(
                    children: const [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: primaryIndigo,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Ticket Activity Timeline',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Vertical Timeline Builder
                  Container(
                    padding: const EdgeInsets.only(left: 6),
                    child: Column(
                      children: List.generate(timeline.length, (index) {
                        final evt = timeline[index];
                        final isLast = index == timeline.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: primaryIndigo,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 1.5,
                                    height: 38,
                                    color: const Color(0xFFC7D2FE),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: isLast ? 0 : 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          evt.title,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '${evt.timestamp.hour}:${evt.timestamp.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      evt.description,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Conversation / Comments
                  Row(
                    children: const [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: primaryIndigo,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Conversation with Support Agent',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (comments.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'No replies yet. Marcus Vance is reviewing your request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    ...comments.map((cmt) {
                      final isAgent = cmt.authorRole == 'agent';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAgent
                              ? const Color(0xFFFFFBEB)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAgent
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      cmt.authorName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (isAgent) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        '(Support Staff)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${cmt.timestamp.hour}:${cmt.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cmt.message,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Bottom Reply Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Add additional information or reply...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _sendComment,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: primaryIndigo,
                        shape: BoxShape.circle,
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
          ),
        ],
      ),
    );
  }

  // --- Helper Badges ---
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Open':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'In Progress':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'Waiting for Customer':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF6D28D9);
        break;
      case 'Resolved':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        break;
      case 'Closed':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMetaItem(
    String label,
    String value, {
    bool isPill = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        if (isPill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return const Color(0xFFDC2626);
      case 'High':
        return const Color(0xFFD97706);
      case 'Medium':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF475569);
    }
  }
}
