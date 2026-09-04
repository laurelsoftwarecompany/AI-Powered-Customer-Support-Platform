import 'package:flutter/material.dart';

class KnowledgeArticle {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String content;
  final List<String> tags;
  final int viewCount;

  KnowledgeArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    required this.tags,
    this.viewCount = 142,
  });
}

class KnowledgeScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(int tabIndex)? onNavigateTab;
  final String? initialArticleId;

  const KnowledgeScreen({
    super.key,
    this.onBack,
    this.onNavigateTab,
    this.initialArticleId,
  });

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  KnowledgeArticle? _selectedArticle;

  final List<String> _categories = [
    'all',
    'Account',
    'Appointment Sync',
    'Billing',
    'Technical',
  ];

  final List<KnowledgeArticle> _articles = [
    KnowledgeArticle(
      id: 'kb-1',
      title: 'How to Reset Your Workspace Password & Setup 2FA',
      category: 'Account',
      summary: 'Step-by-step instructions on resetting your account credentials and configuring two-factor authentication.',
      content:
          '1. Navigate to the login screen and tap "Forgot?" next to the password field.\n\n2. Enter your registered work email address. A 6-digit confirmation code will be dispatched immediately.\n\n3. Input the verification code and set a new password containing at least 8 characters, 1 uppercase letter, and 1 numeric digit.\n\n4. For additional security, enable two-factor authentication from Account Settings.',
      tags: ['password', 'security', '2fa', 'login'],
      viewCount: 384,
    ),
    KnowledgeArticle(
      id: 'kb-2',
      title: 'FastAPI Webhook & Appointment Sync Integration Guide',
      category: 'Appointment Sync',
      summary: 'Best practices for configuring Dart/Flutter clients with FastAPI backend endpoints.',
      content:
          'When connecting Flutter mobile clients to FastAPI backend endpoints, make sure your server includes CORS headers allowing mobile origins.\n\nKey Endpoint Checklist:\n- Endpoint URL: /api/v1/sync/appointments\n- Header: Authorization: Bearer <jwt_token>\n- Return 200 status codes with a JSON body to ensure smooth synchronization without triggering retry alerts.',
      tags: ['sync', 'fastapi', 'dart', 'flutter', 'api'],
      viewCount: 512,
    ),
    KnowledgeArticle(
      id: 'kb-3',
      title: 'Understanding Subscription Billing & Invoices',
      category: 'Billing',
      summary: 'Learn how monthly cycles, prorated seats, and automated receipts are processed.',
      content:
          'Invoices are generated automatically on the 1st of every calendar month. If you update user tiers during an active cycle, seat pricing will be prorated.\n\nReceipts and VAT details can be downloaded as PDF files directly from the customer billing dashboard.',
      tags: ['billing', 'invoice', 'refund', 'subscription'],
      viewCount: 198,
    ),
    KnowledgeArticle(
      id: 'kb-4',
      title: 'Troubleshooting Offline Cache & SQLite Storage',
      category: 'Technical',
      summary: 'Resolving local database synchronization mismatches and clearing corrupted client tokens.',
      content:
          'Our mobile client uses secure SQLite/Hive persistence for offline queueing.\n\nIf you experience stale ticket states:\n1. Pull to refresh on the Tickets screen.\n2. Verify that background app refresh is permitted.\n3. Log out and log back in to renew your token session.',
      tags: ['database', 'sqlite', 'cache', 'storage'],
      viewCount: 276,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialArticleId != null) {
      final match = _articles.where((a) => a.id == widget.initialArticleId);
      if (match.isNotEmpty) {
        _selectedArticle = match.first;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF4F46E5);
    const bgColor = Color(0xFFF8FAFC);

    if (_selectedArticle != null) {
      return _buildArticleDetailView(_selectedArticle!, primaryIndigo, bgColor);
    }

    final filtered = _articles.where((art) {
      final matchCat = _selectedCategory == 'all' || art.category == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          art.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          art.summary.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          art.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF0F172A), size: 28),
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
          'Knowledge Base & Guides',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Category Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search FAQs, password reset, sync...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryIndigo : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cat == 'all' ? 'All Guides' : cat,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
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

          // Article List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No matching articles found.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final art = filtered[index];
                      return InkWell(
                        onTap: () => setState(() => _selectedArticle = art),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      art.category,
                                      style: const TextStyle(
                                        color: primaryIndigo,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${art.viewCount} views',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                art.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                art.summary,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Article Detail View ---
  Widget _buildArticleDetailView(KnowledgeArticle article, Color primaryIndigo, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF0F172A), size: 28),
          onPressed: () => setState(() => _selectedArticle = null),
        ),
        titleSpacing: 0,
        title: Text(
          article.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  article.category,
                  style: TextStyle(fontSize: 10, color: primaryIndigo, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),

            // Summary Callout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      article.summary,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF312E81), fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Body Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                article.content,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.5),
              ),
            ),
            const SizedBox(height: 12),

            // Tags
            const Text(
              'Related Tags:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: article.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF475569), fontFamily: 'monospace'),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Still Have Questions Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Still have questions?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      SizedBox(height: 2),
                      Text('Ask our AI assistant or open a ticket', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _selectedArticle = null);
                      widget.onNavigateTab?.call(1); // Navigate to AI Chat
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryIndigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Ask AI →', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}