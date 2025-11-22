import 'package:flutter/material.dart';
// Placeholder imports - these will be available when this file is used
// ignore: unused_import
import '../screens/flashcard_start_screen.dart';
// ignore: unused_import
import '../screens/flashcard_screen.dart';
// ignore: unused_import
import '../screens/flashcard_results_screen.dart';

/// Custom route transitions for flashcard screens
class FlashcardRouteTransitions {
  /// Slide transition from right for starting a new flashcard session
  static Route<T> slideFromRight<T extends Object?>(
    Widget child, {
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeInOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;

        final slideAnimation = Tween(begin: begin, end: end).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        final fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
          ),
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Fade transition with scale for results screen
  static Route<T> fadeWithScale<T extends Object?>(
    Widget child, {
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        final scaleAnimation = Tween(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
          ),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Slide up transition from bottom for modal-like screens
  static Route<T> slideFromBottom<T extends Object?>(
    Widget child, {
    Duration duration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeOutCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;

        final slideAnimation = Tween(begin: begin, end: end).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
    );
  }

  /// Custom transition for session flow (start → flashcard → results)
  static Route<T> sessionFlow<T extends Object?>(
    Widget child, {
    bool isForward = true,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Different transition direction based on flow direction
        final begin =
            isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
        const end = Offset.zero;

        final slideAnimation = Tween(begin: begin, end: end).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
        );

        final fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
          ),
        );

        // Add a subtle blur effect during transition
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Hero transition for individual vocabulary items to flashcard
  static Route<T> heroTransition<T extends Object?>(
    Widget child, {
    String? heroTag,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
          ),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      },
    );
  }
}

/// Navigation helper for flashcard screens with proper state management
class FlashcardNavigation {
  /// Navigate to flashcard start screen with appropriate transition
  static Future<T?> toFlashcardStart<T extends Object?>(
    BuildContext context, {
    bool useCustomTransition = true,
  }) {
    if (useCustomTransition) {
      return Navigator.of(context).push<T>(
        FlashcardRouteTransitions.slideFromRight<T>(
          // We'll import the screen in the files that use this
          const FlashcardStartScreen(),
        ),
      );
    } else {
      return Navigator.of(context).push<T>(
        MaterialPageRoute<T>(
          builder: (context) => const FlashcardStartScreen(),
        ),
      );
    }
  }

  /// Navigate to flashcard session screen (from start screen)
  static Future<T?> toFlashcardSession<T extends Object?>(
    BuildContext context, {
    bool useCustomTransition = true,
  }) {
    if (useCustomTransition) {
      return Navigator.of(context).push<T>(
        FlashcardRouteTransitions.sessionFlow<T>(
          const FlashcardScreen(),
          isForward: true,
        ),
      );
    } else {
      return Navigator.of(context).push<T>(
        MaterialPageRoute<T>(
          builder: (context) => const FlashcardScreen(),
        ),
      );
    }
  }

  /// Navigate to results screen (replace current screen)
  static Future<T?> toFlashcardResults<T extends Object?>(
    BuildContext context, {
    bool useCustomTransition = true,
  }) {
    if (useCustomTransition) {
      return Navigator.of(context).pushReplacement<T, dynamic>(
        FlashcardRouteTransitions.fadeWithScale<T>(
          const FlashcardResultsScreen(),
        ),
      );
    } else {
      return Navigator.of(context).pushReplacement<T, dynamic>(
        MaterialPageRoute<T>(
          builder: (context) => const FlashcardResultsScreen(),
        ),
      );
    }
  }

  /// Navigate back to start screen for a new session
  static Future<T?> toNewSession<T extends Object?>(
    BuildContext context, {
    bool useCustomTransition = true,
  }) {
    if (useCustomTransition) {
      return Navigator.of(context).pushReplacement<T, dynamic>(
        FlashcardRouteTransitions.sessionFlow<T>(
          const FlashcardStartScreen(),
          isForward: false,
        ),
      );
    } else {
      return Navigator.of(context).pushReplacement<T, dynamic>(
        MaterialPageRoute<T>(
          builder: (context) => const FlashcardStartScreen(),
        ),
      );
    }
  }

  /// Navigate home and clear flashcard stack
  static void toHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Pop with feedback - used for cancelling sessions
  static void popWithFeedback(BuildContext context, {String? message}) {
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    Navigator.of(context).pop();
  }
}
