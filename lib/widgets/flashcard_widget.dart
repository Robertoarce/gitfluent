import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/flashcard_question.dart';
import '../models/user_vocabulary.dart';

/// A versatile flashcard widget that supports multiple question types with animations
class FlashcardWidget extends StatefulWidget {
  final FlashcardQuestion question;
  final Function(String answer)? onAnswerSubmitted;
  final Function(String difficultyRating)? onSelfAssessment;
  final VoidCallback? onShowAnswer;
  final bool showAnswer;
  final bool isAnswered;
  final String? submittedAnswer;
  final bool? wasCorrect;
  final Duration flipAnimationDuration;

  const FlashcardWidget({
    super.key,
    required this.question,
    this.onAnswerSubmitted,
    this.onSelfAssessment,
    this.onShowAnswer,
    this.showAnswer = false,
    this.isAnswered = false,
    this.submittedAnswer,
    this.wasCorrect,
    this.flipAnimationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _fadeController;
  late Animation<double> _flipAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _textController = TextEditingController();
  String? _selectedOption;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      duration: widget.flipAnimationDuration,
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
  }

  @override
  void didUpdateWidget(FlashcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showAnswer && !oldWidget.showAnswer) {
      _flipController.forward();
      _fadeController.forward();
    } else if (!widget.showAnswer && oldWidget.showAnswer) {
      _flipController.reverse();
      _fadeController.reverse();
    }

    // Reset for new question
    if (widget.question.id != oldWidget.question.id) {
      _flipController.reset();
      _fadeController.reset();
      _textController.clear();
      _selectedOption = null;
      _hasInteracted = false;
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _fadeController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 300,
          maxHeight: 600,
        ),
        child: _buildQuestionTypeWidget(theme),
      ),
    );
  }

  Widget _buildQuestionTypeWidget(ThemeData theme) {
    switch (widget.question.type) {
      case FlashcardQuestionType.traditional:
      case FlashcardQuestionType.reverse:
        return _buildTraditionalFlashcard(theme);
      case FlashcardQuestionType.multipleChoice:
        return _buildMultipleChoiceWidget(theme);
      case FlashcardQuestionType.fillInBlank:
        return _buildFillInBlankWidget(theme);
    }
  }

  Widget _buildTraditionalFlashcard(ThemeData theme) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final isShowingFront = _flipAnimation.value < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * math.pi),
          child:
              isShowingFront ? _buildFrontCard(theme) : _buildBackCard(theme),
        );
      },
    );
  }

  Widget _buildFrontCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Question type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.question.typeDisplayName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Question text
          Expanded(
            child: Center(
              child: Text(
                widget.question.question,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Tap to reveal hint
          if (!widget.showAnswer)
            Column(
              children: [
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: widget.onShowAnswer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flip_to_back,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to reveal answer',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBackCard(ThemeData theme) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.secondary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Answer section
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Answer:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.question.correctAnswer,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.question.getHint()?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.question.getHint() ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Self-assessment buttons
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildSelfAssessmentButtons(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceWidget(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question header
          _buildQuestionHeader(theme),
          const SizedBox(height: 24),

          // Question text
          Text(
            widget.question.question,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Options
          Expanded(
            child: ListView.builder(
              itemCount: widget.question.options.length,
              itemBuilder: (context, index) {
                final option = widget.question.options[index];
                final isSelected = _selectedOption == option;
                final isCorrect = widget.question.isCorrectAnswer(option);
                final showResult = widget.isAnswered;

                Color? backgroundColor;
                Color? borderColor;
                Color? textColor;

                if (showResult) {
                  if (isCorrect) {
                    backgroundColor = Colors.green.withOpacity(0.1);
                    borderColor = Colors.green;
                    textColor = Colors.green.shade700;
                  } else if (isSelected && !isCorrect) {
                    backgroundColor = Colors.red.withOpacity(0.1);
                    borderColor = Colors.red;
                    textColor = Colors.red.shade700;
                  }
                } else if (isSelected) {
                  backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
                  borderColor = theme.colorScheme.primary;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: backgroundColor ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: widget.isAnswered
                          ? null
                          : () {
                              setState(() {
                                _selectedOption = option;
                                _hasInteracted = true;
                              });
                              widget.onAnswerSubmitted?.call(option);
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: borderColor ??
                                theme.colorScheme.outline.withOpacity(0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      borderColor ?? theme.colorScheme.outline,
                                  width: 2,
                                ),
                                color: isSelected || (showResult && isCorrect)
                                    ? (borderColor ?? theme.colorScheme.primary)
                                    : null,
                              ),
                              child: isSelected || (showResult && isCorrect)
                                  ? Icon(
                                      showResult && isCorrect
                                          ? Icons.check
                                          : Icons.circle,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: textColor,
                                  fontWeight:
                                      isSelected || (showResult && isCorrect)
                                          ? FontWeight.w600
                                          : null,
                                ),
                              ),
                            ),
                            if (showResult && isCorrect)
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                            if (showResult && isSelected && !isCorrect)
                              Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Result feedback
          if (widget.isAnswered) _buildAnswerFeedback(theme),
        ],
      ),
    );
  }

  Widget _buildFillInBlankWidget(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question header
          _buildQuestionHeader(theme),
          const SizedBox(height: 24),

          // Context with blank
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.question.question,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Text input
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: TextField(
                      controller: _textController,
                      enabled: !widget.isAnswered,
                      decoration: InputDecoration(
                        hintText: 'Type your answer...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: widget.isAnswered
                            ? theme.colorScheme.surfaceVariant.withOpacity(0.3)
                            : theme.colorScheme.surface,
                      ),
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                      onSubmitted: widget.isAnswered
                          ? null
                          : (value) {
                              if (value.trim().isNotEmpty) {
                                setState(() {
                                  _hasInteracted = true;
                                });
                                widget.onAnswerSubmitted?.call(value.trim());
                              }
                            },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Submit button
                  if (!widget.isAnswered)
                    ElevatedButton(
                      onPressed: _textController.text.trim().isEmpty
                          ? null
                          : () {
                              setState(() {
                                _hasInteracted = true;
                              });
                              widget.onAnswerSubmitted
                                  ?.call(_textController.text.trim());
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Submit Answer'),
                    ),
                ],
              ),
            ),
          ),

          // Result feedback
          if (widget.isAnswered) _buildAnswerFeedback(theme),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.question.typeDisplayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.question.vocabularyItem.wordType.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerFeedback(ThemeData theme) {
    final isCorrect = widget.wasCorrect ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isCorrect ? 'Correct!' : 'Incorrect',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color:
                        isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              'Correct answer: ${widget.question.correctAnswer}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSelfAssessmentButtons(theme),
        ],
      ),
    );
  }

  Widget _buildSelfAssessmentButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildAssessmentButton(
          theme,
          'Again',
          Colors.red,
          Icons.refresh,
          () => widget.onSelfAssessment?.call('again'),
        ),
        _buildAssessmentButton(
          theme,
          'Hard',
          Colors.orange,
          Icons.trending_down,
          () => widget.onSelfAssessment?.call('hard'),
        ),
        _buildAssessmentButton(
          theme,
          'Good',
          Colors.blue,
          Icons.thumb_up,
          () => widget.onSelfAssessment?.call('good'),
        ),
        _buildAssessmentButton(
          theme,
          'Easy',
          Colors.green,
          Icons.trending_up,
          () => widget.onSelfAssessment?.call('easy'),
        ),
      ],
    );
  }

  Widget _buildAssessmentButton(
    ThemeData theme,
    String label,
    Color color,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: Color.fromRGBO(
              (color.red * 0.7).round(),
              (color.green * 0.7).round(),
              (color.blue * 0.7).round(),
              1.0,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: color.withOpacity(0.3)),
            ),
          ),
        ),
      ),
    );
  }
}
