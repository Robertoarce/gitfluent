import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/services/conversation_service.dart';
import '../lib/services/settings_service.dart';
import '../lib/services/language_settings_service.dart';
import '../lib/services/vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ConversationService', () {
    late ConversationService conversationService;
    late SettingsService settingsService;
    late LanguageSettings languageSettings;
    late VocabularyService vocabularyService;

    setUp(() {
      settingsService = SettingsService();
      languageSettings = LanguageSettings();
      vocabularyService = VocabularyService();

      conversationService = ConversationService(
        settings: settingsService,
        languageSettings: languageSettings,
        vocabularyService: vocabularyService,
      );
    });

    test('should initialize with empty messages', () {
      expect(conversationService.messages, isEmpty);
      expect(conversationService.isLoading, isFalse);
    });

    test('should clear conversation', () {
      // Add some messages first
      conversationService.clearConversation();

      expect(conversationService.messages, isEmpty);
    });

    test('should have system prompt', () {
      expect(conversationService.systemPrompt, isNotEmpty);
    });
  });
}
