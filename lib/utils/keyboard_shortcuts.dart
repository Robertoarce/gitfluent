import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/language_settings_service.dart';
import '../services/user_service.dart';
import '../utils/app_navigation.dart';

/// Comprehensive keyboard shortcuts for app navigation and testing
///
/// Shortcuts:
/// - Cmd/Ctrl + 1: Navigate to Chat Screen (Home)
/// - Cmd/Ctrl + 2: Navigate to Settings Screen
/// - Cmd/Ctrl + 3: Navigate to Vocabulary Screen
/// - Cmd/Ctrl + 4: Navigate to Flashcard Screen
/// - Cmd/Ctrl + 5: Navigate to Vocabulary Review Screen
/// - Cmd/Ctrl + R: Refresh language settings from Supabase
/// - Cmd/Ctrl + T: Send test chat message
/// - Cmd/Ctrl + L: Cycle through language settings (for testing)
/// - Cmd/Ctrl + D: Toggle debug overlay (if available)
class KeyboardShortcuts {
  /// Handle keyboard events for navigation and testing
  static bool handleKeyEvent(
    KeyEvent event,
    BuildContext context,
    TextEditingController? messageController,
  ) {
    if (event is! KeyDownEvent) return false;

    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (!isCtrlOrCmd) return false;

    switch (event.logicalKey) {
      // Navigation shortcuts
      case LogicalKeyboardKey.digit1:
        _navigateToHome(context);
        return true;

      case LogicalKeyboardKey.digit2:
        _navigateToSettings(context);
        return true;

      case LogicalKeyboardKey.digit3:
        _navigateToVocabulary(context);
        return true;

      case LogicalKeyboardKey.digit4:
        _navigateToFlashcards(context);
        return true;

      case LogicalKeyboardKey.digit5:
        _navigateToVocabularyReview(context);
        return true;

      // Testing shortcuts
      case LogicalKeyboardKey.keyR:
        _refreshLanguageSettings(context);
        return true;

      case LogicalKeyboardKey.keyT:
        _sendTestMessage(context, messageController);
        return true;

      case LogicalKeyboardKey.keyL:
        _cycleLanguageSettings(context);
        return true;

      case LogicalKeyboardKey.keyV:
        _pasteTestMessage(context, messageController);
        return true;

      case LogicalKeyboardKey.keyH:
        _showShortcutsHelp(context);
        return true;

      default:
        return false;
    }
  }

