import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool isSignIn = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _backgroundBlobController;
  late AnimationController _emojiBounceController;

  // Password Real-Time Validation Flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigits = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    _backgroundBlobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _emojiBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _passwordController.addListener(_validatePasswordRules);
  }

  void _validatePasswordRules() {
    final text = _passwordController.text;
    setState(() {
      _hasMinLength = text.length >= 8;
      _hasUppercase = text.contains(RegExp(r'[A-Z]'));
      _hasDigits = text.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_validatePasswordRules);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _backgroundBlobController.dispose();
    _emojiBounceController.dispose();
    super.dispose();
  }

  void _switchTab(bool signInSelected) {
    if (isSignIn == signInSelected) return;
    setState(() {
      isSignIn = signInSelected;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  void _onSignIn() {
    if (_signInFormKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        LoginSubmittedEvent(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        ),
      );
    }
  }

  void _onSignUp() {
    if (_signUpFormKey.currentState?.validate() ?? false) {
      final isStrong =
          _hasMinLength && _hasUppercase && _hasDigits && _hasSpecialChar;
      if (!isStrong) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please satisfy all strong password conditions below.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      context.read<AuthBloc>().add(
        RegisterSubmittedEvent(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF4F46E5);
    const slateBackground = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: slateBackground,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.message,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 20.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFriendlyHeader(primaryIndigo),
                        const SizedBox(height: 18),
                        _buildAuthCard(primaryIndigo),
                        const SizedBox(height: 16),
                        _buildFooterSecurityNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Background with Soft Blobs ---
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundBlobController,
      builder: (context, child) {
        final progress = _backgroundBlobController.value;
        final dx = math.sin(progress * 2 * math.pi) * 20;
        final dy = math.cos(progress * 2 * math.pi) * 15;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEEF2FF),
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -60 + dy,
              right: -50 + dx,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF818CF8).withValues(alpha: 0.22),
                      const Color(0xFFEEF2FF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60 - dy,
              left: -50 - dx,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA855F7).withValues(alpha: 0.16),
                      const Color(0xFFF8FAFC).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Brand Header with Animated Emoji ---
  Widget _buildFriendlyHeader(Color primaryIndigo) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/laurel_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        '{LSC}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -6,
              child: AnimatedBuilder(
                animation: _emojiBounceController,
                builder: (context, child) {
                  final bounce =
                      math.sin(_emojiBounceController.value * math.pi) * 4;
                  return Transform.translate(
                    offset: Offset(0, -bounce),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    isSignIn ? '👋' : '✨',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Laurel Desk',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          isSignIn
              ? 'Welcome back! Sign in to access your portal'
              : 'Register your account to manage tickets and sync',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // --- Auth Card ---
  Widget _buildAuthCard(Color primaryIndigo) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSegmentedTab(primaryIndigo),
          const SizedBox(height: 18),
          FadeTransition(
            opacity: _fadeAnimation,
            child: isSignIn
                ? _buildSignInForm(primaryIndigo)
                : _buildSignUpForm(primaryIndigo),
          ),
        ],
      ),
    );
  }

  // --- Segmented Switcher ---
  Widget _buildSegmentedTab(Color primaryIndigo) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _switchTab(true),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSignIn ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSignIn
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSignIn ? FontWeight.w700 : FontWeight.w600,
                    color: isSignIn
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _switchTab(false),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !isSignIn ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: !isSignIn
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: !isSignIn ? FontWeight.w700 : FontWeight.w600,
                    color: !isSignIn
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sign In Form ---
  Widget _buildSignInForm(Color primaryIndigo) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldLabel('Email'),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _emailController,
            hint: 'name@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your work email';
              }
              if (!val.contains('@') || !val.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Password'),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Password recovery instructions sent to registered email.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: primaryIndigo,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _passwordController,
            hint: '••••••••••••',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            validator: (val) => val == null || val.isEmpty
                ? 'Please enter your password'
                : val.length < 6
                ? 'Password must be at least 6 characters'
                : null,
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            label: 'Sign In to Support',
            onPressed: _onSignIn,
            color: primaryIndigo,
          ),
        ],
      ),
    );
  }

  // --- Sign Up Form ---
  Widget _buildSignUpForm(Color primaryIndigo) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Full Name
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _nameController,
            hint: 'Hammad Mehmood',
            icon: Icons.person_outline_rounded,
            validator: (val) => val == null || val.trim().isEmpty
                ? 'Please enter your full name'
                : null,
          ),
          const SizedBox(height: 12),

          // 2. Phone Number
          _buildFieldLabel('Phone Number'),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _phoneController,
            hint: '+92 300 1234567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              if (val.trim().length < 7) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 3. City / Country
          _buildFieldLabel('City / Country'),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _locationController,
            hint: 'Lahore, Pakistan',
            icon: Icons.location_on_outlined,
            validator: (val) => val == null || val.trim().isEmpty
                ? 'Please enter your city and country'
                : null,
          ),
          const SizedBox(height: 12),

          // 4. Work Email
          _buildFieldLabel('Email'),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _emailController,
            hint: 'name@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!val.contains('@') || !val.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 5. Strong Password
          _buildFieldLabel('Strong Password'),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _passwordController,
            hint: 'Min. 8 chars, 1 upper, 1 digit, 1 symbol',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Password is required';
              }
              if (val.length < 8) {
                return 'Must be at least 8 characters long';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Password Strength Requirements Badges
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password Requirements:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildRuleItem('8+ Chars', _hasMinLength),
                    _buildRuleItem('Uppercase (A-Z)', _hasUppercase),
                    _buildRuleItem('Number (0-9)', _hasDigits),
                    _buildRuleItem('Symbol (!@#\$)', _hasSpecialChar),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 6. Rewrite / Confirm Password
          _buildFieldLabel('Rewrite Password'),
          const SizedBox(height: 6),
          _buildInputField(
            controller: _confirmPasswordController,
            hint: 'Re-enter your password',
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please confirm your password';
              }
              if (val != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // CTA Submit
          _buildActionButton(
            label: 'Create Account',
            onPressed: _onSignUp,
            color: primaryIndigo,
          ),
        ],
      ),
    );
  }

  // --- Helper: Password Rule Badge ---
  Widget _buildRuleItem(String text, bool met) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 13,
          color: met ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: met ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  // --- Helper: Field Label ---
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  // --- Helper: Input Field ---
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscureText : false,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }

  // --- Helper: Action Button ---
  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 13),
            elevation: 1.5,
            shadowColor: color.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
        );
      },
    );
  }

  // --- Helper: Footer Note ---
  Widget _buildFooterSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.lock_rounded, size: 12, color: Color(0xFF94A3B8)),
        SizedBox(width: 5),
        Text(
          'Protected by industry-standard encryption',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
