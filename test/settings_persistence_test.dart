import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/language_settings_service.dart';
import '../lib/services/settings_service.dart';
import '../lib/models/user.dart';

void main() {
  group('Settings Persistence Integration Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('Language Settings Local Persistence', () {
      test('should persist language settings locally', () async {
        // Create first instance of LanguageSettings
        final languageSettings1 = LanguageSettings();

        // Initialize and wait for defaults to be set
        await languageSettings1.init();

        // Change some settings
        final frenchLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'fr');
        final germanLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'de');

        await languageSettings1.setTargetLanguage(frenchLang);
        await languageSettings1.setNativeLanguage(germanLang);

        // Verify the settings are set
        expect(languageSettings1.targetLanguage?.code, equals('fr'));
        expect(languageSettings1.nativeLanguage?.code, equals('de'));

        // Create new instance (simulating app restart)
        final languageSettings2 = LanguageSettings();

        // Wait for initialization to complete
        await languageSettings2.init();

        // Settings should be loaded from SharedPreferences
        expect(languageSettings2.targetLanguage?.code, equals('fr'));
        expect(languageSettings2.nativeLanguage?.code, equals('de'));
      });

      test(
          'should set defaults when no preferences exist locally or in database',
          () async {
        print('\n=== Testing Default Assignment When No Preferences Exist ===');

        // Create settings service with empty SharedPreferences (new user scenario)
        final languageSettings = LanguageSettings();

        // Initialize and verify defaults are set
        await languageSettings.init();

        print('Step 1: Verifying defaults are set for new user...');
        expect(languageSettings.targetLanguage?.code, equals('it')); // Default
        expect(languageSettings.nativeLanguage?.code, equals('en')); // Default
        expect(
            languageSettings.supportLanguage1?.code, equals('es')); // Default
        expect(
            languageSettings.supportLanguage2?.code, equals('fr')); // Default

        print('  ✓ All default languages set correctly');
        print(
            '  ✓ Defaults: IT (target), EN (native), ES (support1), FR (support2)');

        print('✅ Default assignment test passed');
      });
    });

    group('AI Settings Local Persistence', () {
      test('should persist AI settings locally', () async {
        // Create first instance of SettingsService
        final settingsService1 = SettingsService();

        // Initialize
        await settingsService1.init();

        // Change some settings
        await settingsService1.setProvider(AIProvider.openai);
        await settingsService1.setMaxVerbs(15);
        await settingsService1.setMaxNouns(25);

        // Verify the settings are set
        expect(settingsService1.currentProvider, equals(AIProvider.openai));
        expect(settingsService1.maxVerbs, equals(15));
        expect(settingsService1.maxNouns, equals(25));

        // Create new instance (simulating app restart)
        final settingsService2 = SettingsService();

        // Wait for initialization to complete
        await settingsService2.init();

        // Settings should be loaded from SharedPreferences
        expect(settingsService2.currentProvider, equals(AIProvider.openai));
        expect(settingsService2.maxVerbs, equals(15));
        expect(settingsService2.maxNouns, equals(25));
      });
    });

    group('Settings Synchronization Scenarios', () {
      test('should handle settings changes in sequence', () async {
        final languageSettings = LanguageSettings();
        final settingsService = SettingsService();

        await languageSettings.init();
        await settingsService.init();

        // Make multiple changes
        await languageSettings.setTargetLanguage(
          LanguageSettings.availableLanguages
              .firstWhere((lang) => lang.code == 'es'),
        );
        await settingsService.setProvider(AIProvider.openai);
        await settingsService.setMaxVerbs(8);

        // Verify both services maintain their settings
        expect(languageSettings.targetLanguage?.code, equals('es'));
        expect(settingsService.currentProvider, equals(AIProvider.openai));
        expect(settingsService.maxVerbs, equals(8));

        // Create new instances (app restart simulation)
        final newLanguageSettings = LanguageSettings();
        final newSettingsService = SettingsService();

        await newLanguageSettings.init();
        await newSettingsService.init();

        // Wait for initialization to complete
        await Future.delayed(Duration(milliseconds: 100));

        // Both should persist their settings
        expect(newLanguageSettings.targetLanguage?.code, equals('es'));
        expect(newSettingsService.currentProvider, equals(AIProvider.openai));
        expect(newSettingsService.maxVerbs, equals(8));
      });
    });

    group('End-to-End Supabase Integration Scenarios', () {
      test('should demonstrate priority: Supabase > Local > Defaults',
          () async {
        print('\n=== TESTING PRIORITY: SUPABASE > LOCAL > DEFAULTS ===');

        // Step 1: Setup conflicting data sources
        print('Step 1: Setting up conflicting preference sources...');

        // Set some data in SharedPreferences (old local data)
        SharedPreferences.setMockInitialValues({
          'target_language': 'fr', // French in local storage
          'native_language': 'de', // German in local storage
        });

        // Step 2: Initialize language settings (loads from local first)
        print('Step 2: Initializing with local data...');
        final languageSettings = LanguageSettings();
        await languageSettings.init();

        // Verify local data is loaded initially
        expect(languageSettings.targetLanguage?.code, equals('fr'));
        expect(languageSettings.nativeLanguage?.code, equals('de'));
        print('  ✓ Local storage data loaded initially');

        // Step 3: Simulate Supabase preferences loading (should override local)
        print('Step 3: Simulating Supabase data load...');
        final supabasePrefs = UserPreferences(
          targetLanguage: 'ja', // Japanese from Supabase (should win)
          nativeLanguage: 'ko', // Korean from Supabase (should win)
          supportLanguage1: 'zh',
          supportLanguage2: 'ru',
        );

        // Use the new loadFromUserPreferences method to simulate Supabase load
        await languageSettings.loadFromUserPreferences(supabasePrefs);

        // Step 4: Verify Supabase data takes priority
        print('Step 4: Verifying Supabase data overrode local data...');
        expect(languageSettings.targetLanguage?.code,
            equals('ja')); // From Supabase
        expect(languageSettings.nativeLanguage?.code,
            equals('ko')); // From Supabase
        expect(languageSettings.supportLanguage1?.code,
            equals('zh')); // From Supabase
        expect(languageSettings.supportLanguage2?.code,
            equals('ru')); // From Supabase

        print('  ✓ Supabase data correctly overrode local storage');
        print(
            '✅ Priority order correctly enforced: Supabase > Local > Defaults');
      });

      test('should only assign defaults when no Supabase preferences exist',
          () async {
        print('\n=== TESTING DEFAULT ASSIGNMENT LOGIC ===');

        // Step 1: Test new user scenario (no local, no Supabase)
        print(
            'Step 1: Testing completely new user (no preferences anywhere)...');
        final newUserSettings = LanguageSettings();
        await newUserSettings.init();

        // Should have defaults
        expect(newUserSettings.targetLanguage?.code, equals('it')); // Default
        expect(newUserSettings.nativeLanguage?.code, equals('en')); // Default
        print('  ✓ Defaults set for completely new user');

        // Step 2: Test user with Supabase preferences
        print('Step 2: Testing user with existing Supabase preferences...');
        final existingUserSettings = LanguageSettings();
        await existingUserSettings.init();

        // Simulate loading from Supabase (existing user)
        final existingPrefs = UserPreferences(
          targetLanguage: 'de', // German
          nativeLanguage: 'fr', // French
          supportLanguage1: 'es',
          supportLanguage2: 'pt',
        );

        await existingUserSettings.loadFromUserPreferences(existingPrefs);

        // Should use Supabase preferences, not defaults
        expect(existingUserSettings.targetLanguage?.code,
            equals('de')); // From Supabase
        expect(existingUserSettings.nativeLanguage?.code,
            equals('fr')); // From Supabase
        print('  ✓ Supabase preferences loaded, defaults not used');

        print('✅ Default assignment logic working correctly');
      });

      test('should handle user preference changes and sync simulation',
          () async {
        print('\n=== TESTING USER PREFERENCE CHANGES ===');

        // Step 1: Initialize with existing preferences
        print('Step 1: User logs in with existing preferences...');
        final languageSettings = LanguageSettings();
        await languageSettings.init();

        final initialPrefs = UserPreferences(
          targetLanguage: 'ja', // Japanese
          nativeLanguage: 'ko', // Korean
          supportLanguage1: 'zh',
          supportLanguage2: 'ru',
        );

        await languageSettings.loadFromUserPreferences(initialPrefs);

        expect(languageSettings.targetLanguage?.code, equals('ja'));
        expect(languageSettings.nativeLanguage?.code, equals('ko'));
        print('  ✓ Initial preferences loaded from Supabase');

        // Step 2: User changes preferences
        print('Step 2: User changes language preferences...');
        final italianLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'it');
        final englishLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'en');

        await languageSettings.setTargetLanguage(italianLang);
        await languageSettings.setNativeLanguage(englishLang);

        expect(languageSettings.targetLanguage?.code, equals('it'));
        expect(languageSettings.nativeLanguage?.code, equals('en'));
        print('  ✓ Language preferences changed successfully');

        // Step 3: Verify changes persist locally
        print('Step 3: Verifying local persistence...');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('target_language'), equals('it'));
        expect(prefs.getString('native_language'), equals('en'));
        print('  ✓ Changes persisted to local storage');

        // Step 4: Simulate app restart with updated Supabase data
        print('Step 4: Simulating app restart with updated Supabase data...');
        final newLanguageSettings = LanguageSettings();
        await newLanguageSettings.init();

        // Simulate loading updated preferences from Supabase
        final updatedPrefs = UserPreferences(
          targetLanguage: 'it', // Updated from user changes
          nativeLanguage: 'en', // Updated from user changes
          supportLanguage1: 'es',
          supportLanguage2: 'fr',
        );

        await newLanguageSettings.loadFromUserPreferences(updatedPrefs);

        expect(newLanguageSettings.targetLanguage?.code, equals('it'));
        expect(newLanguageSettings.nativeLanguage?.code, equals('en'));
        print('  ✓ Updated preferences loaded correctly after restart');

        print('✅ User preference change cycle completed successfully');
      });
    });

    group('Real World Test Scenarios', () {
      test('should demonstrate the actual persistence issue', () async {
        print('\n=== TESTING SETTINGS PERSISTENCE ===');

        // Step 1: Create services and change settings
        print('Step 1: Creating services and changing settings...');
        final languageSettings1 = LanguageSettings();
        final settingsService1 = SettingsService();

        await languageSettings1.init();
        await settingsService1.init();

        // Wait for initialization to complete
        await Future.delayed(Duration(milliseconds: 100));

        print(
            'Initial target language: ${languageSettings1.targetLanguage?.code}');
        print('Initial AI provider: ${settingsService1.currentProvider}');

        // Change settings
        final koreanLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'ko');
        await languageSettings1.setTargetLanguage(koreanLang);
        await settingsService1.setProvider(AIProvider.openai);
        await settingsService1.setMaxVerbs(15);

        print(
            'Changed target language to: ${languageSettings1.targetLanguage?.code}');
        print('Changed AI provider to: ${settingsService1.currentProvider}');
        print('Changed max verbs to: ${settingsService1.maxVerbs}');

        // Step 2: Simulate app restart by creating new instances
        print('\nStep 2: Simulating app restart...');
        final languageSettings2 = LanguageSettings();
        final settingsService2 = SettingsService();

        await languageSettings2.init();
        await settingsService2.init();

        // Wait for the new instances to initialize and load from SharedPreferences
        await Future.delayed(Duration(milliseconds: 200));

        print(
            'After restart - target language: ${languageSettings2.targetLanguage?.code}');
        print(
            'After restart - AI provider: ${settingsService2.currentProvider}');
        print('After restart - max verbs: ${settingsService2.maxVerbs}');

        // Step 3: Verify persistence
        print('\nStep 3: Verifying persistence...');
        final languagePersisted =
            languageSettings2.targetLanguage?.code == 'ko';
        final aiProviderPersisted =
            settingsService2.currentProvider == AIProvider.openai;
        final maxVerbsPersisted = settingsService2.maxVerbs == 15;

        print('Language settings persisted: $languagePersisted');
        print('AI provider persisted: $aiProviderPersisted');
        print('Max verbs persisted: $maxVerbsPersisted');

        // Assert results
        expect(languagePersisted, isTrue,
            reason: 'Language settings should persist across app restarts');
        expect(aiProviderPersisted, isTrue,
            reason: 'AI provider should persist across app restarts');
        expect(maxVerbsPersisted, isTrue,
            reason: 'Max verbs should persist across app restarts');

        print('\n✅ All settings successfully persisted!');
      });
    });
  });
}