  /// Navigate to home/chat screen
  static void _navigateToHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _showShortcutFeedback(context, '🏠 Navigated to Home/Chat');
  }

  /// Navigate to settings screen
  static void _navigateToSettings(BuildContext context) {
    AppNavigation.toSettings(context);
    _showShortcutFeedback(context, '⚙️ Navigated to Settings');
  }

  /// Navigate to vocabulary screen
  static void _navigateToVocabulary(BuildContext context) {
    AppNavigation.toVocabulary(context);
    _showShortcutFeedback(context, '📚 Navigated to Vocabulary');
  }

  /// Navigate to flashcards screen
  static void _navigateToFlashcards(BuildContext context) {
    AppNavigation.toFlashcards(context);
    _showShortcutFeedback(context, '🃏 Navigated to Flashcards');
  }

  /// Navigate to vocabulary review screen
  static void _navigateToVocabularyReview(BuildContext context) {
    AppNavigation.toVocabularyReview(context);
    _showShortcutFeedback(context, '📖 Navigated to Vocabulary Review');
  }

  /// Refresh language settings from Supabase
  static void _refreshLanguageSettings(BuildContext context) {
    final languageSettings = context.read<LanguageSettings>();
    final userService = context.read<UserService>();

    if (userService.isLoggedIn && userService.currentUser != null) {
      languageSettings.loadFromUserPreferences(userService.currentUser!);
      _showShortcutFeedback(
          context, '🔄 Language settings refreshed from Supabase');
    } else {
      _showShortcutFeedback(
          context, '⚠️ Please log in to refresh from Supabase');
    }
  }

  /// Send a test message to chat
  static void _sendTestMessage(
      BuildContext context, TextEditingController? controller) {
    if (controller == null) {
      _showShortcutFeedback(context, '⚠️ Chat not available on this screen');
      return;
    }

    final languageSettings = context.read<LanguageSettings>();
    final targetLang = languageSettings.targetLanguage?.name ?? 'unknown';

    final testMessages = [
      'Hello, I would like to practice $targetLang',
      'Can you help me learn some basic phrases?',
      'What are common greetings in $targetLang?',
      'me gustaría irme a casa',
      'I love working with you at the school',
    ];

    final message =
        testMessages[DateTime.now().millisecond % testMessages.length];
    controller.text = message;

    // Trigger send if we're on chat screen
    final chatService = context.read<ChatService>();
    _sendChatMessage(
        context, chatService, languageSettings, message, controller);

    _showShortcutFeedback(context, '💬 Test message sent: $message');
  }

  /// Paste a specific test message
  static void _pasteTestMessage(
      BuildContext context, TextEditingController? controller) {
    if (controller == null) {
      _showShortcutFeedback(context, '⚠️ Chat not available on this screen');
      return;
    }

    controller.text = 'me gustaría irme a casa';
    _showShortcutFeedback(
        context, '📋 Test message pasted (ready to send with Enter)');
  }

  /// Cycle through different language settings for testing
  static void _cycleLanguageSettings(BuildContext context) {
    final languageSettings = context.read<LanguageSettings>();

    // Define test language combinations
    final testLanguages = [
      {'target': 'it', 'native': 'en', 'name': 'Italian/English'},
      {'target': 'nl', 'native': 'es', 'name': 'Dutch/Spanish'},
      {'target': 'ko', 'native': 'en', 'name': 'Korean/English'},
      {'target': 'fr', 'native': 'es', 'name': 'French/Spanish'},
      {'target': 'de', 'native': 'en', 'name': 'German/English'},
    ];

    // Find current setting and cycle to next
    final currentTarget = languageSettings.targetLanguage?.code ?? 'it';
    final currentIndex =
        testLanguages.indexWhere((lang) => lang['target'] == currentTarget);
    final nextIndex = (currentIndex + 1) % testLanguages.length;
    final nextLang = testLanguages[nextIndex];

    // Find language objects
    final targetLang = LanguageSettings.availableLanguages.firstWhere(
      (lang) => lang.code == nextLang['target'],
    );
    final nativeLang = LanguageSettings.availableLanguages.firstWhere(
      (lang) => lang.code == nextLang['native'],
    );

    // Update settings
    languageSettings.setTargetLanguage(targetLang);
    languageSettings.setNativeLanguage(nativeLang);

    _showShortcutFeedback(context, '🌍 Cycled to ${nextLang['name']}');
  }

  /// Show keyboard shortcuts help
  static void _showShortcutsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⌨️ Keyboard Shortcuts'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Navigation:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Cmd/Ctrl + 1: Home/Chat'),
              Text('Cmd/Ctrl + 2: Settings'),
              Text('Cmd/Ctrl + 3: Vocabulary'),
              Text('Cmd/Ctrl + 4: Flashcards'),
              Text('Cmd/Ctrl + 5: Vocabulary Review'),
              SizedBox(height: 16),
              Text('Testing:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Cmd/Ctrl + R: Refresh language settings'),
              Text('Cmd/Ctrl + T: Send test message'),
              Text('Cmd/Ctrl + V: Paste test message'),
              Text('Cmd/Ctrl + L: Cycle language settings'),
              Text('Cmd/Ctrl + H: Show this help'),
              SizedBox(height: 16),
              Text('Chat:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Shift + Enter: Send message'),
              Text('Enter: New line'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  /// Helper to send chat message
  static void _sendChatMessage(
    BuildContext context,
    ChatService chatService,
    LanguageSettings languageSettings,
    String message,
    TextEditingController controller,
  ) {
    chatService.sendMessage(message);
    controller.clear();
  }

  /// Show feedback for keyboard shortcuts
  static void _showShortcutFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Widget that wraps any screen with keyboard shortcuts
class KeyboardShortcutWrapper extends StatelessWidget {
  final Widget child;
  final TextEditingController? messageController;

  const KeyboardShortcutWrapper({
    super.key,
    required this.child,
    this.messageController,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        KeyboardShortcuts.handleKeyEvent(event, context, messageController);
      },
      child: child,
    );
  }
}
