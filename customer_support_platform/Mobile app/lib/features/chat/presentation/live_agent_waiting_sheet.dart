import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../tickets/data/ticket_model.dart';
import '../../tickets/data/ticket_repository.dart';

class LiveAgentWaitingSheet extends StatefulWidget {
  final Function(TicketModel? selectedTicket) onProceedToChat;
  final Function(TicketModel ticket)? onViewTicketDetails;
  final TicketModel? initialSelectedTicket;

  const LiveAgentWaitingSheet({
    super.key,
    required this.onProceedToChat,
    this.onViewTicketDetails,
    this.initialSelectedTicket,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(TicketModel? selectedTicket) onProceedToChat,
    Function(TicketModel ticket)? onViewTicketDetails,
    TicketModel? initialSelectedTicket,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveAgentWaitingSheet(
        onProceedToChat: onProceedToChat,
        onViewTicketDetails: onViewTicketDetails,
        initialSelectedTicket: initialSelectedTicket,
      ),
    );
  }

  @override
  State<LiveAgentWaitingSheet> createState() => _LiveAgentWaitingSheetState();
}

class _LiveAgentWaitingSheetState extends State<LiveAgentWaitingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  bool _isLoading = true;
  String? _errorMessage;
  List<TicketModel> _openTickets = [];
  TicketModel? _selectedTicket;
  bool _isNewInquiry = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchOpenTickets();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchOpenTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<TicketRepository>();
      final allTickets = await repository.fetchTickets();
      if (!mounted) return;

      // Filter to active/open tickets (not resolved or closed)
      final open = allTickets.where((t) {
        final st = t.status.trim().toLowerCase();
        return st != 'resolved' && st != 'closed';
      }).toList();

      setState(() {
        _openTickets = open;
        _isLoading = false;

        // Auto-select initial ticket if passed, otherwise default to first open ticket
        if (widget.initialSelectedTicket != null) {
          final match = _openTickets.where(
            (t) => t.id == widget.initialSelectedTicket!.id,
          );
          if (match.isNotEmpty) {
            _selectedTicket = match.first;
            _isNewInquiry = false;
          } else {
            _selectedTicket = _openTickets.isNotEmpty ? _openTickets.first : null;
            _isNewInquiry = _openTickets.isEmpty;
          }
        } else if (_openTickets.isNotEmpty) {
          _selectedTicket = _openTickets.first;
          _isNewInquiry = false;
        } else {
          _selectedTicket = null;
          _isNewInquiry = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isNewInquiry = true;
      });
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  Color _statusColor(String status) {
    final st = status.toLowerCase();
    if (st == 'open') return const Color(0xFF10B981);
    if (st == 'in progress') return const Color(0xFF3B82F6);
    if (st.contains('waiting')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  Color _statusBgColor(String status) {
    final st = status.toLowerCase();
    if (st == 'open') return const Color(0xFFECFDF5);
    if (st == 'in progress') return const Color(0xFFEFF6FF);
    if (st.contains('waiting')) return const Color(0xFFFFFBEB);
    return const Color(0xFFF1F5F9);
  }

  Color _priorityColor(String priority) {
    final p = priority.toLowerCase();
    if (p == 'urgent') return const Color(0xFFEF4444);
    if (p == 'high') return const Color(0xFFF97316);
    if (p == 'medium') return const Color(0xFF4F46E5);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF4F46E5);
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ScaleTransition(
                          scale: _pulseScale,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFC7D2FE),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.support_agent_rounded,
                                color: primaryIndigo,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Talk to a Support Specialist",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Select which open ticket you want to talk about",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // Queue & Availability Status Pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                          SizedBox(width: 6),
                          Text(
                            "Specialist Available",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.confirmation_number_outlined, size: 13, color: primaryIndigo),
                          const SizedBox(width: 4),
                          Text(
                            _isLoading
                                ? "Loading tickets..."
                                : "${_openTickets.length} Open ${_openTickets.length == 1 ? 'Ticket' : 'Tickets'}",
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: primaryIndigo,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),

              // Main Content: Ticket Selection List
              Expanded(
                child: _buildBodyContent(primaryIndigo),
              ),

              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Stay Here",
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: (_selectedTicket == null && !_isNewInquiry)
                            ? null
                            : () {
                                Navigator.pop(context);
                                if (_selectedTicket != null) {
                                  widget.onProceedToChat(_selectedTicket);
                                } else {
                                  widget.onProceedToChat(null);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryIndigo,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFC7D2FE),
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedTicket != null
                                  ? "Chat About ${_selectedTicket!.ticketNumber}"
                                  : "Start New Chat",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 15),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(Color primaryIndigo) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            SizedBox(height: 14),
            Text(
              "Retrieving your open tickets...",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _openTickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 36),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _fetchOpenTickets,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      children: [
        // Section 1: Open Tickets
        Row(
          children: [
            const Text(
              "YOUR OPEN TICKETS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${_openTickets.length}",
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_openTickets.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.inbox_outlined, color: Color(0xFF94A3B8), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You do not have any open tickets right now. You can start a new live inquiry below!",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ..._openTickets.map((ticket) => _buildTicketCard(ticket, primaryIndigo)),

        const SizedBox(height: 16),

        // Section 2: General live inquiry option
        const Text(
          "OR START A FRESH INQUIRY",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        _buildNewInquiryCard(primaryIndigo),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTicketCard(TicketModel ticket, Color primaryIndigo) {
    final isSelected = !_isNewInquiry && _selectedTicket?.id == ticket.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF5F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? primaryIndigo : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryIndigo.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedTicket = ticket;
              _isNewInquiry = false;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Radio indicator
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? primaryIndigo : const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                    const SizedBox(width: 10),

                    // Ticket number
                    Text(
                      ticket.ticketNumber,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? primaryIndigo : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusBgColor(ticket.status),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ticket.status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(ticket.status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Priority pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _priorityColor(ticket.priority).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ticket.priority,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _priorityColor(ticket.priority),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Relative updated time
                    Text(
                      _formatRelativeTime(ticket.updatedAt),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Ticket Subject
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Text(
                    ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Category & View details shortcut
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ticket.category,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (widget.onViewTicketDetails != null)
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onViewTicketDetails!(ticket);
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  "View Details",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF4F46E5)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewInquiryCard(Color primaryIndigo) {
    final isSelected = _isNewInquiry;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF5F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? primaryIndigo : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryIndigo.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isNewInquiry = true;
              _selectedTicket = null;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? primaryIndigo : const Color(0xFFCBD5E1),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: primaryIndigo,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Start a New Live Support Chat",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Connect regarding a new inquiry or general question",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
