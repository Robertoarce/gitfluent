import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llm_chat_app/services/user_preferences_service.dart';
import 'package:llm_chat_app/services/language_settings_service.dart';
import 'package:llm_chat_app/services/prompts.dart';
import 'package:llm_chat_app/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Persistence Integration Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('User login/logout language persistence scenario', () async {
      // Initialize services
      final userPreferencesService = UserPreferencesService();
      final languageSettings = LanguageSettings();

      // Initialize both services
      await userPreferencesService.init();
      await languageSettings.init();

      // Setup callback communication (simulating what main.dart does)
      UserPreferencesService.setLanguageSettingsCallback((languageMap) {
        languageSettings.updateFromExternalSource(
          targetLanguageCode: languageMap['target_language'],
          nativeLanguageCode: languageMap['native_language'],
          supportLanguage1Code:
              languageMap['support_language_1']?.isNotEmpty == true
                  ? languageMap['support_language_1']
                  : null,
          supportLanguage2Code:
              languageMap['support_language_2']?.isNotEmpty == true
                  ? languageMap['support_language_2']
                  : null,
        );
      });

      // Step 1: User changes language to Spanish while logged out (guest mode)
      await userPreferencesService.updateLanguagePreferences(
        targetLanguage: 'es',
        nativeLanguage: 'en',
      );

      // Verify language settings are updated
      expect(languageSettings.targetLanguage?.code, equals('es'));
      expect(languageSettings.nativeLanguage?.code, equals('en'));

      // Verify initial bot message is in Spanish
      expect(Prompts.getInitialBotMessage('es').contains('¡Hola!'), true);

      // Step 2: Simulate user logging in by changing user ID
      SharedPreferences.setMockInitialValues({});
      final mockUserId = 'user123';

      // Create user preferences for this user with different language (Italian)
      final userPrefs = UserPreferences(
        targetLanguage: 'it',
        nativeLanguage: 'en',
        supportLanguage1: 'fr',
        supportLanguage2: 'de',
      );

      // Set the mock data as if user is logging in with Italian preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_preferences_$mockUserId', userPrefs.toJson());

      // Simulate login by loading user preferences
      final userPrefsJson = prefs.getString('user_preferences_$mockUserId');
      final loadedPrefs = UserPreferences.fromJson(userPrefsJson!);

      // Manually update userPreferencesService as if user logged in
      await userPreferencesService.updateLanguagePreferences(
        targetLanguage: loadedPrefs.targetLanguage,
        nativeLanguage: loadedPrefs.nativeLanguage,
        supportLanguage1: loadedPrefs.supportLanguage1,
        supportLanguage2: loadedPrefs.supportLanguage2,
      );

      // Step 3: Verify that language settings are now Italian (user's preferences)
      expect(languageSettings.targetLanguage?.code, equals('it'));
      expect(languageSettings.nativeLanguage?.code, equals('en'));

      // Verify initial bot message is now in Italian
      expect(Prompts.getInitialBotMessage('it').contains('Ciao!'), true);

      // Step 4: User changes language to German while logged in
      await userPreferencesService.updateLanguagePreferences(
        targetLanguage: 'de',
        nativeLanguage: 'en',
      );

      // Verify settings are updated
      expect(languageSettings.targetLanguage?.code, equals('de'));

      // Verify initial bot message is now in German
      expect(Prompts.getInitialBotMessage('de').contains('Hallo!'), true);

      // Step 5: Simulate logout and login again
      SharedPreferences.setMockInitialValues({
        'user_preferences_$mockUserId': UserPreferences(
          targetLanguage: 'de',
          nativeLanguage: 'en',
        ).toJson(),
      });

      // Reload services as if app restarted
      final newUserPreferencesService = UserPreferencesService();
      final newLanguageSettings = LanguageSettings();

      await newUserPreferencesService.init();
      await newLanguageSettings.init();

      // Setup callback again
      UserPreferencesService.setLanguageSettingsCallback((languageMap) {
        newLanguageSettings.updateFromExternalSource(
          targetLanguageCode: languageMap['target_language'],
          nativeLanguageCode: languageMap['native_language'],
        );
      });

      // Simulate loading user preferences after login
      final reloadedPrefs = await SharedPreferences.getInstance();
      final reloadedUserPrefsJson =
          reloadedPrefs.getString('user_preferences_$mockUserId');
      final reloadedUserPrefs =
          UserPreferences.fromJson(reloadedUserPrefsJson!);

      await newUserPreferencesService.updateLanguagePreferences(
        targetLanguage: reloadedUserPrefs.targetLanguage,
        nativeLanguage: reloadedUserPrefs.nativeLanguage,
      );

      // Step 6: Verify that the user's German preference persisted
      expect(newLanguageSettings.targetLanguage?.code, equals('de'));
      expect(Prompts.getInitialBotMessage('de').contains('Hallo!'), true);
    });

    test('Multi-language initial bot message coverage', () {
      // Test all supported languages
      final testCases = {
        'en': 'Hello!',
        'es': '¡Hola!',
        'fr': 'Bonjour',
        'de': 'Hallo',
        'it': 'Ciao',
        'pt': 'Olá',
        'ru': 'Привет',
        'zh': '你好',
        'ja': 'こんにちは',
        'ko': '안녕하세요',
        'nl': 'Hallo',
        'el': 'Γεια σας',
        'he': 'שלום',
        'hi': 'नमस्ते',
        'ga': 'Dia dhuit',
        'pl': 'Cześć',
        'sv': 'Hej',
        'vi': 'Xin chào',
      };

      for (final entry in testCases.entries) {
        final languageCode = entry.key;
        final expectedGreeting = entry.value;
        final message = Prompts.getInitialBotMessage(languageCode);

        expect(message.contains(expectedGreeting), true,
            reason:
                'Language $languageCode should contain "$expectedGreeting" but got: $message');
        expect(message.isNotEmpty, true);
      }

      // Test fallback for unknown language
      expect(Prompts.getInitialBotMessage('unknown'),
          "Hello! I'm your conversation partner. How can I help you practice today?");
    });

    test('Callback communication system works', () async {
      bool callbackTriggered = false;
      String? receivedTargetLanguage;

      // Setup callback
      UserPreferencesService.setLanguageSettingsCallback((languageMap) {
        callbackTriggered = true;
        receivedTargetLanguage = languageMap['target_language'];
      });

      // Initialize service
      final userPreferencesService = UserPreferencesService();
      await userPreferencesService.init();

      // Update preferences
      await userPreferencesService.updateLanguagePreferences(
        targetLanguage: 'fr',
      );

      // Verify callback was triggered
      expect(callbackTriggered, true);
      expect(receivedTargetLanguage, equals('fr'));
    });
  });
}
