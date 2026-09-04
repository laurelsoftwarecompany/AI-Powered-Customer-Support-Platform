import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../auth/data/user_model.dart';
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

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF4F46E5);

    final screens = [
      DashboardContent(
        user: widget.user,
        onNavigateTab: (index) => setState(() {
          _isLiveAgentMode = false;
          _currentIndex = index;
        }),
      ),
      AIChatScreen(
        user: widget.user,
        isLiveAgent: _isLiveAgentMode,
        onBack: () => setState(() {
          _isLiveAgentMode = false;
          _currentIndex = 0;
        }),
        onLogTicket: () => setState(() => _currentIndex = 2),
      ),
      CreateTicketScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onSuccess: () => setState(() => _currentIndex = 3),
      ),
      TicketListScreen(
        onNavigateTab: (index) => setState(() {
          _isLiveAgentMode = false;
          _currentIndex = index;
        }),
      ),
      AlertsScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
      ProfileScreen(
        user: widget.user,
        onBack: () => setState(() => _currentIndex = 0),
      ),
      KnowledgeScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: screens[_currentIndex]),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final progress = _animController.value;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Animated Home Pill
                _buildAnimatedNavPill(
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

                // 2. Animated Tickets Pill
                _buildAnimatedNavPill(
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

                // 3. Animated Ask AI Robot Pill
                _buildAnimatedNavPill(
                  isSelected: _currentIndex == 1 && !_isLiveAgentMode,
                  label: 'Ask AI',
                  primaryColor: primaryPurple,
                  iconWidget: CustomPaint(
                    size: const Size(20, 20),
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

                // 4. Animated Live Agent Pill
                _buildAnimatedNavPill(
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
                  onTap: () {
                    LiveAgentWaitingSheet.show(
                      context,
                      onProceedToChat: () {
                        setState(() {
                          _isLiveAgentMode = true;
                          _currentIndex = 1;
                        });
                      },
                    );
                  },
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
        ? math.sin(_animController.value * 2 * math.pi) * 2.2
        : 0.0;

    return Transform.translate(
      offset: Offset(0, -bounce),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF818CF8)
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasLiveBeacon && !isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              iconWidget,
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.1,
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
    final mainColor = isSelected ? Colors.white : const Color(0xFF475569);

    final linePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = isSelected
          ? Colors.white.withValues(alpha: 0.25)
          : const Color(0xFFEEF2FF)
      ..style = PaintingStyle.fill;

    final chimneyFloat = math.sin(progress * 2 * math.pi) * 1.5;

    // Roof Path
    final roof = Path()
      ..moveTo(cx - 8, cy + 1)
      ..lineTo(cx, cy - 7)
      ..lineTo(cx + 8, cy + 1);
    canvas.drawPath(roof, linePaint);

    // Chimney
    canvas.drawLine(
      Offset(cx + 5, cy - 3),
      Offset(cx + 5, cy - 7),
      linePaint..strokeWidth = 1.6,
    );

    // Animated Cozy Smoke Dot
    canvas.drawCircle(
      Offset(cx + 5, cy - 8.5 + chimneyFloat),
      1.1,
      Paint()
        ..color = isSelected ? const Color(0xFFFDE047) : const Color(0xFF818CF8)
        ..style = PaintingStyle.fill,
    );

    // House Base
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 6, cy, 12, 8),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(baseRect, fillPaint);
    canvas.drawRRect(baseRect, linePaint..strokeWidth = 1.8);

    // Warm Doorway
    final doorRect = Rect.fromLTWH(cx - 2, cy + 3.5, 4, 4.5);
    canvas.drawRect(
      doorRect,
      Paint()
        ..color = isSelected ? Colors.white : const Color(0xFF4F46E5)
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
// 🎟️ 2. TICKET PAINTER
// ==========================================
class _PookieTicketPainter extends CustomPainter {
  final double progress;
  final bool isSelected;

  _PookieTicketPainter({required this.progress, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final mainColor = isSelected ? Colors.white : const Color(0xFF475569);

    final linePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = isSelected
          ? Colors.white.withValues(alpha: 0.22)
          : const Color(0xFFEEF2FF)
      ..style = PaintingStyle.fill;

    // Ticket Outline with Notch Cuts
    final ticket = Path()
      ..moveTo(cx - 8, cy - 5.5)
      ..lineTo(cx + 8, cy - 5.5)
      ..arcToPoint(
        Offset(cx + 8, cy + 5.5),
        radius: const Radius.circular(2.5),
        clockwise: true,
      )
      ..lineTo(cx - 8, cy + 5.5)
      ..arcToPoint(
        Offset(cx - 8, cy - 5.5),
        radius: const Radius.circular(2.5),
        clockwise: true,
      );

    canvas.drawPath(ticket, fillPaint);
    canvas.drawPath(ticket, linePaint);

    // Side cutouts
    canvas.drawCircle(Offset(cx - 8, cy), 1.6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + 8, cy), 1.6, Paint()..color = Colors.white);

    // Perforation / Star shimmer in center
    final shimmer = (math.sin(progress * 2 * math.pi) + 1) / 2;
    canvas.drawLine(
      Offset(cx, cy - 3.5),
      Offset(cx, cy + 3.5),
      Paint()
        ..color = isSelected
            ? Colors.white.withValues(alpha: 0.6 + (shimmer * 0.4))
            : const Color(0xFF818CF8)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PookieTicketPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSelected != isSelected;
  }
}

// ==========================================
// 🤖 3. POOKIE ROBOT PAINTER (AI BOT)
// ==========================================
class _PookieRobotPainter extends CustomPainter {
  final double progress;
  final bool isSelected;

  _PookieRobotPainter({required this.progress, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 1;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final blushPaint = Paint()
      ..color = const Color(0xFFFDA4AF)
      ..style = PaintingStyle.fill;

    final screenPaint = Paint()
      ..color = const Color(0xFF1E1B4B)
      ..style = PaintingStyle.fill;

    final eyePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;

    final antennaWiggle = math.sin(progress * 2 * math.pi) * 1.5;

    // Antenna Stick
    canvas.drawLine(
      Offset(cx, cy - 6),
      Offset(cx + antennaWiggle, cy - 10),
      Paint()
        ..color = isSelected ? Colors.white : const Color(0xFF64748B)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // Glowing Antenna Tip
    canvas.drawCircle(
      Offset(cx + antennaWiggle, cy - 10),
      2.0,
      Paint()
        ..color = const Color(0xFFFDE047)
        ..style = PaintingStyle.fill,
    );

    // Head Body
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 17, height: 13),
      const Radius.circular(5),
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
      Rect.fromCenter(center: Offset(cx, cy), width: 13, height: 9),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(visorRect, screenPaint);

    // Blinking Cyan Eyes
    final isBlinking = (progress > 0.45 && progress < 0.55);
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

    // Cheeks
    canvas.drawCircle(Offset(cx - 4.5, cy + 2.5), 1.0, blushPaint);
    canvas.drawCircle(Offset(cx + 4.5, cy + 2.5), 1.0, blushPaint);
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
    final mainColor = isSelected ? Colors.white : const Color(0xFF475569);

    final linePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = isSelected
          ? Colors.white.withValues(alpha: 0.25)
          : const Color(0xFFEEF2FF)
      ..style = PaintingStyle.fill;

    // Specialist Head
    canvas.drawCircle(Offset(cx, cy - 1), 4.2, fillPaint);
    canvas.drawCircle(Offset(cx, cy - 1), 4.2, linePaint);

    // Headset Arc
    final headsetArc = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(cx, cy - 1), radius: 5.4),
        math.pi * 0.9,
        math.pi * 1.2,
      );
    canvas.drawPath(
      headsetArc,
      Paint()
        ..color = isSelected ? const Color(0xFFFDE047) : const Color(0xFF4F46E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Headset Microphone Tip
    final micPulse = math.sin(progress * 2 * math.pi) * 0.8;
    canvas.drawCircle(
      Offset(cx + 4.5, cy + 2.5 + micPulse),
      1.2,
      Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill,
    );

    // Shoulders
    final shoulders = Path()
      ..moveTo(cx - 6.5, cy + 8)
      ..quadraticBezierTo(cx, cy + 4, cx + 6.5, cy + 8);
    canvas.drawPath(shoulders, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PookieAgentPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSelected != isSelected;
  }
}
