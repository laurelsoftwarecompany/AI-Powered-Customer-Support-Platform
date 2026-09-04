import 'package:flutter/material.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final String
  type; // 'ticket_reply', 'status_change', 'agent_takeover', 'ai_escalation', etc.
  final DateTime timestamp;
  bool read;
  final String? ticketId;
  final String? conversationId;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.read = false,
    this.ticketId,
    this.conversationId,
  });
}

class AlertsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(int tabIndex)? onNavigateTab;

  const AlertsScreen({super.key, this.onBack, this.onNavigateTab});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AppNotificationModel> _notifications = [
    AppNotificationModel(
      id: 'notif-1',
      title: 'New Reply on Ticket #TICK-802',
      message:
          'Support staff sent a troubleshooting message regarding your session.',
      type: 'ticket_reply',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      read: false,
      ticketId: '1',
    ),
    AppNotificationModel(
      id: 'notif-2',
      title: 'Agent Assigned to Ticket #TICK-802',
      message:
          'Marcus Vance was assigned to investigate your password reset issue.',
      type: 'agent_takeover',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      read: false,
      ticketId: '1',
    ),
    AppNotificationModel(
      id: 'notif-3',
      title: 'Ticket #TICK-799 Resolved',
      message:
          'Your billing refund request was successfully approved and closed.',
      type: 'status_change',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      read: true,
      ticketId: '3',
    ),
    AppNotificationModel(
      id: 'notif-4',
      title: 'AI Chat Escalated',
      message:
          'Your chat session regarding sync endpoints has been linked to a support ticket.',
      type: 'ai_escalation',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      read: true,
      conversationId: 'conv-1',
    ),
  ];

  void _markAllAsRead() {
    setState(() {
      for (var notif in _notifications) {
        notif.read = true;
      }
    });
  }

  Widget _getNotificationIcon(String type, bool isRead) {
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'ticket_reply':
        icon = Icons.chat_bubble_outline_rounded;
        iconColor = const Color(0xFF2563EB);
        break;
      case 'status_change':
        icon = Icons.error_outline_rounded;
        iconColor = const Color(0xFF059669);
        break;
      case 'agent_takeover':
        icon = Icons.headset_mic_outlined;
        iconColor = const Color(0xFFD97706);
        break;
      case 'ai_escalation':
        icon = Icons.auto_awesome;
        iconColor = const Color(0xFF7C3AED);
        break;
      default:
        icon = Icons.notifications_none_rounded;
        iconColor = const Color(0xFF4F46E5);
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: !isRead ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF4F46E5);
    const bgColor = Color(0xFFF8FAFC);

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
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(
                Icons.done_all_rounded,
                size: 15,
                color: primaryIndigo,
              ),
              label: const Text(
                'Mark All Read',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primaryIndigo,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 40,
                        color: Color(0xFFCBD5E1),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No new notifications',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'You\'re all caught up with your support updates.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isUnread = !notif.read;

                return InkWell(
                  onTap: () {
                    setState(() => notif.read = true);
                    if (notif.ticketId != null) {
                      widget.onNavigateTab?.call(3); // Go to Tickets tab
                    } else if (notif.conversationId != null) {
                      widget.onNavigateTab?.call(1); // Go to Chat tab
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnread ? Colors.white : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUnread
                            ? const Color(0xFFC7D2FE)
                            : const Color(0xFFE2E8F0),
                        width: isUnread ? 1.2 : 1,
                      ),
                      boxShadow: isUnread
                          ? [
                              BoxShadow(
                                color: primaryIndigo.withAlpha(12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _getNotificationIcon(notif.type, notif.read),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isUnread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${notif.timestamp.hour.toString().padLeft(2, '0')}:${notif.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                notif.message,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
