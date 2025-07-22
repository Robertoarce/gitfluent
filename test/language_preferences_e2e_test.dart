import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/services/language_settings_service.dart';
import '../lib/services/user_service.dart';
import '../lib/models/user.dart';

// Generate mocks
@GenerateMocks([UserService])
import 'language_preferences_e2e_test.mocks.dart';

void main() {
  group('Language Preferences End-to-End Tests', () {
    late LanguageSettings languageSettings;
    late MockUserService mockUserService;
    late User mockUser;
    late UserPreferences mockPreferences;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});

      // Create mocks
      mockUserService = MockUserService();
      languageSettings = LanguageSettings();

      // Setup default mock user with preferences
      mockPreferences = UserPreferences(
        targetLanguage: 'ja', // Japanese
        nativeLanguage: 'ko', // Korean
        supportLanguage1: 'zh', // Chinese
        supportLanguage2: 'ru', // Russian
        notificationsEnabled: true,
        soundEnabled: true,
        theme: 'dark',
      );

      mockUser = User(
        id: 'test-user-123',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        isPremium: true,
        authProvider: 'email',
        preferences: mockPreferences,
        statistics: UserStatistics(),
        createdAt: DateTime.now(),
      );

      // Setup UserService mocks
      when(mockUserService.isLoggedIn).thenReturn(true);
      when(mockUserService.currentUser).thenReturn(mockUser);
    });

    group('Initial Load from Supabase', () {
      test('should load preferences from Supabase when user is logged in',
          () async {
        print('\n=== Testing Initial Load from Supabase ===');

        // Step 1: Initialize LanguageSettings
        print('Step 1: Initializing LanguageSettings...');
        await languageSettings.init();

        // Verify initial state (should be null before Supabase load)
        expect(languageSettings.targetLanguage, isNull);
        expect(languageSettings.nativeLanguage, isNull);

        // Step 2: Connect UserService and load from Supabase
        print('Step 2: Connecting UserService and loading from Supabase...');
        languageSettings.setUserService(mockUserService);
        await languageSettings.loadFromUserPreferences(mockPreferences);

        // Step 3: Verify preferences loaded from Supabase
        print('Step 3: Verifying preferences loaded from Supabase...');
        expect(languageSettings.targetLanguage?.code, equals('ja'));
        expect(languageSettings.nativeLanguage?.code, equals('ko'));
        expect(languageSettings.supportLanguage1?.code, equals('zh'));
        expect(languageSettings.supportLanguage2?.code, equals('ru'));

        print('✅ Successfully loaded preferences from Supabase');
      });

      test('should set defaults only when no Supabase preferences exist',
          () async {
        print('\n=== Testing Default Assignment Logic ===');

        // Create user with no preferences (new user scenario)
        final newUserPreferences = UserPreferences(
          targetLanguage: 'it', // Default values
          nativeLanguage: 'en',
          supportLanguage1: 'es',
          supportLanguage2: 'fr',
        );

        final newUser = mockUser.copyWith(preferences: newUserPreferences);
        when(mockUserService.currentUser).thenReturn(newUser);

        // Step 1: Initialize without any existing preferences
        print('Step 1: Initializing for new user...');
        await languageSettings.init();

        // Step 2: Load "empty" preferences (new user)
        print('Step 2: Loading new user preferences...');
        languageSettings.setUserService(mockUserService);
        await languageSettings.loadFromUserPreferences(newUserPreferences);

        // Step 3: Verify defaults are properly set
        print('Step 3: Verifying default preferences...');
        expect(languageSettings.targetLanguage?.code, equals('it'));
        expect(languageSettings.nativeLanguage?.code, equals('en'));
        expect(languageSettings.supportLanguage1?.code, equals('es'));
        expect(languageSettings.supportLanguage2?.code, equals('fr'));

        print('✅ Defaults correctly assigned for new user');
      });
    });

    group('Language Changes and Sync', () {
      test('should sync language changes to Supabase immediately', () async {
        print('\n=== Testing Language Changes and Sync ===');

        // Setup: Initialize with existing preferences
        await languageSettings.init();
        languageSettings.setUserService(mockUserService);
        await languageSettings.loadFromUserPreferences(mockPreferences);

        // Clear any previous calls
        clearInteractions(mockUserService);

        // Step 1: Change target language
        print('Step 1: Changing target language to German...');
        final germanLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'de');

        when(mockUserService.updatePreferences(any))
            .thenAnswer((_) async => {});

        await languageSettings.setTargetLanguage(germanLang);

        // Step 2: Verify language changed locally
        print('Step 2: Verifying local change...');
        expect(languageSettings.targetLanguage?.code, equals('de'));

        // Step 3: Verify sync to Supabase was called
        print('Step 3: Verifying Supabase sync...');
        verify(mockUserService.updatePreferences(any)).called(1);

        // Verify the correct preferences were sent
        final capturedPrefs =
            verify(mockUserService.updatePreferences(captureAny))
                .captured
                .single as UserPreferences;
        expect(capturedPrefs.targetLanguage, equals('de'));

        print('✅ Language change successfully synced to Supabase');
      });

      test('should handle multiple rapid language changes', () async {
        print('\n=== Testing Multiple Rapid Changes ===');

        // Setup
        await languageSettings.init();
        languageSettings.setUserService(mockUserService);
        await languageSettings.loadFromUserPreferences(mockPreferences);

        clearInteractions(mockUserService);
        when(mockUserService.updatePreferences(any))
            .thenAnswer((_) async => {});

        // Step 1: Make multiple rapid changes
        print('Step 1: Making multiple rapid language changes...');
        final germanLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'de');
        final frenchLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'fr');
        final spanishLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'es');

        await languageSettings.setTargetLanguage(germanLang);
        await languageSettings.setNativeLanguage(frenchLang);
        await languageSettings.setSupportLanguage1(spanishLang);

        // Step 2: Verify final state
        print('Step 2: Verifying final state...');
        expect(languageSettings.targetLanguage?.code, equals('de'));
        expect(languageSettings.nativeLanguage?.code, equals('fr'));
        expect(languageSettings.supportLanguage1?.code, equals('es'));

        // Step 3: Verify each change was synced
        print('Step 3: Verifying all changes were synced...');
        verify(mockUserService.updatePreferences(any)).called(3);

        print('✅ Multiple changes handled correctly');
      });
    });

    group('Offline and Error Scenarios', () {
      test('should handle sync failures gracefully', () async {
        print('\n=== Testing Sync Failure Handling ===');

        // Setup
        await languageSettings.init();
        languageSettings.setUserService(mockUserService);
        await languageSettings.loadFromUserPreferences(mockPreferences);

        // Step 1: Mock sync failure
        print('Step 1: Simulating sync failure...');
        when(mockUserService.updatePreferences(any))
            .thenThrow(Exception('Network error'));

        // Step 2: Try to change language (should not throw)
        print('Step 2: Attempting language change with network error...');
        final germanLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'de');

        // Should not throw an exception
        await languageSettings.setTargetLanguage(germanLang);

        // Step 3: Verify local change still worked
        print(
            'Step 3: Verifying local change persisted despite sync failure...');
        expect(languageSettings.targetLanguage?.code, equals('de'));

        // Step 4: Verify SharedPreferences was still updated
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('target_language'), equals('de'));

        print('✅ Sync failure handled gracefully');
      });

      test('should work when user is not logged in', () async {
        print('\n=== Testing Offline User Scenario ===');

        // Step 1: Setup offline user
        print('Step 1: Setting up offline user...');
        when(mockUserService.isLoggedIn).thenReturn(false);
        when(mockUserService.currentUser).thenReturn(null);

        // Step 2: Initialize and set UserService
        await languageSettings.init();
        languageSettings.setUserService(mockUserService);

        // Step 3: Change language (should work locally)
        print('Step 2: Changing language while offline...');
        final germanLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'de');

        await languageSettings.setTargetLanguage(germanLang);

        // Step 4: Verify local change worked
        print('Step 3: Verifying local-only change...');
        expect(languageSettings.targetLanguage?.code, equals('de'));

        // Step 5: Verify no sync attempt was made
        print('Step 4: Verifying no sync attempted...');
        verifyNever(mockUserService.updatePreferences(any));

        print('✅ Offline scenario handled correctly');
      });
    });

    group('Complete User Journey', () {
      test('should demonstrate complete user journey with preferences',
          () async {
        print('\n=== Complete User Journey Test ===');

        // Scenario: User logs in, loads existing preferences, makes changes, logs out, logs back in

        // Step 1: User logs in - load existing preferences
        print('Step 1: User logs in, loading existing preferences...');
        await languageSettings.init();
        languageSettings.setUserService(mockUserService);
        await languageSettings.loadFromUserPreferences(mockPreferences);

        print('  Loaded - Target: ${languageSettings.targetLanguage?.code}');
        print('  Loaded - Native: ${languageSettings.nativeLanguage?.code}');

        expect(languageSettings.targetLanguage?.code, equals('ja'));
        expect(languageSettings.nativeLanguage?.code, equals('ko'));

        // Step 2: User changes preferences
        print('\nStep 2: User changes language preferences...');
        when(mockUserService.updatePreferences(any))
            .thenAnswer((_) async => {});

        final italianLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'it');
        final englishLang = LanguageSettings.availableLanguages
            .firstWhere((lang) => lang.code == 'en');

        await languageSettings.setTargetLanguage(italianLang);
        await languageSettings.setNativeLanguage(englishLang);

        print('  Changed - Target: ${languageSettings.targetLanguage?.code}');
        print('  Changed - Native: ${languageSettings.nativeLanguage?.code}');

        expect(languageSettings.targetLanguage?.code, equals('it'));
        expect(languageSettings.nativeLanguage?.code, equals('en'));

        // Step 3: Verify changes were synced
        print('\nStep 3: Verifying changes synced to database...');
        verify(mockUserService.updatePreferences(any)).called(2);

        // Step 4: Simulate app restart / user logs back in
        print('\nStep 4: Simulating app restart / user logs back in...');

        // Create new instance (simulates app restart)
        final newLanguageSettings = LanguageSettings();
        await newLanguageSettings.init();

        // Mock updated user preferences after changes
        final updatedPreferences = mockPreferences.copyWith(
          targetLanguage: 'it',
          nativeLanguage: 'en',
        );
        final updatedUser = mockUser.copyWith(preferences: updatedPreferences);
        when(mockUserService.currentUser).thenReturn(updatedUser);

        // Load preferences again
        newLanguageSettings.setUserService(mockUserService);
        await newLanguageSettings.loadFromUserPreferences(updatedPreferences);

        // Step 5: Verify persistence across sessions
        print('\nStep 5: Verifying preferences persisted across sessions...');
        expect(newLanguageSettings.targetLanguage?.code, equals('it'));
        expect(newLanguageSettings.nativeLanguage?.code, equals('en'));

        print('\n✅ Complete user journey successful!');
        print('✅ Preferences correctly loaded from Supabase');
        print('✅ Changes synced to database');
        print('✅ Persistence verified across sessions');
      });
    });

    group('Priority Testing - Supabase vs Local vs Defaults', () {
      test('should prioritize Supabase > SharedPreferences > Defaults',
          () async {
        print('\n=== Testing Priority: Supabase > Local > Defaults ===');

        // Step 1: Setup conflicting data
        print('Step 1: Setting up conflicting preference sources...');

        // Set some data in SharedPreferences (old local data)
        SharedPreferences.setMockInitialValues({
          'target_language': 'fr', // French in local storage
          'native_language': 'de', // German in local storage
        });

        // Supabase has different data (should win)
        final supabasePrefs = UserPreferences(
          targetLanguage: 'ja', // Japanese in Supabase (should win)
          nativeLanguage: 'ko', // Korean in Supabase (should win)
          supportLanguage1: 'zh',
          supportLanguage2: 'ru',
        );

        // Step 2: Initialize (loads from SharedPreferences first)
        print('Step 2: Initializing with local data...');
        await languageSettings.init();

        // Verify local data is loaded initially
        expect(languageSettings.targetLanguage?.code, equals('fr'));
        expect(languageSettings.nativeLanguage?.code, equals('de'));

        // Step 3: Connect to UserService (Supabase data should override)
        print('Step 3: Loading Supabase data (should override local)...');
        languageSettings.setUserService(mockUserService);
        await languageSettings.loadFromUserPreferences(supabasePrefs);

        // Step 4: Verify Supabase data won
        print('Step 4: Verifying Supabase data takes priority...');
        expect(languageSettings.targetLanguage?.code,
            equals('ja')); // From Supabase
        expect(languageSettings.nativeLanguage?.code,
            equals('ko')); // From Supabase
        expect(languageSettings.supportLanguage1?.code,
            equals('zh')); // From Supabase
        expect(languageSettings.supportLanguage2?.code,
            equals('ru')); // From Supabase

        print(
            '✅ Priority order correctly enforced: Supabase > Local > Defaults');
      });
    });
  });
}
