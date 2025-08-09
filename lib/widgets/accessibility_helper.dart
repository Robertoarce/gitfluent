import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// Accessibility helper utilities for flashcard widgets
class AccessibilityHelper {
  /// Screen breakpoints for responsive design
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Get responsive padding based on device type
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.all(16);
      case DeviceType.tablet:
        return const EdgeInsets.all(24);
      case DeviceType.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Get responsive font size multiplier
  static double getFontSizeMultiplier(BuildContext context) {
    final deviceType = getDeviceType(context);
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    double baseMultiplier;
    switch (deviceType) {
      case DeviceType.mobile:
        baseMultiplier = 1.0;
        break;
      case DeviceType.tablet:
        baseMultiplier = 1.1;
        break;
      case DeviceType.desktop:
        baseMultiplier = 1.2;
        break;
    }

    // Clamp text scale factor to prevent UI breaking
    final clampedTextScale = textScaleFactor.clamp(0.8, 2.0);
    return baseMultiplier * clampedTextScale;
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return baseSpacing;
      case DeviceType.tablet:
        return baseSpacing * 1.2;
      case DeviceType.desktop:
        return baseSpacing * 1.4;
    }
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get maximum content width for responsive design
  static double getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return screenWidth * 0.95;
      case DeviceType.tablet:
        return math.min(screenWidth * 0.8, 600);
      case DeviceType.desktop:
        return math.min(screenWidth * 0.6, 800);
    }
  }

  /// Announce message to screen readers
  static void announceToScreenReader(BuildContext context, String message) {
    // For now, we'll rely on Semantics widgets to provide screen reader information
    // Future enhancement: could use platform-specific announcement APIs
    debugPrint('Accessibility announcement: $message');
  }

  /// Provide haptic feedback for interactions
  static void provideHapticFeedback(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.correct:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.incorrect:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.navigation:
        HapticFeedback.mediumImpact();
        break;
    }
  }

  /// Get accessible button style with proper sizing
  static ButtonStyle getAccessibleButtonStyle(
    BuildContext context, {
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsets? padding,
  }) {
    final responsivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: getResponsiveSpacing(context, 16),
          vertical: getResponsiveSpacing(context, 12),
        );

    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: responsivePadding,
      minimumSize: Size(
        getResponsiveSpacing(context, 44), // Minimum touch target
        getResponsiveSpacing(context, 44),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// Create accessible focus decoration
  static BoxDecoration getAccessibleFocusDecoration(
    BuildContext context, {
    Color? borderColor,
    double borderWidth = 2,
  }) {
    final theme = Theme.of(context);
    return BoxDecoration(
      border: Border.all(
        color: borderColor ?? theme.colorScheme.primary,
        width: borderWidth,
      ),
      borderRadius: BorderRadius.circular(8),
    );
  }

  /// Get accessible text style with proper sizing
  static TextStyle getAccessibleTextStyle(
    BuildContext context,
    TextStyle? baseStyle,
  ) {
    final fontMultiplier = getFontSizeMultiplier(context);
    final theme = Theme.of(context);

    return (baseStyle ?? theme.textTheme.bodyMedium!).copyWith(
      fontSize: (baseStyle?.fontSize ?? theme.textTheme.bodyMedium!.fontSize!) *
          fontMultiplier,
      height: 1.4, // Improved line height for readability
    );
  }

  /// Check if high contrast mode is enabled
  static bool isHighContrast(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }

  /// Check if animations should be reduced
  static bool shouldReduceAnimations(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get semantic label for flashcard progress
  static String getProgressSemanticLabel(
      int current, int total, double accuracy) {
    return 'Question $current of $total. Current accuracy: ${accuracy.toStringAsFixed(0)} percent.';
  }

  /// Get semantic label for answer feedback
  static String getAnswerFeedbackSemanticLabel(
    bool isCorrect,
    String correctAnswer,
    String? userAnswer,
    Duration? responseTime,
  ) {
    final correctnessText = isCorrect ? 'Correct' : 'Incorrect';
    final answerText = isCorrect
        ? 'Your answer was correct.'
        : 'The correct answer is $correctAnswer${userAnswer != null ? '. You answered $userAnswer.' : '.'}';

    final timeText = responseTime != null
        ? ' Response time: ${responseTime.inSeconds} seconds.'
        : '';

    return '$correctnessText. $answerText$timeText';
  }

  /// Get semantic label for question type
  static String getQuestionTypeSemanticLabel(String questionType, String word) {
    switch (questionType.toLowerCase()) {
      case 'traditional':
        return 'Traditional flashcard for word: $word. Tap to reveal answer.';
      case 'reverse':
        return 'Reverse flashcard for word: $word. Translate to target language.';
      case 'multiple choice':
        return 'Multiple choice question for word: $word. Select the correct answer.';
      case 'fill in blank':
        return 'Fill in the blank question for word: $word. Type the missing word.';
      default:
        return 'Flashcard question for word: $word.';
    }
  }

  /// Create accessible card with proper focus handling
  static Widget buildAccessibleCard({
    required BuildContext context,
    required Widget child,
    VoidCallback? onTap,
    String? semanticLabel,
    bool excludeSemantics = false,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return Container(
            decoration:
                isFocused ? getAccessibleFocusDecoration(context) : null,
            child: Card(
              elevation: isFocused ? 8 : 4,
              margin: getResponsivePadding(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Semantics(
                  label: semanticLabel,
                  excludeSemantics: excludeSemantics,
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Create accessible text field with proper labeling
  static Widget buildAccessibleTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    Function(String)? onSubmitted,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onSubmitted: onSubmitted,
      style: getAccessibleTextStyle(context, null),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: getResponsiveSpacing(context, 16),
          vertical: getResponsiveSpacing(context, 12),
        ),
      ),
    );
  }

  /// Create accessible list for multiple choice options
  static Widget buildAccessibleOptionsList({
    required BuildContext context,
    required List<String> options,
    required Function(String) onOptionSelected,
    String? selectedOption,
    bool enabled = true,
    Map<String, bool>? optionResults,
  }) {
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = selectedOption == option;
        final isCorrect = optionResults?[option];

        return Container(
          margin: EdgeInsets.only(
            bottom: getResponsiveSpacing(context, 8),
          ),
          child: Focus(
            child: Builder(
              builder: (context) {
                final isFocused = Focus.of(context).hasFocus;

                return Container(
                  decoration:
                      isFocused ? getAccessibleFocusDecoration(context) : null,
                  child: Material(
                    color: _getOptionBackgroundColor(isSelected, isCorrect),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: enabled ? () => onOptionSelected(option) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(
                          getResponsiveSpacing(context, 16),
                        ),
                        child: Row(
                          children: [
                            _buildOptionIndicator(isSelected, isCorrect),
                            SizedBox(width: getResponsiveSpacing(context, 12)),
                            Expanded(
                              child: Semantics(
                                label:
                                    'Option ${index + 1}: $option${isSelected ? ', selected' : ''}${isCorrect != null ? (isCorrect ? ', correct' : ', incorrect') : ''}',
                                child: Text(
                                  option,
                                  style: getAccessibleTextStyle(
                                    context,
                                    Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ),
                            ),
                            if (isCorrect != null)
                              Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: getResponsiveSpacing(context, 20),
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
        );
      }).toList(),
    );
  }

  static Color? _getOptionBackgroundColor(bool isSelected, bool? isCorrect) {
    if (isCorrect == true) return Colors.green.withOpacity(0.1);
    if (isCorrect == false && isSelected) return Colors.red.withOpacity(0.1);
    if (isSelected) return Colors.blue.withOpacity(0.1);
    return null;
  }

  static Widget _buildOptionIndicator(bool isSelected, bool? isCorrect) {
    Color color;
    IconData icon;

    if (isCorrect == true) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (isCorrect == false && isSelected) {
      color = Colors.red;
      icon = Icons.cancel;
    } else if (isSelected) {
      color = Colors.blue;
      icon = Icons.radio_button_checked;
    } else {
      color = Colors.grey;
      icon = Icons.radio_button_unchecked;
    }

    return Icon(icon, color: color, size: 24);
  }
}

/// Device type enumeration for responsive design
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Haptic feedback types for different interactions
enum HapticFeedbackType {
  correct,
  incorrect,
  selection,
  navigation,
}

/// Responsive layout helper widget
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = AccessibilityHelper.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// Accessibility-aware container with semantic information
class AccessibleContainer extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final String? semanticHint;
  final bool excludeSemantics;
  final VoidCallback? onTap;

  const AccessibleContainer({
    super.key,
    required this.child,
    this.semanticLabel,
    this.semanticHint,
    this.excludeSemantics = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      excludeSemantics: excludeSemantics,
      child: GestureDetector(
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// Progress indicator with accessibility support
class AccessibleProgressIndicator extends StatelessWidget {
  final double progress;
  final String? semanticLabel;
  final Color? color;
  final double height;

  const AccessibleProgressIndicator({
    super.key,
    required this.progress,
    this.semanticLabel,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercentage = (progress * 100).round();

    return Semantics(
      label: semanticLabel ?? 'Progress: $progressPercentage percent',
      value: progressPercentage.toString(),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).colorScheme.primary,
        ),
        minHeight: height,
      ),
    );
  }
}
