import 'package:flutter/material.dart';
import 'dart:async';

/// Progress widget for displaying flashcard session progress, timers, and statistics
class ProgressWidget extends StatefulWidget {
  final int currentQuestion;
  final int totalQuestions;
  final Duration? sessionDuration;
  final Duration? questionDuration;
  final double accuracy;
  final int correctAnswers;
  final int incorrectAnswers;
  final Duration? targetSessionDuration;
  final bool isActive;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final bool showControls;
  final bool showDetailedStats;

  const ProgressWidget({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    this.sessionDuration,
    this.questionDuration,
    this.accuracy = 0.0,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    this.targetSessionDuration,
    this.isActive = true,
    this.onPause,
    this.onResume,
    this.onStop,
    this.showControls = true,
    this.showDetailedStats = true,
  });

  @override
  State<ProgressWidget> createState() => _ProgressWidgetState();
}

class _ProgressWidgetState extends State<ProgressWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  Timer? _updateTimer;
  Duration _displaySessionDuration = Duration.zero;
  Duration _displayQuestionDuration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.currentQuestion / widget.totalQuestions,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));

    _startUpdateTimer();
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
    _progressController.forward();
  }

  @override
  void didUpdateWidget(ProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update progress animation when question changes
    if (widget.currentQuestion != oldWidget.currentQuestion) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.currentQuestion / widget.totalQuestions,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.reset();
      _progressController.forward();
    }

    // Update pulse animation based on active state
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _displaySessionDuration = widget.sessionDuration ?? Duration.zero;
          _displayQuestionDuration = widget.questionDuration ?? Duration.zero;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.totalQuestions > 0
        ? widget.currentQuestion / widget.totalQuestions
        : 0.0;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with progress info
            _buildProgressHeader(theme, progress),

            const SizedBox(height: 16),

            // Progress bar
            _buildProgressBar(theme, progress),

            const SizedBox(height: 16),

            // Timers and stats row
            _buildTimersAndStats(theme),

            if (widget.showDetailedStats) ...[
              const SizedBox(height: 16),
              _buildDetailedStats(theme),
            ],

            if (widget.showControls) ...[
              const SizedBox(height: 16),
              _buildControlButtons(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(ThemeData theme, double progress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Question counter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Progress',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isActive ? _pulseAnimation.value : 1.0,
                  child: Text(
                    '${widget.currentQuestion} / ${widget.totalQuestions}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        // Percentage
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getProgressColor(progress).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getProgressColor(progress).withOpacity(0.3),
            ),
          ),
          child: Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _getProgressColor(progress),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(ThemeData theme, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Session Progress',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.targetSessionDuration != null)
              Text(
                'Target: ${_formatDuration(widget.targetSessionDuration!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _progressAnimation.value,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(_progressAnimation.value),
              ),
              minHeight: 8,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimersAndStats(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildTimerCard(
            theme,
            'Session Time',
            _displaySessionDuration,
            Icons.timer,
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTimerCard(
            theme,
            'Current Question',
            _displayQuestionDuration,
            Icons.access_time,
            theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatsCard(
            theme,
            'Accuracy',
            '${widget.accuracy.toStringAsFixed(0)}%',
            Icons.analytics,
            _getAccuracyColor(widget.accuracy),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerCard(
    ThemeData theme,
    String label,
    Duration duration,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            _formatDuration(duration),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
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

  Widget _buildDetailedStats(ThemeData theme) {
    final totalAnswered = widget.correctAnswers + widget.incorrectAnswers;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Statistics',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  theme,
                  'Correct',
                  widget.correctAnswers.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  theme,
                  'Incorrect',
                  widget.incorrectAnswers.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  theme,
                  'Remaining',
                  (widget.totalQuestions - widget.currentQuestion).toString(),
                  theme.colorScheme.primary,
                  Icons.pending,
                ),
              ),
            ],
          ),
          if (totalAnswered > 0) ...[
            const SizedBox(height: 12),
            _buildAccuracyBar(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccuracyBar(ThemeData theme) {
    final totalAnswered = widget.correctAnswers + widget.incorrectAnswers;
    final correctRatio =
        totalAnswered > 0 ? widget.correctAnswers / totalAnswered : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Answer Distribution',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.red.withOpacity(0.3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: correctRatio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.green,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (widget.onPause != null && widget.isActive)
          _buildControlButton(
            theme,
            'Pause',
            Icons.pause,
            widget.onPause!,
            theme.colorScheme.primary,
          ),
        if (widget.onResume != null && !widget.isActive)
          _buildControlButton(
            theme,
            'Resume',
            Icons.play_arrow,
            widget.onResume!,
            Colors.green,
          ),
        if (widget.onStop != null)
          _buildControlButton(
            theme,
            'Stop',
            Icons.stop,
            widget.onStop!,
            Colors.red,
          ),
      ],
    );
  }

  Widget _buildControlButton(
    ThemeData theme,
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.6) return Colors.orange;
    if (progress < 0.8) return Colors.blue;
    return Colors.green;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy < 50) return Colors.red;
    if (accuracy < 70) return Colors.orange;
    if (accuracy < 85) return Colors.blue;
    return Colors.green;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
