import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/flashcard_question.dart';
import '../config/custom_theme.dart';

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
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: widget.flipAnimationDuration,
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(FlashcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showAnswer != oldWidget.showAnswer) {
      if (widget.showAnswer) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CustomColorScheme.lightBlue2,
            CustomColorScheme.lightBlue2.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header with back button and card counter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: CustomColorScheme.darkGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: CustomColorScheme.darkGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Card 1 of 5', // This should be dynamic based on actual data
                  style: TextStyle(
                    color: CustomColorScheme.darkGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Main flashcard area
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildQuestionTypeWidget(),
              ),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  'Need Practice',
                  Icons.close,
                  CustomColorScheme.lightBlue3,
                  CustomColorScheme.darkPink,
                  () {
                    // Handle "Need Practice" action
                    if (widget.onSelfAssessment != null) {
                      widget.onSelfAssessment!('difficult');
                    }
                  },
                ),
                _buildActionButton(
                  'Got It!',
                  Icons.check,
                  CustomColorScheme.lightYellow,
                  Colors.white,
                  () {
                    // Handle "Got It!" action
                    if (widget.onSelfAssessment != null) {
                      widget.onSelfAssessment!('easy');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color backgroundColor,
    Color textColor,
    VoidCallback onPressed,
  ) {
    return Container(
      width: 140,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: backgroundColor == CustomColorScheme.lightBlue3
            ? Border.all(color: CustomColorScheme.darkPink, width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionTypeWidget() {
    switch (widget.question.type) {
      case FlashcardQuestionType.traditional:
      case FlashcardQuestionType.reverse:
        return _buildTraditionalFlashcard();
      case FlashcardQuestionType.multipleChoice:
        return _buildMultipleChoiceWidget();
      case FlashcardQuestionType.fillInBlank:
        return _buildFillInBlankWidget();
    }
  }

  Widget _buildTraditionalFlashcard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final isShowingFront = _flipAnimation.value < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * math.pi),
          child: isShowingFront ? _buildFrontCard() : _buildBackCard(),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Question type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CustomColorScheme.lightBlue2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.question.typeDisplayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Question text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.question.question,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: CustomColorScheme.darkGreen,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Tap to reveal hint
          if (!widget.showAnswer)
            GestureDetector(
              onTap: widget.onShowAnswer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: CustomColorScheme.lightBlue3.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: CustomColorScheme.lightBlue1.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flip_to_back,
                      size: 20,
                      color: CustomColorScheme.darkGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Click to reveal translation',
                      style: TextStyle(
                        color: CustomColorScheme.darkGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Answer type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CustomColorScheme.darkPink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Answer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Answer text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.question.correctAnswer,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: CustomColorScheme.darkGreen,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Tap to flip back
          GestureDetector(
            onTap: widget.onShowAnswer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: CustomColorScheme.lightBlue3.withOpacity(0.3),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: CustomColorScheme.lightBlue1.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flip_to_front,
                    size: 20,
                    color: CustomColorScheme.darkGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Click to see question',
                    style: TextStyle(
                      color: CustomColorScheme.darkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceWidget() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Question type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CustomColorScheme.lightBlue2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.question.typeDisplayName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Question text
            Text(
              widget.question.question,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CustomColorScheme.darkGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Answer options
            ...widget.question.options.map((option) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                onPressed: () {
                  if (widget.onAnswerSubmitted != null) {
                    widget.onAnswerSubmitted!(option);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColorScheme.lightBlue3,
                  foregroundColor: CustomColorScheme.darkGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  option,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFillInBlankWidget() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Question type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CustomColorScheme.lightBlue2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.question.typeDisplayName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Question text with blank
            Text(
              widget.question.question,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CustomColorScheme.darkGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Answer input
            TextField(
              onSubmitted: (value) {
                if (widget.onAnswerSubmitted != null) {
                  widget.onAnswerSubmitted!(value);
                }
              },
              decoration: InputDecoration(
                hintText: 'Type your answer here...',
                hintStyle: TextStyle(
                  color: CustomColorScheme.darkGreen.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: CustomColorScheme.lightBlue1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: CustomColorScheme.darkPink, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(
                color: CustomColorScheme.darkGreen,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}