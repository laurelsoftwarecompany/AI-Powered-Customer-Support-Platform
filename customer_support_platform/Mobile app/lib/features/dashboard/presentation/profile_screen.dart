import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onBack;

  const ProfileScreen({super.key, this.user, this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _currentName;
  late String _currentPhone;
  late String _currentLocation;
  late String _currentOrg;

  @override
  void initState() {
    super.initState();
    _populateUserData();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user && widget.user != null) {
      _populateUserData();
    }
  }

  void _populateUserData() {
    _currentName = widget.user?.name ?? '';
    _currentPhone = widget.user?.phone ?? '';
    _currentLocation = widget.user?.location ?? '';
    _currentOrg = widget.user?.organization ?? '';
  }

  // --- Modal: Edit Profile ---
  void _openEditProfileModal() {
    final nameCtrl = TextEditingController(text: _currentName);
    final phoneCtrl = TextEditingController(text: _currentPhone);
    final locationCtrl = TextEditingController(text: _currentLocation);
    final orgCtrl = TextEditingController(text: _currentOrg);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Edit Profile Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Full Name'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: nameCtrl,
                      icon: Icons.person_outline_rounded,
                      hint: 'Full Name',
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Name cannot be empty'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Organization / Company'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: orgCtrl,
                      icon: Icons.business_outlined,
                      hint: 'Organization or Company Name',
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('Phone Number'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: phoneCtrl,
                      icon: Icons.phone_outlined,
                      hint: '+1 (555) 000-0000',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel('City / Country'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: locationCtrl,
                      icon: Icons.location_on_outlined,
                      hint: 'e.g. Chicago, United States',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (formKey.currentState?.validate() ?? false) {
                                      setModalState(() => isSaving = true);
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        final authRepo =
                                            context.read<AuthRepository>();
                                        final authBloc =
                                            context.read<AuthBloc>();
                                        final updated =
                                            await authRepo.updateProfile(
                                          name: nameCtrl.text.trim(),
                                          phone: phoneCtrl.text.trim(),
                                          location: locationCtrl.text.trim(),
                                          organization: orgCtrl.text.trim(),
                                        );

                                        if (!mounted) return;
                                        setState(() {
                                          _currentName = updated.name;
                                          _currentPhone = updated.phone ?? '';
                                          _currentLocation =
                                              updated.location ?? '';
                                          _currentOrg =
                                              updated.organization ?? '';
                                        });

                                        authBloc.add(UpdateUserEvent(updated));

                                        if (ctx.mounted) Navigator.pop(ctx);
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Profile details updated successfully!',
                                            ),
                                            backgroundColor:
                                                const Color(0xFF10B981),
                                            behavior:
                                                SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setModalState(() => isSaving = false);
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceAll(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                              ),
                                              backgroundColor:
                                                  const Color(0xFFDC2626),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Modal: Change Password with Current Password Verification ---
  void _openChangePasswordModal() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    bool hasMinLength = false;
    bool hasUppercase = false;
    bool hasDigits = false;
    bool hasSpecialChar = false;
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void validatePassword(String text) {
            setModalState(() {
              hasMinLength = text.length >= 8;
              hasUppercase = text.contains(RegExp(r'[A-Z]'));
              hasDigits = text.contains(RegExp(r'[0-9]'));
              hasSpecialChar = text.contains(
                RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
              );
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Update Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Verify your current password to set a new one.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Current Password Field
                      _buildFieldLabel('Current Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: currentPassCtrl,
                        obscureText: obscureCurrent,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: _modalInputDecoration(
                          hint: 'Enter your existing password',
                          icon: Icons.lock_clock_outlined,
                          isPassword: true,
                          obscureText: obscureCurrent,
                          onToggleVisibility: () => setModalState(
                            () => obscureCurrent = !obscureCurrent,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please enter your current password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. New Password Field
                      _buildFieldLabel('New Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: newPassCtrl,
                        obscureText: obscureNew,
                        onChanged: validatePassword,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: _modalInputDecoration(
                          hint: 'Min. 8 chars, 1 upper, 1 digit, 1 symbol',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          obscureText: obscureNew,
                          onToggleVisibility: () =>
                              setModalState(() => obscureNew = !obscureNew),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please enter a new password';
                          }
                          if (val == currentPassCtrl.text) {
                            return 'New password cannot be the same as current';
                          }
                          if (val.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Password Rules Badges
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildRuleItem('8+ Chars', hasMinLength),
                            _buildRuleItem('Uppercase (A-Z)', hasUppercase),
                            _buildRuleItem('Number (0-9)', hasDigits),
                            _buildRuleItem('Symbol (!@#\$)', hasSpecialChar),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Confirm New Password Field
                      _buildFieldLabel('Confirm New Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: confirmPassCtrl,
                        obscureText: obscureConfirm,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: _modalInputDecoration(
                          hint: 'Re-enter your new password',
                          icon: Icons.lock_reset_rounded,
                          isPassword: true,
                          obscureText: obscureConfirm,
                          onToggleVisibility: () => setModalState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please confirm your new password';
                          }
                          if (val != newPassCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isUpdating
                                  ? null
                                  : () async {
                                      final isStrong =
                                          hasMinLength &&
                                          hasUppercase &&
                                          hasDigits &&
                                          hasSpecialChar;

                                      if (!isStrong) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Please satisfy all 4 new password rules',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            backgroundColor:
                                                const Color(0xFFDC2626),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (formKey.currentState?.validate() ?? false) {
                                        setModalState(() => isUpdating = true);
                                        final messenger = ScaffoldMessenger.of(context);
                                        try {
                                          final authRepo =
                                              context.read<AuthRepository>();
                                          await authRepo.changePassword(
                                            currentPassword:
                                                currentPassCtrl.text,
                                            newPassword: newPassCtrl.text,
                                          );

                                          if (ctx.mounted) Navigator.pop(ctx);
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Password updated securely!',
                                              ),
                                              backgroundColor:
                                                  const Color(0xFF10B981),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            setModalState(
                                                () => isUpdating = false);
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceAll(
                                                        'Exception: ',
                                                        '',
                                                      ),
                                                ),
                                                backgroundColor:
                                                    const Color(0xFFDC2626),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isUpdating
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Update Password',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF4F46E5);
    const bgColor = Color(0xFFF8FAFC);

    final displayEmail = (widget.user?.email.isNotEmpty ?? false)
        ? widget.user!.email
        : 'customer@workspace.com';

    // Format role dynamically
    String displayRole;
    switch (widget.user?.role.toLowerCase()) {
      case 'admin':
        displayRole = 'Administrator';
        break;
      case 'agent':
        displayRole = 'Support Agent';
        break;
      case 'customer':
      default:
        displayRole = 'Customer';
        break;
    }

    final displayOrg = _currentOrg.isNotEmpty
        ? _currentOrg
        : (widget.user?.organization?.isNotEmpty ?? false
            ? widget.user!.organization!
            : 'Personal Account');

    final displayPhone = _currentPhone.isNotEmpty ? _currentPhone : 'Not provided';
    final displayLocation =
        _currentLocation.isNotEmpty ? _currentLocation : 'Not provided';

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
          'Profile & Account',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Text(
                      _currentName.isNotEmpty
                          ? _currentName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryIndigo,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentName.isNotEmpty ? _currentName : 'Customer',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayEmail,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 11,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Active $displayRole Account',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Profile Actions (Edit Profile & Change Password)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _openEditProfileModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: primaryIndigo,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _openChangePasswordModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_reset_rounded,
                            size: 16,
                            color: primaryIndigo,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Update Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Account Details Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'Organization',
                    displayOrg,
                    isFirst: true,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildInfoRow('Role', displayRole, valueColor: primaryIndigo),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildInfoRow('Phone', displayPhone),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildInfoRow(
                    'City / Country',
                    displayLocation,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out Button
            InkWell(
              onTap: () {
                context.read<AuthBloc>().add(LogoutRequestedEvent());
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 15,
                      color: Color(0xFFB91C1C),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 17),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
      ),
    );
  }

  InputDecoration _modalInputDecoration({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 17),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF94A3B8),
                size: 17,
              ),
              onPressed: onToggleVisibility,
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }

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

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
