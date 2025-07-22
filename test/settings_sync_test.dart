import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/language_settings_service.dart';
import '../lib/services/settings_service.dart';
import '../lib/services/user_service.dart';
import '../lib/models/user.dart';

// Generate mocks
@GenerateMocks([UserService])
import 'settings_sync_test.mocks.dart';

void main() {
  group('Settings Sync Tests', () {
    late LanguageSettings languageSettings;
    late SettingsService settingsService;
    late MockUserService mockUserService;
    late User testUser;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});

      // Create mock user service
      mockUserService = MockUserService();

      // Create test user with specific preferences
      testUser = User(
        id: 'test-user-id',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        isPremium: true,
        createdAt: DateTime.now(),
        preferences: UserPreferences(
          targetLanguage: 'fr', // French
          nativeLanguage: 'es', // Spanish
          supportLanguage1: 'de', // German
          supportLanguage2: 'pt', // Portuguese
          notificationsEnabled: false,
          soundEnabled: false,
          theme: 'dark',
          aiProvider: 'openai',
          maxVerbs: 10,
          maxNouns: 20,
        ),
        statistics: UserStatistics(
          totalWordsLearned: 0,
          totalMessagesProcessed: 0,
          streakDays: 0,
          languageProgress: {},
          totalStudyTimeMinutes: 0,
        ),
      );

      // Setup mock to return our test user
      when(mockUserService.currentUser).thenReturn(testUser);

      // Create services (they auto-initialize)
      languageSettings = LanguageSettings();
      settingsService = SettingsService();
    });

    group('LanguageSettings Sync', () {
      test('should sync FROM Supabase when UserService is set', () async {
        // Act: Connect to UserService (simulates app startup)
        languageSettings.setUserService(mockUserService);

        // Wait for async operations
        await Future.delayed(Duration(milliseconds: 100));

        // Assert: Language settings should match user preferences
        expect(languageSettings.targetLanguage?.code, equals('fr'));
        expect(languageSettings.nativeLanguage?.code, equals('es'));
        expect(languageSettings.supportLanguage1?.code, equals('de'));
        expect(languageSettings.supportLanguage2?.code, equals('pt'));
      });

      test('should sync TO Supabase when language settings change', () async {
        // Arrange: Connect to UserService first
        languageSettings.setUserService(mockUserService);
        await Future.delayed(Duration(milliseconds: 100));

        // Act: Change target language
        final newTargetLanguage = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'ja');
        await languageSettings.setTargetLanguage(newTargetLanguage);

        // Assert: UserService.updatePreferences should be called
        verify(mockUserService.updatePreferences(any)).called(1);

        // Verify the new preferences contain the updated language
        final capturedPrefs =
            verify(mockUserService.updatePreferences(captureAny))
                .captured
                .single as UserPreferences;
        expect(capturedPrefs.targetLanguage, equals('ja'));
      });

      test('should handle null UserService gracefully', () async {
        // Act: Try to change settings without UserService
        final newTargetLanguage = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'it');

        // Should not throw exception
        expect(() async {
          await languageSettings.setTargetLanguage(newTargetLanguage);
        }, returnsNormally);

        // Should still update local settings
        expect(languageSettings.targetLanguage?.code, equals('it'));
      });
    });

    group('SettingsService Sync', () {
      test('should sync FROM Supabase when UserService is set', () async {
        // Act: Connect to UserService (simulates app startup)
        settingsService.setUserService(mockUserService);

        // Wait for async operations
        await Future.delayed(Duration(milliseconds: 100));

        // Assert: Settings should match user preferences
        expect(settingsService.currentProvider, equals(AIProvider.openai));
        expect(settingsService.maxVerbs, equals(10));
        expect(settingsService.maxNouns, equals(20));
      });

      test('should sync TO Supabase when AI settings change', () async {
        // Arrange: Connect to UserService first
        settingsService.setUserService(mockUserService);
        await Future.delayed(Duration(milliseconds: 100));

        // Act: Change AI provider
        await settingsService.setProvider(AIProvider.gemini);

        // Assert: UserService.updatePreferences should be called
        verify(mockUserService.updatePreferences(any)).called(1);

        // Verify the new preferences contain the updated provider
        final capturedPrefs =
            verify(mockUserService.updatePreferences(captureAny))
                .captured
                .single as UserPreferences;
        expect(capturedPrefs.aiProvider, equals('gemini'));
      });
    });

    group('Error Handling', () {
      test('should handle UserService errors gracefully', () async {
        // Arrange: Setup UserService to throw error
        when(mockUserService.updatePreferences(any))
            .thenThrow(Exception('Supabase error'));

        languageSettings.setUserService(mockUserService);
        await Future.delayed(Duration(milliseconds: 100));

        // Act: Change settings (should not crash)
        final newTargetLanguage = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'en');

        expect(() async {
          await languageSettings.setTargetLanguage(newTargetLanguage);
        }, returnsNormally);

        // Assert: Local settings should still be updated
        expect(languageSettings.targetLanguage?.code, equals('en'));
      });

      test('should handle null user preferences', () async {
        // Arrange: UserService returns user without preferences
        when(mockUserService.currentUser).thenReturn(null);

        // Act: Should not crash when connecting to UserService
        expect(() {
          languageSettings.setUserService(mockUserService);
          settingsService.setUserService(mockUserService);
        }, returnsNormally);
      });
    });
  });
}
