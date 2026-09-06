import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/data/user_model.dart';
import '../../tickets/data/ticket_model.dart';
import '../../tickets/presentation/create_ticket_screen.dart';
import '../../tickets/presentation/ticket_list_screen.dart';
import 'dashboard_screen.dart';
import '../../chat/presentation/ai_chat_screen.dart';
import '../../chat/presentation/live_agent_waiting_sheet.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';
import 'knowledge_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel? user;

  const MainNavigationScreen({super.key, this.user});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isLiveAgentMode = false;
  String? _selectedTicketId;
  TicketModel? _activeLiveTicket;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showLiveAgentSelector(BuildContext context) {
    LiveAgentWaitingSheet.show(
      context,
      initialSelectedTicket: _activeLiveTicket,
      onProceedToChat: (selectedTicket) {
        setState(() {
          _activeLiveTicket = selectedTicket;
          _isLiveAgentMode = true;
          _currentIndex = 1;
        });
      },
      onViewTicketDetails: (ticket) {
        setState(() {
          _selectedTicketId = ticket.id;
          _isLiveAgentMode = false;
          _currentIndex = 3;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF4F46E5);

    final authState = context.watch<AuthBloc>().state;
    final currentUser =
        (authState is Authenticated) ? authState.user : widget.user;

    final screens = [
      DashboardContent(
        user: currentUser,
        onNavigateTab: (index) => setState(() {
          _isLiveAgentMode = false;
          _currentIndex = index;
        }),
      ),
      AIChatScreen(
        user: currentUser,
        isLiveAgent: _isLiveAgentMode,
        ticket: _activeLiveTicket,
        onChangeTicket: () => _showLiveAgentSelector(context),
        onBack: () => setState(() {
          _isLiveAgentMode = false;
          _activeLiveTicket = null;
          _currentIndex = 0;
        }),
        onLogTicket: () => setState(() => _currentIndex = 2),
        onOpenTicket: (ticketId) => setState(() {
          _selectedTicketId = ticketId;
          _isLiveAgentMode = false;
          _currentIndex = 3;
        }),
      ),
      CreateTicketScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onSuccess: () => setState(() => _currentIndex = 3),
      ),
      TicketListScreen(
        key: ValueKey(_selectedTicketId ?? 'ticket_list'),
        initialTicketId: _selectedTicketId,
        onNavigateTab: (index) => setState(() {
          _selectedTicketId = null;
          _isLiveAgentMode = (index == 1);
          _currentIndex = index;
        }),
        onOpenLiveChat: (ticket) => setState(() {
          _selectedTicketId = null;
          _activeLiveTicket = ticket;
          _isLiveAgentMode = true;
          _currentIndex = 1;
        }),
      ),
      AlertsScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
      ProfileScreen(
        user: currentUser,
        onBack: () => setState(() => _currentIndex = 0),
      ),
      KnowledgeScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final progress = _animController.value;

            return Row(
              children: [
                // 1. Animated Home Pill
                Expanded(
                  child: _buildAnimatedNavPill(
                    isSelected: _currentIndex == 0,
                    label: 'Home',
                    primaryColor: primaryPurple,
                    iconWidget: CustomPaint(
                      size: const Size(20, 20),
                      painter: _PookieHomePainter(
                        progress: progress,
                        isSelected: _currentIndex == 0,
                      ),
                    ),
                    onTap: () => setState(() {
                      _isLiveAgentMode = false;
                      _currentIndex = 0;
                    }),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Animated Tickets Pill
                Expanded(
                  child: _buildAnimatedNavPill(
                    isSelected: _currentIndex == 3,
                    label: 'Tickets',
                    primaryColor: primaryPurple,
                    iconWidget: CustomPaint(
                      size: const Size(20, 20),
                      painter: _PookieTicketPainter(
                        progress: progress,
                        isSelected: _currentIndex == 3,
                      ),
                    ),
                    onTap: () => setState(() {
                      _isLiveAgentMode = false;
                      _currentIndex = 3;
                    }),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Animated Ask AI Robot Pill
                Expanded(
                  child: _buildAnimatedNavPill(
                    isSelected: _currentIndex == 1 && !_isLiveAgentMode,
                    label: 'Ask AI',
                    primaryColor: primaryPurple,
                    iconWidget: CustomPaint(
                      size: const Size(22, 22),
                      painter: _PookieRobotPainter(
                        progress: progress,
                        isSelected: _currentIndex == 1 && !_isLiveAgentMode,
                      ),
                    ),
                    onTap: () => setState(() {
                      _isLiveAgentMode = false;
                      _currentIndex = 1;
                    }),
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Animated Live Agent Pill
                Expanded(
                  child: _buildAnimatedNavPill(
                    isSelected: _currentIndex == 1 && _isLiveAgentMode,
                    label: 'Live Agent',
                    primaryColor: primaryPurple,
                    hasLiveBeacon: true,
                    iconWidget: CustomPaint(
                      size: const Size(20, 20),
                      painter: _PookieAgentPainter(
                        progress: progress,
                        isSelected: _currentIndex == 1 && _isLiveAgentMode,
                      ),
                    ),
                    onTap: () => _showLiveAgentSelector(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Unified Responsive Pill Container with Lift and Hover
  Widget _buildAnimatedNavPill({
    required bool isSelected,
    required String label,
    required Color primaryColor,
    required Widget iconWidget,
    required VoidCallback onTap,
    bool hasLiveBeacon = false,
  }) {
    final bounce = isSelected
        ? math.sin(_animController.value * 2 * math.pi) * 1.5
        : 0.0;

    return Transform.translate(
      offset: Offset(0, -bounce),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 46,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              if (hasLiveBeacon) ...[
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              iconWidget,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🏠 1. HOME PAINTER
// ==========================================
class _PookieHomePainter extends CustomPainter {
  final double progress;
  final bool isSelected;

  _PookieHomePainter({required this.progress, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final strokeColor = isSelected ? Colors.white : const Color(0xFF334155);

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Roof Path
    final roof = Path()
      ..moveTo(cx - 8, cy + 1)
      ..lineTo(cx, cy - 6.5)
      ..lineTo(cx + 8, cy + 1);
    canvas.drawPath(roof, linePaint);

    // Chimney
    canvas.drawLine(
      Offset(cx + 4.5, cy - 2.8),
      Offset(cx + 4.5, cy - 6),
      linePaint..strokeWidth = 1.5,
    );

    // House Base
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 6, cy + 0.5, 12, 7.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(baseRect, linePaint..strokeWidth = 1.7);

    // Doorway
    final doorRect = Rect.fromLTWH(cx - 2, cy + 3.5, 4, 4.5);
    canvas.drawRect(
      doorRect,
      Paint()
        ..color = isSelected ? Colors.white : const Color(0xFF334155)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PookieHomePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSelected != isSelected;
  }
}

// ==========================================
// 🎟️ 2. TICKET PAINTER (Capsule Split Token)
// ==========================================
class _PookieTicketPainter extends CustomPainter {
  final double progress;
  final bool isSelected;

  _PookieTicketPainter({required this.progress, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final strokeColor = isSelected ? Colors.white : const Color(0xFF334155);

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Capsule / Pill shape: width 19, height 10, radius 5
    final capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 19, height: 10),
      const Radius.circular(5),
    );
    canvas.drawRRect(capsule, linePaint);

    // Center vertical dividing line
    canvas.drawLine(
      Offset(cx, cy - 4.5),
      Offset(cx, cy + 4.5),
      linePaint..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _PookieTicketPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSelected != isSelected;
  }
}

// ==========================================
// 🤖 3. POOKIE ROBOT PAINTER (AI BOT WITH SPARK STAR)
// ==========================================
class _PookieRobotPainter extends CustomPainter {
  final double progress;
  final bool isSelected;

  _PookieRobotPainter({required this.progress, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 1.2;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final screenPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final eyePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;

    final antennaWiggle = math.sin(progress * 2 * math.pi) * 1.0;

    // Antenna Stick
    canvas.drawLine(
      Offset(cx, cy - 6),
      Offset(cx + antennaWiggle, cy - 10),
      Paint()
        ..color = isSelected ? Colors.white : const Color(0xFF64748B)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // Glowing Antenna Sparkle / Star (Yellow)
    _drawStar(
      canvas,
      Offset(cx + antennaWiggle, cy - 10.5),
      4,
      2.6,
      1.3,
      Paint()
        ..color = const Color(0xFFFACC15)
        ..style = PaintingStyle.fill,
    );

    // Head Body
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 17, height: 12),
      const Radius.circular(4),
    );
    canvas.drawRRect(headRect, whitePaint);

    if (!isSelected) {
      canvas.drawRRect(
        headRect,
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Visor Screen
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 13, height: 8),
      const Radius.circular(2.6),
    );
    canvas.drawRRect(visorRect, screenPaint);

    // Blinking Cyan Eyes
    final isBlinking = (progress > 0.46 && progress < 0.54);
    final eyeHeight = isBlinking ? 0.6 : 2.2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - 3.2, cy - 0.2),
          width: 2.2,
          height: eyeHeight,
        ),
        const Radius.circular(1),
      ),
      eyePaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + 3.2, cy - 0.2),
          width: 2.2,
          height: eyeHeight,
        ),
        const Radius.circular(1),
      ),
      eyePaint,
    );
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    int points,
    double outerRadius,
    double innerRadius,
    Paint paint,
  ) {
    final path = Path();
    final step = math.pi / points;
    for (int i = 0; i < 2 * points; i++) {
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final angle = i * step - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PookieRobotPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSelected != isSelected;
  }
}

// ==========================================
// 🎧 4. LIVE AGENT SPECIALIST PAINTER
// ==========================================
class _PookieAgentPainter extends CustomPainter {
  final double progress;
  final bool isSelected;

  _PookieAgentPainter({required this.progress, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final strokeColor = isSelected ? Colors.white : const Color(0xFF334155);

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Specialist Head
    canvas.drawCircle(
      Offset(cx, cy - 1.5),
      3.8,
      Paint()
        ..color = isSelected
            ? Colors.white.withValues(alpha: 0.25)
            : const Color(0xFFEEF2FF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(cx, cy - 1.5), 3.8, linePaint);

    // Headset Arc
    final headsetArc = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(cx, cy - 1.5), radius: 5.0),
        math.pi * 0.9,
        math.pi * 1.2,
      );
    canvas.drawPath(
      headsetArc,
      Paint()
        ..color = isSelected ? const Color(0xFFFDE047) : const Color(0xFF4F46E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Headset mic / ear cup
    canvas.drawCircle(
      Offset(cx + 4.2, cy + 1.5),
      1.1,
      Paint()
        ..color = isSelected ? Colors.white : const Color(0xFF4F46E5)
        ..style = PaintingStyle.fill,
    );

    // Shoulders
    final shoulders = Path()
      ..moveTo(cx - 6.5, cy + 7.5)
      ..quadraticBezierTo(cx, cy + 3.5, cx + 6.5, cy + 7.5);
    canvas.drawPath(shoulders, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PookieAgentPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSelected != isSelected;
  }
}
