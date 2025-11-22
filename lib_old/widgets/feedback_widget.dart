import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/flashcard_question.dart';
import '../models/user_vocabulary.dart';

/// Enhanced feedback widget for immediate visual feedback on flashcard answers
class FeedbackWidget extends StatefulWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String? userAnswer;
  final FlashcardQuestion question;
  final Duration? responseTime;
  final int currentStreak;
  final bool showDetailed;
  final VoidCallback? onDismiss;
  final Duration autoHideDuration;

  const FeedbackWidget({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
    this.userAnswer,
    required this.question,
    this.responseTime,
    this.currentStreak = 0,
    this.showDetailed = true,
    this.onDismiss,
    this.autoHideDuration = const Duration(seconds: 3),
  });

  @override
  State<FeedbackWidget> createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends State<FeedbackWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _celebrationController;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _celebrationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _celebrationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: widget.isCorrect ? Colors.green.shade100 : Colors.red.shade100,
      end: widget.isCorrect ? Colors.green.shade50 : Colors.red.shade50,
    ).animate(_pulseController);

    _startAnimations();
    _scheduleAutoHide();
  }

  void _startAnimations() {
    _scaleController.forward();
    _slideController.forward();

    if (widget.isCorrect) {
      _pulseController.repeat(reverse: true);

      // Start celebration for streaks
      if (widget.currentStreak >= 3) {
        _celebrationController.forward();
      }
    }
  }

  void _scheduleAutoHide() {
    Future.delayed(widget.autoHideDuration, () {
      if (mounted) {
        _dismissWidget();
      }
    });
  }

  void _dismissWidget() {
    _scaleController.reverse();
    _slideController.reverse();
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    _celebrationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          children: [
            // Main feedback card
            _buildFeedbackCard(theme),

            // Celebration overlay for streaks
            if (widget.isCorrect && widget.currentStreak >= 3)
              _buildCelebrationOverlay(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(ThemeData theme) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isCorrect ? Colors.green : Colors.red,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isCorrect ? Colors.green : Colors.red)
                    .withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with result icon and text
              _buildFeedbackHeader(theme),

              const SizedBox(height: 16),

              // Answer details
              _buildAnswerDetails(theme),

              // Response time and additional info
              if (widget.responseTime != null || widget.showDetailed) ...[
                const SizedBox(height: 16),
                _buildAdditionalInfo(theme),
              ],

              // Quick explanation for incorrect answers
              if (!widget.isCorrect && widget.showDetailed) ...[
                const SizedBox(height: 16),
                _buildExplanation(theme),
              ],

              // Streak indicator
              if (widget.currentStreak > 1) ...[
                const SizedBox(height: 12),
                _buildStreakIndicator(theme),
              ],

              const SizedBox(height: 16),

              // Dismiss button
              _buildDismissButton(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackHeader(ThemeData theme) {
    final color = widget.isCorrect ? Colors.green : Colors.red;
    final icon = widget.isCorrect ? Icons.check_circle : Icons.cancel;
    final title = widget.isCorrect ? 'Correct!' : 'Incorrect';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCorrect ? _pulseAnimation.value : 1.0,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (widget.responseTime != null)
                      Text(
                        'Response time: ${_formatResponseTime(widget.responseTime!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.isCorrect) _buildPerformanceBadge(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceBadge(ThemeData theme) {
    String badge = 'Good';
    Color badgeColor = Colors.blue;

    if (widget.responseTime != null) {
      final responseMs = widget.responseTime!.inMilliseconds;
      if (responseMs < 2000) {
        badge = 'Lightning';
        badgeColor = Colors.purple;
      } else if (responseMs < 5000) {
        badge = 'Quick';
        badgeColor = Colors.green;
      } else if (responseMs < 10000) {
        badge = 'Steady';
        badgeColor = Colors.blue;
      } else {
        badge = 'Thoughtful';
        badgeColor = Colors.orange;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        badge,
        style: theme.textTheme.labelSmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAnswerDetails(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word being studied
          Row(
            children: [
              Icon(
                Icons.translate,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Word: ${widget.question.vocabularyItem.word}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Correct answer
          _buildAnswerRow(
            theme,
            'Correct Answer',
            widget.correctAnswer,
            Colors.green,
            Icons.check_circle_outline,
          ),

          // User's answer (if different and provided)
          if (widget.userAnswer != null &&
              widget.userAnswer != widget.correctAnswer) ...[
            const SizedBox(height: 8),
            _buildAnswerRow(
              theme,
              'Your Answer',
              widget.userAnswer!,
              Colors.red,
              Icons.cancel_outlined,
            ),
          ],

          // Question type
          const SizedBox(height: 8),
          _buildAnswerRow(
            theme,
            'Question Type',
            widget.question.typeDisplayName,
            theme.colorScheme.primary,
            Icons.quiz,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerRow(
    ThemeData theme,
    String label,
    String answer,
    Color color,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: answer,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo(ThemeData theme) {
    return Row(
      children: [
        if (widget.responseTime != null)
          Expanded(
            child: _buildInfoCard(
              theme,
              'Response Time',
              _formatResponseTime(widget.responseTime!),
              Icons.timer,
              _getResponseTimeColor(widget.responseTime!),
            ),
          ),
        if (widget.responseTime != null && widget.showDetailed)
          const SizedBox(width: 12),
        if (widget.showDetailed)
          Expanded(
            child: _buildInfoCard(
              theme,
              'Difficulty',
              widget.question.difficultyLevel.toString(),
              Icons.trending_up,
              theme.colorScheme.secondary,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanation(ThemeData theme) {
    String explanation = _generateExplanation();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Tip',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.currentStreak} Streak!',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissButton(ThemeData theme) {
    return TextButton.icon(
      onPressed: _dismissWidget,
      icon: const Icon(Icons.close, size: 18),
      label: const Text('Continue'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildCelebrationOverlay(ThemeData theme) {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CelebrationPainter(_celebrationAnimation.value),
            ),
          ),
        );
      },
    );
  }

  String _generateExplanation() {
    final questionType = widget.question.type;
    final wordType = widget.question.vocabularyItem.wordType;

    switch (questionType) {
      case FlashcardQuestionType.multipleChoice:
        return 'For multiple choice questions, try eliminating obviously wrong answers first.';
      case FlashcardQuestionType.fillInBlank:
        return 'Pay attention to the context clues in the sentence to determine the correct word.';
      case FlashcardQuestionType.reverse:
        return 'Practice thinking in the target language rather than translating word by word.';
      case FlashcardQuestionType.traditional:
        return wordType == 'verb'
            ? 'Try to remember verb conjugations and common usage patterns.'
            : 'Associate this word with visual images or personal experiences.';
    }
  }

  String _formatResponseTime(Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = duration.inMilliseconds % 1000;

    if (seconds > 0) {
      return '${seconds}s';
    } else {
      return '${(milliseconds / 100).round() / 10}s';
    }
  }

  Color _getResponseTimeColor(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms < 2000) return Colors.purple;
    if (ms < 5000) return Colors.green;
    if (ms < 10000) return Colors.blue;
    return Colors.orange;
  }
}

/// Custom painter for celebration effects
class CelebrationPainter extends CustomPainter {
  final double progress;

  CelebrationPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent animation

    // Draw confetti particles
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * progress;
      final color = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
      ][i % 6];

      paint.color = color.withOpacity(0.8 * (1 - progress));

      canvas.drawCircle(
        Offset(x, y),
        3 + (math.sin(progress * math.pi * 2) * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
