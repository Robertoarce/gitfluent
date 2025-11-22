import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/flashcard_service.dart';
import '../models/flashcard_question.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/progress_widget.dart';
import '../widgets/feedback_widget.dart';
import '../widgets/accessibility_helper.dart';
import '../utils/flashcard_route_transitions.dart';
import 'flashcard_results_screen.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with TickerProviderStateMixin {
  bool _showFeedback = false;
  bool _isAnswerCorrect = false;
  final String _feedbackMessage = '';
  String? _userAnswer;
  String? _selectedDifficulty;
  bool _isFlipped = false;

  // Animation controllers
  late AnimationController _feedbackController;
  late AnimationController _questionTransitionController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _questionTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _questionTransitionController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _questionTransitionController,
      curve: Curves.easeIn,
    ));

    // Start the initial animation
    _questionTransitionController.forward();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _questionTransitionController.dispose();
    super.dispose();
  }

  Future<void> _handleAnswer({
    String? userAnswer,
    bool? isCorrect,
    String? difficultyRating,
  }) async {
    final flashcardService = context.read<FlashcardService>();

    setState(() {
      _userAnswer = userAnswer;
      _isAnswerCorrect = isCorrect ?? false;
      _selectedDifficulty = difficultyRating;
      _showFeedback = true;
    });

    // Animate feedback
    await _feedbackController.forward();

    // Provide haptic feedback
    AccessibilityHelper.provideHapticFeedback(
      _isAnswerCorrect
          ? HapticFeedbackType.correct
          : HapticFeedbackType.incorrect,
    );

    // Record the answer
    bool recorded = false;
    if (difficultyRating != null) {
      recorded = await flashcardService.recordSelfAssessment(difficultyRating);
    } else if (userAnswer != null) {
      recorded = await flashcardService.recordSpecificAnswer(userAnswer);
    }

    if (!recorded) {
      _showError('Failed to record answer. Please try again.');
    }

    // Auto-advance after a delay for correct answers
    if (_isAnswerCorrect && difficultyRating == null) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _nextQuestion();
      }
    }
  }

  Future<void> _nextQuestion() async {
    final flashcardService = context.read<FlashcardService>();

    // Hide feedback first
    await _hideFeedback();

    // Check if this was the last question
    if (!flashcardService.hasNextQuestion()) {
      _completeSession();
      return;
    }

    // Animate question transition
    await _questionTransitionController.reverse();

    // Move to next question
    final success = await flashcardService.nextQuestion();

    if (success) {
      setState(() {
        _isFlipped = false;
      });

      // Animate in new question
      await _questionTransitionController.forward();

      AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.navigation);
    } else {
      _showError('Failed to load next question.');
    }
  }

  Future<void> _previousQuestion() async {
    final flashcardService = context.read<FlashcardService>();

    if (!flashcardService.hasPreviousQuestion()) return;

    // Hide feedback first
    await _hideFeedback();

    // Animate question transition
    await _questionTransitionController.reverse();

    // Move to previous question
    final success = await flashcardService.previousQuestion();

    if (success) {
      setState(() {
        _isFlipped = false;
      });

      // Animate in new question
      await _questionTransitionController.forward();

      AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.navigation);
    } else {
      _showError('Failed to load previous question.');
    }
  }

  Future<void> _hideFeedback() async {
    if (_showFeedback) {
      await _feedbackController.reverse();
      setState(() {
        _showFeedback = false;
        _userAnswer = null;
        _selectedDifficulty = null;
      });
    }
  }

  Future<void> _pauseSession() async {
    final flashcardService = context.read<FlashcardService>();

    final success = await flashcardService.pauseSession();
    if (success) {
      AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.navigation);
    } else {
      _showError('Failed to pause session.');
    }
  }

  Future<void> _resumeSession() async {
    final flashcardService = context.read<FlashcardService>();

    final success = await flashcardService.resumeSession();
    if (success) {
      AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.navigation);
    } else {
      _showError('Failed to resume session.');
    }
  }

  Future<void> _completeSession() async {
    final flashcardService = context.read<FlashcardService>();

    final success = await flashcardService.completeSession();
    if (success) {
      AccessibilityHelper.provideHapticFeedback(HapticFeedbackType.correct);

      // Navigate to results screen
      if (mounted) {
        FlashcardNavigation.toFlashcardResults(context);
      }
    } else {
      _showError('Failed to complete session.');
    }
  }

  Future<void> _exitSession() async {
    // Show confirmation dialog
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Session?'),
        content: const Text(
          'Are you sure you want to exit? Your progress will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      final flashcardService = context.read<FlashcardService>();
      await flashcardService.pauseSession(); // Save progress

      if (mounted) {
        Navigator.of(context).pop();
      }
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _exitSession();
        return false; // Prevent default back navigation
      },
      child: Scaffold(
        body: Consumer<FlashcardService>(
          builder: (context, flashcardService, child) {
            // Handle different session states
            if (flashcardService.sessionStatus ==
                FlashcardSessionStatus.notStarted) {
              return _buildNotStartedState();
            }

            if (flashcardService.sessionStatus ==
                FlashcardSessionStatus.completed) {
              return _buildCompletedState();
            }

            if (flashcardService.sessionStatus ==
                FlashcardSessionStatus.cancelled) {
              return _buildCancelledState();
            }

            final currentQuestion = flashcardService.currentQuestion;
            if (currentQuestion == null) {
              return _buildLoadingState();
            }

            return _buildActiveSessionState(flashcardService, currentQuestion);
          },
        ),
      ),
    );
  }

  Widget _buildNotStartedState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Starting your flashcard session...'),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading questions...'),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'Session Complete!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text('Redirecting to results...'),
        ],
      ),
    );
  }

  Widget _buildCancelledState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cancel,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const Text(
            'Session Cancelled',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionState(
    FlashcardService flashcardService,
    FlashcardQuestion currentQuestion,
  ) {
    final isPaused =
        flashcardService.sessionStatus == FlashcardSessionStatus.paused;

    return ResponsiveLayout(
      mobile: _buildMobileLayout(flashcardService, currentQuestion, isPaused),
      tablet: _buildTabletLayout(flashcardService, currentQuestion, isPaused),
      desktop: _buildDesktopLayout(flashcardService, currentQuestion, isPaused),
    );
  }

  Widget _buildMobileLayout(
    FlashcardService flashcardService,
    FlashcardQuestion currentQuestion,
    bool isPaused,
  ) {
    return Column(
      children: [
        // Progress Section
        Container(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          child: SafeArea(
            bottom: false,
            child: ProgressWidget(
              currentQuestion: flashcardService.getCurrentQuestionNumber(),
              totalQuestions: flashcardService.totalQuestions,
              correctAnswers: flashcardService.correctAnswers,
              incorrectAnswers: flashcardService.incorrectAnswers,
              sessionDuration: flashcardService.sessionDuration,
              onPause: _pauseSession,
              onResume: _resumeSession,
              onStop: _exitSession,
              showDetailedStats: false, // Simplified for mobile
            ),
          ),
        ),

        // Main Content
        Expanded(
          child: _buildMainContent(flashcardService, currentQuestion, isPaused),
        ),

        // Bottom Controls
        _buildBottomControls(flashcardService),
      ],
    );
  }

  Widget _buildTabletLayout(
    FlashcardService flashcardService,
    FlashcardQuestion currentQuestion,
    bool isPaused,
  ) {
    return Row(
      children: [
        // Side Progress Panel
        Container(
          width: 300,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ProgressWidget(
                currentQuestion: flashcardService.getCurrentQuestionNumber(),
                totalQuestions: flashcardService.totalQuestions,
                correctAnswers: flashcardService.correctAnswers,
                incorrectAnswers: flashcardService.incorrectAnswers,
                sessionDuration: flashcardService.sessionDuration,
                isActive: !isPaused,
                onPause: _pauseSession,
                onResume: _resumeSession,
                onStop: _exitSession,
                showDetailedStats: true,
              ),
            ),
          ),
        ),

        // Main Content
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _buildMainContent(
                    flashcardService, currentQuestion, isPaused),
              ),
              _buildBottomControls(flashcardService),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    FlashcardService flashcardService,
    FlashcardQuestion currentQuestion,
    bool isPaused,
  ) {
    return Row(
      children: [
        // Side Progress Panel
        Container(
          width: 350,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ProgressWidget(
                currentQuestion: flashcardService.getCurrentQuestionNumber(),
                totalQuestions: flashcardService.totalQuestions,
                correctAnswers: flashcardService.correctAnswers,
                incorrectAnswers: flashcardService.incorrectAnswers,
                sessionDuration: flashcardService.sessionDuration,
                isActive: !isPaused,
                onPause: _pauseSession,
                onResume: _resumeSession,
                onStop: _exitSession,
                showDetailedStats: true,
              ),
            ),
          ),
        ),

        // Main Content
        Expanded(
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: AccessibilityHelper.getMaxContentWidth(context),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _buildMainContent(
                        flashcardService, currentQuestion, isPaused),
                  ),
                  _buildBottomControls(flashcardService),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(
    FlashcardService flashcardService,
    FlashcardQuestion currentQuestion,
    bool isPaused,
  ) {
    if (isPaused) {
      return _buildPausedState();
    }

    return Column(
      children: [
        // Main Flashcard Area
        Expanded(
          child: Padding(
            padding: AccessibilityHelper.getResponsivePadding(context),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: FlashcardWidget(
                  question: currentQuestion,
                  showAnswer: _isFlipped,
                  onShowAnswer: () {
                    setState(() {
                      _isFlipped = !_isFlipped;
                    });
                    AccessibilityHelper.provideHapticFeedback(
                        HapticFeedbackType.selection);
                  },
                  onAnswerSubmitted: (answer) =>
                      _handleAnswer(userAnswer: answer),
                  onSelfAssessment: (rating) =>
                      _handleAnswer(difficultyRating: rating),
                ),
              ),
            ),
          ),
        ),

        // Feedback Area
        if (_showFeedback)
          FadeTransition(
            opacity: _feedbackController,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: FeedbackWidget(
                isCorrect: _isAnswerCorrect,
                question: currentQuestion,
                userAnswer: _userAnswer,
                correctAnswer: currentQuestion.correctAnswer,
                currentStreak: 0,
                showDetailed: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPausedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pause_circle_outline,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Session Paused',
            style: AccessibilityHelper.getAccessibleTextStyle(
              context,
              Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your progress has been saved.\nTap resume to continue studying.',
            textAlign: TextAlign.center,
            style: AccessibilityHelper.getAccessibleTextStyle(
              context,
              Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _resumeSession,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
                style: AccessibilityHelper.getAccessibleButtonStyle(
                  context,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _exitSession,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Exit'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(FlashcardService flashcardService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous Button
            Expanded(
              child: AccessibilityHelper.buildAccessibleCard(
                context: context,
                child: OutlinedButton.icon(
                  onPressed:
                      flashcardService.hasPreviousQuestion() && !_showFeedback
                          ? _previousQuestion
                          : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Next Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: flashcardService.hasNextQuestion()
                    ? _nextQuestion
                    : _completeSession,
                icon: Icon(
                  flashcardService.hasNextQuestion()
                      ? Icons.arrow_forward
                      : Icons.check,
                ),
                label: Text(
                  flashcardService.hasNextQuestion() ? 'Next' : 'Complete',
                ),
                style: AccessibilityHelper.getAccessibleButtonStyle(
                  context,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
