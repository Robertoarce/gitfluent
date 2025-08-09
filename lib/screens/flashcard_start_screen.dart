import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flashcard_service.dart';
import '../services/user_service.dart';
import '../services/vocabulary_service.dart';
import '../widgets/accessibility_helper.dart';
import '../utils/flashcard_route_transitions.dart';
import 'flashcard_screen.dart';

class FlashcardStartScreen extends StatefulWidget {
  const FlashcardStartScreen({super.key});

  @override
  State<FlashcardStartScreen> createState() => _FlashcardStartScreenState();
}

class _FlashcardStartScreenState extends State<FlashcardStartScreen> {
  int _sessionDuration = 10; // minutes
  int _maxWords = 20;
  String? _selectedLanguage;
  final Set<String> _selectedWordTypes = {};
  bool _prioritizeReview = true;
  bool _includeFavorites = true;
  bool _isLoading = false;
  bool _hasInterruptedSession = false;

  // Available word types
  final List<String> _wordTypes = [
    'verb',
    'noun',
    'adjective',
    'adverb',
    'preposition',
    'phrase',
  ];

  // Available languages (will be populated from vocabulary)
  List<String> _availableLanguages = [];
  int _vocabularyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkForInterruptedSession();
  }

  Future<void> _loadSettings() async {
    final flashcardService = context.read<FlashcardService>();
    final vocabularyService = context.read<VocabularyService>();
    final userService = context.read<UserService>();

    setState(() {
      _isLoading = true;
    });

    try {
      // Load flashcard service preferences
      final preferences = flashcardService.sessionPreferences;
      _sessionDuration = preferences['defaultDuration'] ?? 10;
      _maxWords = preferences['maxWordsPerSession'] ?? 20;
      _prioritizeReview = preferences['prioritizeReview'] ?? true;
      _includeFavorites = preferences['includeFavorites'] ?? true;

      // Load available vocabulary info
      if (userService.isLoggedIn) {
        final vocabulary = await userService.getUserVocabulary();
        _vocabularyCount = vocabulary.length;

        // Get unique languages
        final languages =
            vocabulary.map((item) => item.language).toSet().toList();
        _availableLanguages = languages;

        if (languages.isNotEmpty) {
          _selectedLanguage = languages.first;
        }
      } else {
        // Use local vocabulary service
        _vocabularyCount = vocabularyService.items.length;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading flashcard start screen settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkForInterruptedSession() {
    final flashcardService = context.read<FlashcardService>();
    setState(() {
      _hasInterruptedSession = flashcardService.hasInterruptedSession();
    });
  }

  Future<void> _startSession() async {
    if (_vocabularyCount == 0) {
      _showNoVocabularyDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final flashcardService = context.read<FlashcardService>();

      // Update preferences
      await flashcardService.updateSessionPreferences({
        'defaultDuration': _sessionDuration,
        'maxWordsPerSession': _maxWords,
        'prioritizeReview': _prioritizeReview,
        'includeFavorites': _includeFavorites,
      });

      // Start the session
      final success = await flashcardService.startSession(
        durationMinutes: _sessionDuration,
        language: _selectedLanguage,
        focusWordTypes:
            _selectedWordTypes.isNotEmpty ? _selectedWordTypes.toList() : null,
        maxWords: _maxWords,
        prioritizeReview: _prioritizeReview,
        includeFavorites: _includeFavorites,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Provide haptic feedback
        AccessibilityHelper.provideHapticFeedback(
            HapticFeedbackType.navigation);

        // Navigate to flashcard screen
        if (mounted) {
          FlashcardNavigation.toFlashcardSession(context);
        }
      } else {
        _showErrorDialog(
            'Failed to start flashcard session. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error starting session: $e');
    }
  }

  Future<void> _resumeInterruptedSession() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final flashcardService = context.read<FlashcardService>();
      final success = await flashcardService.resumeInterruptedSession();

      setState(() {
        _isLoading = false;
      });

      if (success) {
        AccessibilityHelper.provideHapticFeedback(
            HapticFeedbackType.navigation);

        if (mounted) {
          // TODO: Uncomment when FlashcardScreen is created
          // Navigator.of(context).push(
          //   MaterialPageRoute(
          //     builder: (context) => const FlashcardScreen(),
          //   ),
          // );
          FlashcardNavigation.toFlashcardSession(context);
        }
      } else {
        setState(() {
          _hasInterruptedSession = false;
        });
        _showErrorDialog(
            'Session could not be resumed. Please start a new session.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasInterruptedSession = false;
      });
      _showErrorDialog('Error resuming session: $e');
    }
  }

  void _showNoVocabularyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Vocabulary Found'),
        content: const Text(
          'You need to add some vocabulary words before starting a flashcard session. Try having a conversation first to build your vocabulary!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Flashcards'),
        backgroundColor: const Color.fromARGB(255, 71, 175, 227),
        foregroundColor: Colors.white,
        actions: [
          if (_hasInterruptedSession)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _isLoading ? null : _resumeInterruptedSession,
              tooltip: 'Resume interrupted session',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayout(
              mobile: _buildMobileLayout(),
              tablet: _buildTabletLayout(),
              desktop: _buildDesktopLayout(),
            ),
      bottomNavigationBar: _buildBottomActions(theme),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: AccessibilityHelper.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInterruptedSessionCard(),
          _buildVocabularyStatusCard(),
          _buildSessionConfigSection(),
          _buildWordTypesSection(),
          _buildPreferencesSection(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: AccessibilityHelper.getResponsivePadding(context),
      child: Column(
        children: [
          _buildInterruptedSessionCard(),
          _buildVocabularyStatusCard(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildSessionConfigSection(),
                    _buildPreferencesSection(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildWordTypesSection(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: AccessibilityHelper.getResponsivePadding(context),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: AccessibilityHelper.getMaxContentWidth(context),
          ),
          child: Column(
            children: [
              _buildInterruptedSessionCard(),
              _buildVocabularyStatusCard(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildSessionConfigSection(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildWordTypesSection(),
                        const SizedBox(height: 16),
                        _buildPreferencesSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterruptedSessionCard() {
    if (!_hasInterruptedSession) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pause_circle,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Interrupted Session Found',
                  style: AccessibilityHelper.getAccessibleTextStyle(
                    context,
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You have an unfinished flashcard session. You can resume where you left off or start a new session.',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.orange.shade700,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _resumeInterruptedSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume Session'),
              style: AccessibilityHelper.getAccessibleButtonStyle(
                context,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyStatusCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.library_books,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vocabulary Available',
                    style: AccessibilityHelper.getAccessibleTextStyle(
                      context,
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    '$_vocabularyCount words ready to study',
                    style: AccessibilityHelper.getAccessibleTextStyle(
                      context,
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _vocabularyCount > 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _vocabularyCount > 0 ? 'Ready' : 'No Words',
                style: TextStyle(
                  color: _vocabularyCount > 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionConfigSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Configuration',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 24),

            // Session Duration
            _buildSliderSetting(
              title: 'Study Duration',
              subtitle: '$_sessionDuration minutes',
              value: _sessionDuration.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (value) {
                setState(() {
                  _sessionDuration = value.round();
                });
              },
              semanticLabel: 'Study duration: $_sessionDuration minutes',
            ),

            const SizedBox(height: 16),

            // Number of Words
            _buildSliderSetting(
              title: 'Maximum Words',
              subtitle: '$_maxWords words',
              value: _maxWords.toDouble(),
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: (value) {
                setState(() {
                  _maxWords = value.round();
                });
              },
              semanticLabel: 'Maximum words: $_maxWords',
            ),

            // Language Selection (if multiple available)
            if (_availableLanguages.length > 1) ...[
              const SizedBox(height: 16),
              _buildLanguageDropdown(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String semanticLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              subtitle,
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        Semantics(
          label: semanticLabel,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language Focus',
          style: AccessibilityHelper.getAccessibleTextStyle(
            context,
            Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedLanguage,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _availableLanguages.map((language) {
            return DropdownMenuItem<String>(
              value: language,
              child: Text(language),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLanguage = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildWordTypesSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Focus Word Types',
                  style: AccessibilityHelper.getAccessibleTextStyle(
                    context,
                    Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_selectedWordTypes.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedWordTypes.clear();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedWordTypes.isEmpty
                  ? 'All word types will be included'
                  : '${_selectedWordTypes.length} types selected',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _wordTypes.map((type) {
                final isSelected = _selectedWordTypes.contains(type);
                return FilterChip(
                  label: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedWordTypes.add(type);
                      } else {
                        _selectedWordTypes.remove(type);
                      }
                    });
                    AccessibilityHelper.provideHapticFeedback(
                        HapticFeedbackType.selection);
                  },
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  selectedColor: Theme.of(context).colorScheme.primary,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Preferences',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: 'Prioritize Review Words',
              subtitle:
                  'Focus on words that need review based on spaced repetition',
              value: _prioritizeReview,
              onChanged: (value) {
                setState(() {
                  _prioritizeReview = value;
                });
              },
            ),
            _buildSwitchTile(
              title: 'Include Favorite Words',
              subtitle: 'Include words you\'ve marked as favorites',
              value: _includeFavorites,
              onChanged: (value) {
                setState(() {
                  _includeFavorites = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: AccessibilityHelper.getAccessibleTextStyle(
          context,
          Theme.of(context).textTheme.titleMedium,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AccessibilityHelper.getAccessibleTextStyle(
          context,
          Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      value: value,
      onChanged: (newValue) {
        onChanged(newValue);
        AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.selection);
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      padding:
          EdgeInsets.all(AccessibilityHelper.getResponsiveSpacing(context, 16)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading || _vocabularyCount == 0 ? null : _startSession,
                icon: _isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? 'Starting...' : 'Start Studying'),
                style: AccessibilityHelper.getAccessibleButtonStyle(
                  context,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(
                    vertical:
                        AccessibilityHelper.getResponsiveSpacing(context, 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
