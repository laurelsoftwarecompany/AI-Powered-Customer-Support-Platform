import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';

class AttachmentItem {
  final String id;
  final String name;
  final String size;
  final String path;
  final bool isImage;

  AttachmentItem({
    required this.id,
    required this.name,
    required this.size,
    required this.path,
    required this.isImage,
  });
}

class CreateTicketScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSuccess;

  const CreateTicketScreen({super.key, this.onBack, this.onSuccess});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'Technical';
  String _selectedPriority = 'High';
  final List<AttachmentItem> _attachments = [];
  String? _submittedTicketNumber;

  final List<String> _categories = [
    'Account',
    'Appointment Sync',
    'Billing',
    'Technical',
    'Security',
    'Product',
    'Other',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void dispose() {
    _subjectController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _fillExampleFromDoc() {
    setState(() {
      _subjectController.text = 'Unable to access my account';
      _selectedCategory = 'Account';
      _selectedPriority = 'High';
      _descController.text =
          'I have tried resetting my password but still cannot access my account.';
    });
  }

  Future<void> _pickImageFromDevice() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final bytes = await file.length();
      final sizeInKb = bytes / 1024;
      final sizeText = sizeInKb >= 1024
          ? '${(sizeInKb / 1024).toStringAsFixed(1)} MB'
          : '${sizeInKb.toStringAsFixed(0)} KB';

      if (!mounted) return;
      setState(() {
        _attachments.add(
          AttachmentItem(
            id: 'att-${DateTime.now().millisecondsSinceEpoch}',
            name: pickedFile.name,
            size: sizeText,
            path: pickedFile.path,
            isImage: true,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load image: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((item) => item.id == id);
    });
  }

  void _submitTicket() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<TicketBloc>().add(
        CreateTicketSubmittedEvent(
          subject: _subjectController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          description: _descController.text.trim(),
        ),
      );
    }
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
          'Create Support Ticket',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: _fillExampleFromDoc,
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
                      Icons.auto_awesome,
                      color: Color(0xFFF59E0B),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Load Sample',
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
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state is TicketCreateSuccess) {
            setState(() {
              _submittedTicketNumber = state.newTicket.ticketNumber;
            });
          } else if (state is TicketFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: _submittedTicketNumber != null
            ? _buildSuccessView(primaryIndigo)
            : _buildFormView(primaryIndigo),
      ),
    );
  }

  Widget _buildFormView(Color primaryIndigo) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Subject', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _subjectController,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: _inputDecoration('e.g. Unable to access my account'),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Please enter a subject'
                  : null,
            ),
            const SizedBox(height: 18),

            _buildLabel('Category', isRequired: true),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return InkWell(
                  onTap: () => setState(() => _selectedCategory = cat),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryIndigo : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? primaryIndigo
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryIndigo.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            _buildLabel('Priority', isRequired: true),
            const SizedBox(height: 6),
            Row(
              children: _priorities.map((p) {
                final isSelected = _selectedPriority == p;
                Color activeColor;
                switch (p) {
                  case 'Low':
                    activeColor = const Color(0xFF475569);
                    break;
                  case 'Medium':
                    activeColor = const Color(0xFF2563EB);
                    break;
                  case 'High':
                    activeColor = const Color(0xFFD97706);
                    break;
                  case 'Urgent':
                    activeColor = const Color(0xFFDC2626);
                    break;
                  default:
                    activeColor = primaryIndigo;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedPriority = p),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? activeColor
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            _buildLabel('Description', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: _inputDecoration(
                'Describe the issue in detail, error codes, steps to reproduce...',
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Please enter a description'
                  : null,
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Attach Screenshot',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _pickImageFromDevice,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 14,
                          color: primaryIndigo,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Upload Photo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryIndigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_attachments.isNotEmpty)
              Column(
                children: _attachments.map((att) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(att.path),
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 42,
                                  height: 42,
                                  color: const Color(0xFFF1F5F9),
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                att.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                att.size,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                          onPressed: () => _removeAttachment(att.id),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),

            BlocBuilder<TicketBloc, TicketState>(
              builder: (context, state) {
                final isSubmitting = state is TicketSubmitting;
                return ElevatedButton(
                  onPressed: isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryIndigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.confirmation_number_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Submit Support Ticket',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(Color primaryIndigo) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF059669),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Support Ticket Submitted!',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ticket $_submittedTicketNumber has been logged in Laurel Systems and assigned to Support Agent Marcus Vance.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                setState(() => _submittedTicketNumber = null);
                widget.onSuccess?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryIndigo,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Ticket Status & Timeline →',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                setState(() => _submittedTicketNumber = null);
                widget.onSuccess?.call();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF334155),
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back to Ticket History',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
        children: isRequired
            ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
  }
}
