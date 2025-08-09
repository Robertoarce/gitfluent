import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flashcard_service.dart';
import '../services/user_service.dart';
import '../widgets/accessibility_helper.dart';
import '../utils/flashcard_route_transitions.dart';
import 'flashcard_start_screen.dart';

class FlashcardResultsScreen extends StatefulWidget {
  const FlashcardResultsScreen({super.key});

  @override
  State<FlashcardResultsScreen> createState() => _FlashcardResultsScreenState();
}

class _FlashcardResultsScreenState extends State<FlashcardResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  Map<String, dynamic> _performanceStats = {};
  List<String> _recommendations = [];
  Map<String, Map<String, dynamic>> _vocabularyPerformance = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _loadResultsData();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadResultsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final flashcardService = context.read<FlashcardService>();

      _performanceStats = flashcardService.getSessionPerformanceStats();
      _recommendations = flashcardService.getPerformanceRecommendations();
      _vocabularyPerformance = flashcardService.getVocabularyItemPerformance();

      setState(() {
        _isLoading = false;
      });

      // Start animations
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _slideController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _progressController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load session results: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startNewSession() async {
    AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.navigation);
    FlashcardNavigation.toNewSession(context);
  }

  void _goHome() {
    AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.navigation);
    FlashcardNavigation.toHome(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your results...'),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AccessibilityHelper.getResponsivePadding(context),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildOverallStats(),
                const SizedBox(height: 24),
                _buildPerformanceMetrics(),
                const SizedBox(height: 24),
                _buildRecommendations(),
                const SizedBox(height: 24),
                _buildVocabularyBreakdown(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AccessibilityHelper.getResponsivePadding(context),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildOverallStats(),
                          const SizedBox(height: 24),
                          _buildPerformanceMetrics(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildRecommendations(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildVocabularyBreakdown(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: AccessibilityHelper.getResponsivePadding(context),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: AccessibilityHelper.getMaxContentWidth(context),
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildOverallStats(),
                              const SizedBox(height: 24),
                              _buildPerformanceMetrics(),
                              const SizedBox(height: 24),
                              _buildVocabularyBreakdown(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildRecommendations(),
                              const SizedBox(height: 24),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final accuracy = (_performanceStats['accuracyPercentage'] ?? 0.0) as double;
    final totalQuestions = _performanceStats['totalQuestions'] ?? 0;
    final correctAnswers = _performanceStats['correctAnswers'] ?? 0;

    // Determine performance level
    String performanceLevel;
    Color performanceColor;
    IconData performanceIcon;

    if (accuracy >= 90) {
      performanceLevel = 'Excellent!';
      performanceColor = Colors.green;
      performanceIcon = Icons.star;
    } else if (accuracy >= 75) {
      performanceLevel = 'Great Job!';
      performanceColor = Colors.blue;
      performanceIcon = Icons.thumb_up;
    } else if (accuracy >= 60) {
      performanceLevel = 'Good Progress';
      performanceColor = Colors.orange;
      performanceIcon = Icons.trending_up;
    } else {
      performanceLevel = 'Keep Practicing';
      performanceColor = Colors.red;
      performanceIcon = Icons.fitness_center;
    }

    return Column(
      children: [
        // Back button
        Row(
          children: [
            IconButton(
              onPressed: _goHome,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Go back to home',
            ),
            const Spacer(),
            IconButton(
              onPressed: _startNewSession,
              icon: const Icon(Icons.refresh),
              tooltip: 'Start new session',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Performance badge
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                performanceColor.withValues(alpha: 0.1),
                performanceColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: performanceColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                performanceIcon,
                size: 48,
                color: performanceColor,
              ),
              const SizedBox(height: 12),
              Text(
                performanceLevel,
                style: AccessibilityHelper.getAccessibleTextStyle(
                  context,
                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: performanceColor,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Session Complete',
                style: AccessibilityHelper.getAccessibleTextStyle(
                  context,
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickStat(
              'Accuracy',
              '${accuracy.toStringAsFixed(1)}%',
              Icons.track_changes,
              performanceColor,
            ),
            _buildQuickStat(
              'Correct',
              '$correctAnswers/$totalQuestions',
              Icons.check_circle,
              Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AccessibilityHelper.getAccessibleTextStyle(
            context,
            Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Text(
          label,
          style: AccessibilityHelper.getAccessibleTextStyle(
            context,
            Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStats() {
    final stats = _performanceStats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Statistics',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 20),

            // Progress bars for each metric
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    _buildStatProgressBar(
                      'Accuracy',
                      (stats['accuracyPercentage'] ?? 0.0) as double,
                      100.0,
                      '%',
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildStatProgressBar(
                      'Questions Answered',
                      (stats['totalQuestions'] ?? 0).toDouble(),
                      (stats['totalQuestions'] ?? 1).toDouble(),
                      '',
                      Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _buildStatProgressBar(
                      'Session Duration',
                      (stats['sessionDurationMinutes'] ?? 0.0) as double,
                      (stats['targetDurationMinutes'] ?? 1.0) as double,
                      ' min',
                      Colors.orange,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Additional stats grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: AccessibilityHelper.getDeviceType(context) ==
                      DeviceType.mobile
                  ? 2
                  : 4,
              childAspectRatio: 2.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildStatTile(
                    'Total Questions', '${stats['totalQuestions'] ?? 0}'),
                _buildStatTile(
                    'Correct Answers', '${stats['correctAnswers'] ?? 0}'),
                _buildStatTile('Avg. Response Time',
                    '${(stats['averageResponseTimeSeconds'] ?? 0).toStringAsFixed(1)}s'),
                _buildStatTile(
                    'Question Types', '${stats['questionTypesUsed'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatProgressBar(
    String label,
    double value,
    double maxValue,
    String unit,
    Color color,
  ) {
    final progress = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final animatedProgress = progress * _progressAnimation.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$unit',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: animatedProgress,
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AccessibilityHelper.getAccessibleTextStyle(
              context,
              Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AccessibilityHelper.getAccessibleTextStyle(
              context,
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final stats = _performanceStats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 16),

            // Response time distribution
            if (stats['responseTimeDistribution'] != null) ...[
              Text(
                'Response Time Analysis',
                style: AccessibilityHelper.getAccessibleTextStyle(
                  context,
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              _buildResponseTimeChart(
                  stats['responseTimeDistribution'] as Map<String, dynamic>),
              const SizedBox(height: 20),
            ],

            // Question type performance
            if (stats['questionTypeStats'] != null) ...[
              Text(
                'Question Type Performance',
                style: AccessibilityHelper.getAccessibleTextStyle(
                  context,
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuestionTypeStats(
                  stats['questionTypeStats'] as Map<String, dynamic>),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponseTimeChart(Map<String, dynamic> distribution) {
    final categories = [
      'Quick (<3s)',
      'Normal (3-7s)',
      'Slow (7-15s)',
      'Very Slow (>15s)'
    ];
    final values = [
      distribution['quick'] ?? 0,
      distribution['normal'] ?? 0,
      distribution['slow'] ?? 0,
      distribution['verySlow'] ?? 0,
    ];
    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.red];

    return Column(
      children: [
        for (int i = 0; i < categories.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    categories[i],
                    style: AccessibilityHelper.getAccessibleTextStyle(
                      context,
                      Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value:
                            (values[i] / (values.reduce((a, b) => a + b) + 1)) *
                                _progressAnimation.value,
                        backgroundColor: colors[i].withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(colors[i]),
                        minHeight: 6,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${values[i]}',
                    style: AccessibilityHelper.getAccessibleTextStyle(
                      context,
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors[i],
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionTypeStats(Map<String, dynamic> typeStats) {
    final types = typeStats.keys.toList();

    return Column(
      children: [
        for (String type in types)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    type.toUpperCase(),
                    style: AccessibilityHelper.getAccessibleTextStyle(
                      context,
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getQuestionTypeColor(type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${((typeStats[type]['accuracy'] ?? 0.0) * 100).toStringAsFixed(0)}% accuracy',
                    style: AccessibilityHelper.getAccessibleTextStyle(
                      context,
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getQuestionTypeColor(type),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _getQuestionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'traditional':
        return Colors.blue;
      case 'multiplechoice':
        return Colors.green;
      case 'fillinblank':
        return Colors.orange;
      case 'reverse':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Colors.amber.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: AccessibilityHelper.getAccessibleTextStyle(
                    context,
                    Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recommendations.isEmpty)
              Text(
                'Great job! No specific recommendations at this time.',
                style: AccessibilityHelper.getAccessibleTextStyle(
                  context,
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade700,
                      ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _recommendations.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6, right: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _recommendations[i],
                              style: AccessibilityHelper.getAccessibleTextStyle(
                                context,
                                Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyBreakdown() {
    if (_vocabularyPerformance.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedItems = _vocabularyPerformance.entries.toList()
      ..sort((a, b) {
        final accuracyA = a.value['accuracy'] ?? 0.0;
        final accuracyB = b.value['accuracy'] ?? 0.0;
        return accuracyB.compareTo(accuracyA); // Sort by accuracy descending
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vocabulary Performance',
              style: AccessibilityHelper.getAccessibleTextStyle(
                context,
                Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 16),

            // Show top performing and struggling words
            if (sortedItems.isNotEmpty) ...[
              Text(
                'Top Performers',
                style: AccessibilityHelper.getAccessibleTextStyle(
                  context,
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0;
                  i < (sortedItems.length > 3 ? 3 : sortedItems.length);
                  i++)
                if ((sortedItems[i].value['accuracy'] ?? 0.0) >= 0.7)
                  _buildVocabularyItem(
                      sortedItems[i].key, sortedItems[i].value, true),
              const SizedBox(height: 20),
              Text(
                'Needs More Practice',
                style: AccessibilityHelper.getAccessibleTextStyle(
                  context,
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              for (int i = sortedItems.length - 1; i >= 0; i--)
                if ((sortedItems[i].value['accuracy'] ?? 0.0) < 0.7)
                  _buildVocabularyItem(
                      sortedItems[i].key, sortedItems[i].value, false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyItem(
      String word, Map<String, dynamic> performance, bool isGood) {
    final accuracy = (performance['accuracy'] ?? 0.0) as double;
    final timesSeen = performance['timesSeen'] ?? 0;
    final avgResponseTime =
        (performance['averageResponseTime'] ?? 0.0) as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isGood ? Colors.green : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isGood ? Colors.green : Colors.orange).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: AccessibilityHelper.getAccessibleTextStyle(
                    context,
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '$timesSeen attempts • ${avgResponseTime.toStringAsFixed(1)}s avg',
                  style: AccessibilityHelper.getAccessibleTextStyle(
                    context,
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isGood ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${(accuracy * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startNewSession,
            icon: const Icon(Icons.refresh),
            label: const Text('Study Again'),
            style: AccessibilityHelper.getAccessibleButtonStyle(
              context,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _goHome,
            icon: const Icon(Icons.home),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
