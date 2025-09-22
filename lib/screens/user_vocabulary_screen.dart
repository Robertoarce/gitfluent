import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vocabulary_service.dart';
import '../services/user_service.dart';
import '../services/language_settings_service.dart';
import '../models/vocabulary_item.dart';
import '../models/user_vocabulary.dart';
import 'vocabulary_detail_screen.dart'; // Added import for VocabularyDetailScreen
import 'flashcard_start_screen.dart';

class UserVocabularyScreen extends StatefulWidget {
  const UserVocabularyScreen({super.key});

  @override
  State<UserVocabularyScreen> createState() => _UserVocabularyScreenState();
}

class _UserVocabularyScreenState extends State<UserVocabularyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<VocabularyItem> _legacyItems = [];
  List<UserVocabularyItem> _userItems = [];
  String? _selectedLanguage; // Add language filter state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVocabulary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVocabulary() async {
    setState(() => _isLoading = true);

    try {
      final vocabularyService = context.read<VocabularyService>();
      final userService = context.read<UserService>();
      final languageSettings = context.read<LanguageSettings>();

      // Load legacy vocabulary items
      _legacyItems = vocabularyService.items;

      // Load user vocabulary items if logged in
      if (userService.isLoggedIn) {
        // Use current target language for filtering if no specific language is selected
        final filterLanguage =
            _selectedLanguage ?? languageSettings.targetLanguage?.code;
        _userItems =
            await vocabularyService.getUserVocabulary(language: filterLanguage);
      }
    } catch (e) {
      debugPrint('Error loading vocabulary: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageSettings = context.watch<LanguageSettings>();
    final currentLanguage =
        _selectedLanguage ?? languageSettings.targetLanguage?.code;
    final currentLanguageName = _selectedLanguage != null
        ? LanguageSettings.availableLanguages
            .firstWhere((l) => l.code == _selectedLanguage,
                orElse: () => const Language('unknown', 'Unknown'))
            .name
        : languageSettings.targetLanguage?.name ?? 'All';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Vocabulary'),
            if (currentLanguage != null)
              Text(
                'Language: $currentLanguageName',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 71, 175, 227),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: 'User Account (${_userItems.length})',
              icon: const Icon(Icons.cloud),
            ),
            Tab(
              text: 'Local Storage (${_legacyItems.length})',
              icon: const Icon(Icons.storage),
            ),
          ],
        ),
        actions: [
          // Language filter dropdown
          PopupMenuButton<String?>(
            icon: const Icon(Icons.language),
            tooltip: 'Filter by Language',
            onSelected: (String? languageCode) {
              setState(() {
                _selectedLanguage = languageCode;
              });
              _loadVocabulary();
            },
            itemBuilder: (BuildContext context) {
              final items = <PopupMenuEntry<String?>>[
                PopupMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive,
                          color: (_selectedLanguage == null)
                              ? Theme.of(context).primaryColor
                              : null),
                      const SizedBox(width: 8),
                      Text('All Languages',
                          style: TextStyle(
                            fontWeight: (_selectedLanguage == null)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ];

              // Add available languages
              for (final language in LanguageSettings.availableLanguages) {
                items.add(
                  PopupMenuItem<String?>(
                    value: language.code,
                    child: Row(
                      children: [
                        Icon(Icons.language,
                            color: (_selectedLanguage == language.code)
                                ? Theme.of(context).primaryColor
                                : null),
                        const SizedBox(width: 8),
                        Text(language.name,
                            style: TextStyle(
                              fontWeight: (_selectedLanguage == language.code)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                      ],
                    ),
                  ),
                );
              }

              return items;
            },
          ),
          IconButton(
            icon: const Icon(Icons.quiz),
            onPressed: (_userItems.isNotEmpty || _legacyItems.isNotEmpty)
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FlashcardStartScreen(),
                      ),
                    );
                  }
                : null,
            tooltip: 'Study Flashcards',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVocabulary,
            tooltip: 'Refresh Vocabulary',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserVocabularyTab(),
                _buildLegacyVocabularyTab(),
              ],
            ),
    );
  }

  Widget _buildUserVocabularyTab() {
    final userService = context.watch<UserService>();

    if (!userService.isLoggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please log in to view your vocabulary',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_userItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No vocabulary saved yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Start chatting and save words to build your vocabulary!',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by word type
    final verbs = _userItems.where((item) => item.wordType == 'verb').toList();
    final nouns = _userItems.where((item) => item.wordType == 'noun').toList();
    final others = _userItems
        .where((item) => !['verb', 'noun'].contains(item.wordType))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (verbs.isNotEmpty) ...[
          _buildSectionHeader(
              'Verbs', Icons.run_circle, Colors.blue, verbs.length),
          ...verbs.map((item) => _buildUserVocabularyCard(item)),
          const SizedBox(height: 16),
        ],
        if (nouns.isNotEmpty) ...[
          _buildSectionHeader('Nouns', Icons.label, Colors.green, nouns.length),
          ...nouns.map((item) => _buildUserVocabularyCard(item)),
          const SizedBox(height: 16),
        ],
        if (others.isNotEmpty) ...[
          _buildSectionHeader(
              'Other Words', Icons.text_fields, Colors.orange, others.length),
          ...others.map((item) => _buildUserVocabularyCard(item)),
        ],
      ],
    );
  }

  Widget _buildLegacyVocabularyTab() {
    if (_legacyItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No local vocabulary saved',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Group by type
    final verbs = _legacyItems
        .where((item) => item.type == VocabularyItem.typeVerb)
        .toList();
    final nouns = _legacyItems
        .where((item) => item.type == VocabularyItem.typeNoun)
        .toList();
    final adverbs = _legacyItems
        .where((item) => item.type == VocabularyItem.typeAdverb)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (verbs.isNotEmpty) ...[
          _buildSectionHeader(
              'Verbs', Icons.run_circle, Colors.blue, verbs.length),
          ...verbs.map((item) => _buildLegacyVocabularyCard(item)),
          const SizedBox(height: 16),
        ],
        if (nouns.isNotEmpty) ...[
          _buildSectionHeader('Nouns', Icons.label, Colors.green, nouns.length),
          ...nouns.map((item) => _buildLegacyVocabularyCard(item)),
          const SizedBox(height: 16),
        ],
        if (adverbs.isNotEmpty) ...[
          _buildSectionHeader('Adverbs & Others', Icons.text_fields,
              Colors.purple, adverbs.length),
          ...adverbs.map((item) => _buildLegacyVocabularyCard(item)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserVocabularyCard(UserVocabularyItem item) {
    return InkWell(
      onTap: () {
        final vocabularyItem = VocabularyItem.fromUserVocabularyItem(item);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VocabularyDetailScreen(item: vocabularyItem),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.word,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _getTypeColor(item.wordType).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.wordType,
                      style: TextStyle(
                        color: _getTypeColor(item.wordType),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.translations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.translations.join(', '),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (item.translationLanguage != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _getLanguageName(item.translationLanguage!),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (item.forms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Forms: ${item.forms.join(', ')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Seen ${item.timesSeen} times',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Mastery: ${item.masteryLevel}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegacyVocabularyCard(VocabularyItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.word,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _getLegacyTypeColor(item.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.type,
                    style: TextStyle(
                      color: _getLegacyTypeColor(item.type),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.translation,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            if (item.definition != null) ...[
              const SizedBox(height: 8),
              Text(
                item.definition!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Added ${item.addedCount} times',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Last: ${item.lastAdded != null ? _formatDate(item.lastAdded!) : 'Unknown'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'verb':
        return Colors.blue;
      case 'noun':
        return Colors.green;
      case 'adverb':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  Color _getLegacyTypeColor(String type) {
    if (type == VocabularyItem.typeVerb) return Colors.blue;
    if (type == VocabularyItem.typeNoun) return Colors.green;
    if (type == VocabularyItem.typeAdverb) return Colors.purple;
    return Colors.orange;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  String _getLanguageName(String languageCode) {
    final language = LanguageSettings.availableLanguages.firstWhere(
        (l) => l.code == languageCode,
        orElse: () => const Language('unknown', 'Unknown'));
    return language.name;
  }
}
