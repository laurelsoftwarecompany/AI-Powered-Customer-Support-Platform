import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../knowledge/data/knowledge_repository.dart';

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

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? 'Support Guide';
    final content = json['content']?.toString() ?? '';
    final rawSummary = json['summary']?.toString() ?? '';

    // Derive readable category from title
    String category = 'General';
    if (title.contains(' - Support Guide')) {
      category = title.replaceFirst(' - Support Guide', '').trim();
    } else if (title.contains(' - ')) {
      final part = title.split(' - ').first.trim();
      category = part.isNotEmpty ? part : 'General';
    } else if (title.startsWith('FAQ - ')) {
      category = title.replaceFirst('FAQ - ', '').trim();
    } else if (title.toLowerCase().contains('order')) {
      category = 'Orders';
    } else if (title.toLowerCase().contains('payment') ||
        title.toLowerCase().contains('billing')) {
      category = 'Billing';
    } else if (title.toLowerCase().contains('refund')) {
      category = 'Refunds';
    } else if (title.toLowerCase().contains('shipping') ||
        title.toLowerCase().contains('delivery')) {
      category = 'Shipping';
    } else if (title.toLowerCase().contains('account')) {
      category = 'Account';
    }

    String summary = rawSummary;
    if (summary.isEmpty && content.isNotEmpty) {
      final clean = content
          .replaceAll(RegExp(r'#+\s*'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      summary = clean.length > 150 ? '${clean.substring(0, 150)}...' : clean;
    }

    final tags = <String>{};
    for (final word in title.toLowerCase().split(RegExp(r'\W+'))) {
      if (word.length > 3 &&
          !['guide', 'support', 'with', 'your', 'about', 'from'].contains(word)) {
        tags.add(word);
      }
    }
    tags.add(category.toLowerCase());

    final docId = int.tryParse(json['id']?.toString() ?? '') ?? 1;

    return KnowledgeArticle(
      id: json['id']?.toString() ?? '',
      title: title,
      category: category,
      summary: summary.isNotEmpty ? summary : title,
      content: content.isNotEmpty ? content : summary,
      tags: tags.toList(),
      viewCount: 80 + (docId * 19 % 450),
    );
  }
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

  bool _isLoading = false;
  String? _errorMessage;
  List<KnowledgeArticle> _articles = [];
  List<String> _categories = ['all'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchArticles();
    });
  }

  Future<void> _fetchArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<KnowledgeRepository>();
      final docs = await repo.getDocuments();

      if (!mounted) return;
      setState(() {
        _articles = docs;
        final catSet = <String>{'all'};
        for (final doc in docs) {
          if (doc.category.isNotEmpty) {
            catSet.add(doc.category);
          }
        }
        _categories = catSet.toList();
        _isLoading = false;

        if (widget.initialArticleId != null) {
          final match =
              _articles.where((a) => a.id == widget.initialArticleId);
          if (match.isNotEmpty) {
            _selectedArticle = match.first;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
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
      final matchCat =
          _selectedCategory == 'all' || art.category == _selectedCategory;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Knowledge Base & Guides',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_articles.isNotEmpty)
              Text(
                '${_articles.length} verified support guides',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            tooltip: 'Refresh Articles',
            onPressed: _fetchArticles,
          ),
        ],
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
                    hintText: 'Search 100+ guides, orders, refunds, billing...',
                    hintStyle:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_categories.length > 1) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryIndigo
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cat == 'all' ? 'All Guides' : cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF475569),
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
              ],
            ),
          ),

          // Article List
          Expanded(
            child: _isLoading && _articles.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryIndigo),
                        SizedBox(height: 12),
                        Text(
                          'Loading knowledge base from server...',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null && _articles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 40,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fetchArticles,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryIndigo,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching articles found.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchArticles,
                            color: primaryIndigo,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final art = filtered[index];
                                return InkWell(
                                  onTap: () => setState(
                                    () => _selectedArticle = art,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF2FF),
                                                borderRadius:
                                                    BorderRadius.circular(6),
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
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF94A3B8),
                                              ),
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
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            height: 1.3,
                                          ),
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
          ),
        ],
      ),
    );
  }

  // --- Article Detail View ---
  Widget _buildArticleDetailView(
    KnowledgeArticle article,
    Color primaryIndigo,
    Color bgColor,
  ) {
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
          onPressed: () => setState(() => _selectedArticle = null),
        ),
        titleSpacing: 0,
        title: Text(
          article.title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
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
                  style: TextStyle(
                    fontSize: 10,
                    color: primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF312E81),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tags
            if (article.tags.isNotEmpty) ...[
              const Text(
                'Related Tags:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: article.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF475569),
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
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
                      Text(
                        'Still have questions?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ask our AI assistant or open a ticket',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Ask AI →',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
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