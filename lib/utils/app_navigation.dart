import 'package:flutter/material.dart';
import '../screens/flashcard_start_screen.dart';
import '../screens/user_vocabulary_screen.dart';
import '../screens/vocabulary_review_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/auth_screen.dart';
import 'flashcard_route_transitions.dart';

/// Centralized navigation helper for the entire app
/// Provides consistent navigation patterns and easy access to all screens
class AppNavigation {
  // Route names for named navigation
  static const String authRoute = '/auth';
  static const String homeRoute = '/home';
  static const String flashcardsRoute = '/flashcards';
  static const String vocabularyRoute = '/vocabulary';
  static const String settingsRoute = '/settings';

  /// Navigate to flashcard start screen with custom transition
  static Future<T?> toFlashcards<T extends Object?>(
    BuildContext context, {
    bool useCustomTransition = true,
  }) {
    if (useCustomTransition) {
      return FlashcardNavigation.toFlashcardStart<T>(context);
    } else {
      return Navigator.pushNamed<T>(context, flashcardsRoute);
    }
  }

  /// Navigate to vocabulary screen
  static Future<T?> toVocabulary<T extends Object?>(BuildContext context) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (context) => const UserVocabularyScreen(),
      ),
    );
  }

  /// Navigate to vocabulary review screen
  static Future<T?> toVocabularyReview<T extends Object?>(
      BuildContext context) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (context) => const VocabularyReviewScreen(),
      ),
    );
  }

  /// Navigate to settings screen
  static Future<T?> toSettings<T extends Object?>(BuildContext context) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  /// Navigate to home screen (replacing current)
  static Future<T?> toHome<T extends Object?>(BuildContext context) {
    return Navigator.pushReplacementNamed<T, dynamic>(context, homeRoute);
  }

  /// Navigate to auth screen (replacing current)
  static Future<T?> toAuth<T extends Object?>(BuildContext context) {
    return Navigator.pushReplacementNamed<T, dynamic>(context, authRoute);
  }

  /// Pop to home screen (clear navigation stack)
  static void popToHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// Show vocabulary feature discovery bottom sheet
  static void showVocabularyFeatures(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const VocabularyFeaturesBottomSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  /// Show flashcard quick actions bottom sheet
  static void showFlashcardQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const FlashcardQuickActionsBottomSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

/// Bottom sheet showing available vocabulary features
class VocabularyFeaturesBottomSheet extends StatelessWidget {
  const VocabularyFeaturesBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.book,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Vocabulary Features',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFeatureOption(
            context,
            'Study Flashcards',
            'Interactive study sessions with spaced repetition',
            Icons.quiz,
            Colors.blue,
            () {
              Navigator.pop(context);
              AppNavigation.toFlashcards(context);
            },
          ),
          _buildFeatureOption(
            context,
            'My Vocabulary',
            'View and manage your vocabulary collection',
            Icons.library_books,
            Colors.green,
            () {
              Navigator.pop(context);
              AppNavigation.toVocabulary(context);
            },
          ),
          _buildFeatureOption(
            context,
            'Review Words',
            'Browse vocabulary by word type and difficulty',
            Icons.menu_book,
            Colors.orange,
            () {
              Navigator.pop(context);
              AppNavigation.toVocabularyReview(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

/// Bottom sheet showing flashcard quick actions
class FlashcardQuickActionsBottomSheet extends StatelessWidget {
  const FlashcardQuickActionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.quiz,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Flashcard Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuickAction(
            context,
            'Quick Study (5 min)',
            'Short study session with 10 words',
            Icons.flash_on,
            Colors.orange,
            () {
              Navigator.pop(context);
              // TODO: Add quick study navigation with preset configuration
              AppNavigation.toFlashcards(context);
            },
          ),
          _buildQuickAction(
            context,
            'Custom Session',
            'Configure your own study session',
            Icons.tune,
            Colors.blue,
            () {
              Navigator.pop(context);
              AppNavigation.toFlashcards(context);
            },
          ),
          _buildQuickAction(
            context,
            'Review Mode',
            'Focus on words that need review',
            Icons.refresh,
            Colors.green,
            () {
              Navigator.pop(context);
              // TODO: Add review mode navigation with preset configuration
              AppNavigation.toFlashcards(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
