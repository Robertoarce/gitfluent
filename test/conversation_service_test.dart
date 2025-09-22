import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/services/conversation_service.dart';
import '../lib/services/settings_service.dart';
import '../lib/services/language_settings_service.dart';
import '../lib/services/vocabulary_service.dart';

// Generate mocks
@GenerateMocks([SettingsService, LanguageSettings, VocabularyService])
import 'conversation_service_test.mocks.dart';

void main() {
  group('ConversationService', () {
    late ConversationService conversationService;
    late MockSettingsService mockSettingsService;
    late MockLanguageSettings mockLanguageSettings;
    late MockVocabularyService mockVocabularyService;

    setUp(() {
      mockSettingsService = MockSettingsService();
      mockLanguageSettings = MockLanguageSettings();
      mockVocabularyService = MockVocabularyService();

      conversationService = ConversationService(
        settings: mockSettingsService,
        languageSettings: mockLanguageSettings,
        vocabularyService: mockVocabularyService,
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
