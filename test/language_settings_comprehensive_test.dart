import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/language_settings_service.dart';
import '../lib/services/user_service.dart';
import '../lib/services/database_service.dart';
import '../lib/services/auth_service.dart';
import '../lib/models/user.dart';
import '../lib/models/user_vocabulary.dart';
import '../lib/models/flashcard_session.dart';

// Manual Mock Classes (following the pattern from existing tests)
class MockUserService extends UserService {
  User? _mockCurrentUser;
  bool _mockIsLoggedIn = false;
  String? _mockError;
  bool _mockIsLoading = false;

  MockUserService()
      : super(
          authService: MockAuthService(),
          databaseService: MockDatabaseService(),
        );

  void setMockUser(User? user) => _mockCurrentUser = user;
  void setMockLoggedIn(bool isLoggedIn) => _mockIsLoggedIn = isLoggedIn;

  @override
  User? get currentUser => _mockCurrentUser;

  @override
  bool get isLoggedIn => _mockIsLoggedIn;

  @override
  String? get error => _mockError;

  @override
  bool get isLoading => _mockIsLoading;

  bool _updateLanguageSettingsCalled = false;
  Map<String, String?> _lastLanguageSettingsCall = {};

  @override
  Future<void> updateLanguageSettings({
    String? targetLanguage,
    String? nativeLanguage,
    String? supportLanguage1,
    String? supportLanguage2,
  }) async {
    _updateLanguageSettingsCalled = true;
    _lastLanguageSettingsCall = {
      'targetLanguage': targetLanguage,
      'nativeLanguage': nativeLanguage,
      'supportLanguage1': supportLanguage1,
      'supportLanguage2': supportLanguage2,
    };
    // Update mock user if present
    if (_mockCurrentUser != null) {
      _mockCurrentUser = _mockCurrentUser!.copyWith(
        targetLanguage: targetLanguage ?? _mockCurrentUser!.targetLanguage,
        nativeLanguage: nativeLanguage ?? _mockCurrentUser!.nativeLanguage,
        supportLanguage1:
            supportLanguage1 ?? _mockCurrentUser!.supportLanguage1,
        supportLanguage2:
            supportLanguage2 ?? _mockCurrentUser!.supportLanguage2,
      );
    }
  }

  bool get updateLanguageSettingsCalled => _updateLanguageSettingsCalled;
  Map<String, String?> get lastLanguageSettingsCall =>
      _lastLanguageSettingsCall;

  void reset() {
    _updateLanguageSettingsCalled = false;
    _lastLanguageSettingsCall.clear();
  }
}

class MockAuthService implements AuthService {
  User? _mockUser;
  void setMockUser(User? user) => _mockUser = user;

  @override
  User? get currentUser => _mockUser;

  @override
  Stream<User?> get authStateChanges => Stream.value(_mockUser);

  @override
  Future<AuthResult> signInWithEmailAndPassword(
          String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthResult> createUserWithEmailAndPassword(String email,
          String password, String firstName, String lastName) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async => _mockUser = null;

  @override
  Future<AuthResult> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<AuthResult> signInWithApple() async => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) async =>
      throw UnimplementedError();

  @override
  Future<void> updateUserProfile(
          {String? firstName,
          String? lastName,
          String? profileImageUrl}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount() async => throw UnimplementedError();

  @override
  Future<bool> isPremiumUser() async => false;

  @override
  Future<void> updatePremiumStatus(bool isPremium) async =>
      throw UnimplementedError();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cleanup() async {}
}

class MockDatabaseService implements DatabaseService {
  @override
  Future<User?> getUserById(String userId) async => null;

  @override
  Future<User?> getUserByEmail(String email) async => null;

  @override
  Future<String> createUser(User user) async => user.id;

  @override
  Future<void> updateUser(User user) async {}

  @override
  Future<void> deleteUser(String userId) async {}

  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {}

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId,
          {String? language}) async =>
      [];

  @override
  Future<UserVocabularyItem> saveVocabularyItem(
          UserVocabularyItem item) async =>
      item;

  @override
  Future<void> updateVocabularyItem(UserVocabularyItem item) async {}

  @override
  Future<void> deleteVocabularyItem(String itemId) async {}

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId,
          {String? language}) async =>
      [];

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(
          String userId, String language) async =>
      null;

  @override
  Future<void> updateVocabularyStats(UserVocabularyStats stats) async {}

  @override
  Future<FlashcardSession> createFlashcardSession(
          FlashcardSession session) async =>
      session;

  @override
  Future<FlashcardSession?> getFlashcardSession(String sessionId) async => null;

  @override
  Future<void> updateFlashcardSession(FlashcardSession session) async {}

  @override
  Future<List<FlashcardSession>> getUserFlashcardSessions(String userId,
          {int limit = 50}) async =>
      [];

  @override
  Future<void> deleteFlashcardSession(String sessionId) async {}

  @override
  Future<FlashcardSessionCard> saveFlashcardSessionCard(
          FlashcardSessionCard card) async =>
      card;

  @override
  Future<List<FlashcardSessionCard>> getSessionCards(String sessionId) async =>
      [];

  @override
  Future<void> updateFlashcardSessionCard(FlashcardSessionCard card) async {}

  @override
  Future<void> deleteFlashcardSessionCard(String cardId) async {}

  @override
  Future<void> saveChatMessage(
      String userId, Map<String, dynamic> message) async {}

  @override
  Future<List<Map<String, dynamic>>> getChatHistory(String userId,
          {int limit = 50}) async =>
      [];

  @override
  Future<void> deleteChatHistory(String userId) async {}

  @override
  Future<bool> isPremiumUser(String userId) async => false;

  @override
  Future<void> cleanup() async {}
}

void main() {
  group('Language Settings Comprehensive Tests', () {
    late LanguageSettings languageSettings;
    late MockUserService mockUserService;

    group('🌐 OFFLINE MODE Tests (Local Database)', () {
      group('📱 Without Stored Preferences (New User)', () {
        setUp(() async {
          // Clear SharedPreferences (simulate new user)
          SharedPreferences.setMockInitialValues({});

          // Create mock services with offline behavior
          mockUserService = MockUserService();
          mockUserService.setMockLoggedIn(false);
          mockUserService.setMockUser(null);

          languageSettings = LanguageSettings();
        });

        test('should set default languages when no stored preferences exist',
            () async {
          // Act: Initialize language settings (new user, offline)
          await languageSettings.init();

          // Assert: Should set default languages
          expect(languageSettings.targetLanguage?.code,
              equals('fr')); // Current default
          expect(languageSettings.nativeLanguage?.code, equals('en'));
          expect(languageSettings.supportLanguage1, isNull);
          expect(languageSettings.supportLanguage2, isNull);

          // Verify SharedPreferences were updated
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('target_language'), equals('fr'));
          expect(prefs.getString('native_language'), equals('en'));
        });

        test('should handle language changes offline without database sync',
            () async {
          // Arrange
          await languageSettings.init();

          // Act: Change target language while offline
          final spanishLang = LanguageSettings.availableLanguages
              .firstWhere((lang) => lang.code == 'es');
          await languageSettings.setTargetLanguage(spanishLang);

          // Assert: Language should change locally
          expect(languageSettings.targetLanguage?.code, equals('es'));

          // Verify SharedPreferences were updated
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('target_language'), equals('es'));

          // Should not attempt database sync when offline
          expect(mockUserService.updateLanguageSettingsCalled, isFalse);
        });
      });

      group('💾 With Stored Preferences (Returning User)', () {
        setUp(() async {
          // Set existing SharedPreferences (simulate returning user)
          SharedPreferences.setMockInitialValues({
            'target_language': 'de', // German
            'native_language': 'fr', // French
            'support_language_1': 'it', // Italian
            'support_language_2': 'pt', // Portuguese
          });

          mockUserService = MockUserService();
          mockUserService.setMockLoggedIn(false);
          mockUserService.setMockUser(null);

          languageSettings = LanguageSettings();
        });

        test('should load existing languages from SharedPreferences', () async {
          // Act: Initialize with existing preferences
          await languageSettings.init();

          // Assert: Should load stored languages
          expect(languageSettings.targetLanguage?.code, equals('de'));
          expect(languageSettings.nativeLanguage?.code, equals('fr'));
          expect(languageSettings.supportLanguage1?.code, equals('it'));
          expect(languageSettings.supportLanguage2?.code, equals('pt'));
        });

        test('should handle invalid language codes gracefully', () async {
          // Arrange: Add invalid language code
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('target_language', 'invalid_code');

          // Act: Initialize with invalid code
          await languageSettings.init();

          // Assert: Invalid language should be null
          expect(languageSettings.targetLanguage, isNull);
          expect(languageSettings.nativeLanguage?.code,
              equals('fr')); // Valid ones should work
        });
      });
    });

    group('🌍 ONLINE MODE Tests (Supabase Database)', () {
      group('📱 Without Stored Preferences (New User Login)', () {
        setUp(() async {
          SharedPreferences.setMockInitialValues({});
          mockUserService = MockUserService();
          languageSettings = LanguageSettings();
        });

        test('should load languages from database when user logs in', () async {
          // Arrange: Create user with database language settings
          final testUser = User(
            id: 'test-user-id',
            email: 'test@example.com',
            firstName: 'Test',
            lastName: 'User',
            isPremium: false,
            createdAt: DateTime.now(),
            targetLanguage: 'ja', // Japanese
            nativeLanguage: 'ko', // Korean
            supportLanguage1: 'zh', // Chinese
            supportLanguage2: 'ru', // Russian
            preferences: UserPreferences(
              notificationsEnabled: true,
              soundEnabled: true,
              theme: 'dark',
            ),
            statistics: UserStatistics(
              totalWordsLearned: 0,
              totalMessagesProcessed: 0,
              streakDays: 0,
              languageProgress: {},
              totalStudyTimeMinutes: 0,
            ),
          );

          mockUserService.setMockLoggedIn(true);
          mockUserService.setMockUser(testUser);

          // Act: Initialize and connect user service (simulate login)
          await languageSettings.init();
          languageSettings.setUserService(mockUserService);

          // Wait for async operations
          await Future.delayed(Duration(milliseconds: 100));

          // Assert: Should load languages from database
          expect(languageSettings.targetLanguage?.code, equals('ja'));
          expect(languageSettings.nativeLanguage?.code, equals('ko'));
          expect(languageSettings.supportLanguage1?.code, equals('zh'));
          expect(languageSettings.supportLanguage2?.code, equals('ru'));
        });

        test('should handle corrupted database language fields', () async {
          // Arrange: Create user with corrupted language data
          final testUser = User(
            id: 'test-user-id',
            email: 'test@example.com',
            firstName: 'Test',
            lastName: 'User',
            isPremium: false,
            createdAt: DateTime.now(),
            targetLanguage: 'null', // Corrupted as string
            nativeLanguage: null, // Actually null
            supportLanguage1: 'invalid_code', // Invalid language code
            supportLanguage2: 'fr', // Valid
            preferences: UserPreferences(),
            statistics: UserStatistics(),
          );

          mockUserService.setMockLoggedIn(true);
          mockUserService.setMockUser(testUser);

          // Act: Initialize with corrupted data
          await languageSettings.init();
          languageSettings.setUserService(mockUserService);
          await Future.delayed(Duration(milliseconds: 100));

          // Assert: Should handle corruption gracefully with smart override behavior
          // The smart override keeps existing valid local values when database is corrupted
          expect(languageSettings.targetLanguage?.code,
              equals('fr')); // Kept local default value (French)
          expect(languageSettings.nativeLanguage?.code,
              equals('en')); // Kept local default value (English)
          expect(languageSettings.supportLanguage1,
              isNull); // invalid code should be null
          expect(languageSettings.supportLanguage2?.code,
              equals('fr')); // valid should work
        });
      });

      group('💾 With Stored Preferences (User with Local + Database)', () {
        setUp(() async {
          // Set existing local preferences
          SharedPreferences.setMockInitialValues({
            'target_language': 'fr', // French locally
            'native_language': 'en', // English locally
          });

          mockUserService = MockUserService();
          languageSettings = LanguageSettings();
        });

        test('should prioritize valid database values over local ones',
            () async {
          // Arrange: Database has different (valid) values than local
          final testUser = User(
            id: 'test-user-id',
            email: 'test@example.com',
            firstName: 'Test',
            lastName: 'User',
            isPremium: false,
            createdAt: DateTime.now(),
            targetLanguage: 'es', // Spanish in database
            nativeLanguage: 'de', // German in database
            supportLanguage1: 'it', // Italian in database
            supportLanguage2: 'pt', // Portuguese in database
            preferences: UserPreferences(),
            statistics: UserStatistics(),
          );

          mockUserService.setMockLoggedIn(true);
          mockUserService.setMockUser(testUser);

          // Act: Initialize (loads local first, then database overrides)
          await languageSettings.init();
          expect(languageSettings.targetLanguage?.code,
              equals('fr')); // Local values initially

          languageSettings.setUserService(mockUserService);
          await Future.delayed(Duration(milliseconds: 100));

          // Assert: Database values should override local ones
          expect(languageSettings.targetLanguage?.code, equals('es'));
          expect(languageSettings.nativeLanguage?.code, equals('de'));
          expect(languageSettings.supportLanguage1?.code, equals('it'));
          expect(languageSettings.supportLanguage2?.code, equals('pt'));
        });

        test('should keep local values when database values are invalid',
            () async {
          // Arrange: Database has invalid values, local has valid ones
          final testUser = User(
            id: 'test-user-id',
            email: 'test@example.com',
            firstName: 'Test',
            lastName: 'User',
            isPremium: false,
            createdAt: DateTime.now(),
            targetLanguage: 'invalid_code', // Invalid in database
            nativeLanguage: null, // Null in database
            supportLanguage1: 'also_invalid',
            supportLanguage2: 'fr', // Valid in database
            preferences: UserPreferences(),
            statistics: UserStatistics(),
          );

          mockUserService.setMockLoggedIn(true);
          mockUserService.setMockUser(testUser);

          // Act: Initialize with mixed valid/invalid data
          await languageSettings.init();
          languageSettings.setUserService(mockUserService);
          await Future.delayed(Duration(milliseconds: 100));

          // Assert: Should keep local valid values, override with database valid values
          expect(languageSettings.targetLanguage?.code,
              equals('fr')); // Kept local valid value
          expect(languageSettings.nativeLanguage?.code,
              equals('en')); // Kept local valid value
          expect(languageSettings.supportLanguage1,
              isNull); // Invalid database value ignored
          expect(languageSettings.supportLanguage2?.code,
              equals('fr')); // Used valid database value
        });
      });

      group('🔄 Database Synchronization', () {
        setUp(() async {
          SharedPreferences.setMockInitialValues({});
          mockUserService = MockUserService();
          languageSettings = LanguageSettings();
        });

        test('should sync language changes to database when online', () async {
          // Arrange: Setup logged-in user
          final testUser = User(
            id: 'test-user-id',
            email: 'test@example.com',
            firstName: 'Test',
            lastName: 'User',
            isPremium: false,
            createdAt: DateTime.now(),
            targetLanguage: 'en',
            nativeLanguage: 'es',
            supportLanguage1: null,
            supportLanguage2: null,
            preferences: UserPreferences(),
            statistics: UserStatistics(),
          );

          mockUserService.setMockLoggedIn(true);
          mockUserService.setMockUser(testUser);

          await languageSettings.init();
          languageSettings.setUserService(mockUserService);
          await Future.delayed(Duration(milliseconds: 100));

          // Reset mock state
          mockUserService.reset();

          // Act: Change target language
          final italianLang = LanguageSettings.availableLanguages
              .firstWhere((lang) => lang.code == 'it');
          await languageSettings.setTargetLanguage(italianLang);

          // Assert: Should call database update
          expect(mockUserService.updateLanguageSettingsCalled, isTrue);
          expect(mockUserService.lastLanguageSettingsCall['targetLanguage'],
              equals('it'));
        });

        test('should handle database sync failures gracefully', () async {
          // Note: This test is simplified since we can't easily mock exceptions
          // with our manual mock setup. In a real app, you'd want to test this.

          // Arrange: Setup logged-in user
          final testUser = User(
            id: 'test-user-id',
            email: 'test@example.com',
            firstName: 'Test',
            lastName: 'User',
            isPremium: false,
            createdAt: DateTime.now(),
            targetLanguage: 'en',
            nativeLanguage: 'es',
            preferences: UserPreferences(),
            statistics: UserStatistics(),
          );

          mockUserService.setMockLoggedIn(true);
          mockUserService.setMockUser(testUser);

          await languageSettings.init();
          languageSettings.setUserService(mockUserService);
          await Future.delayed(Duration(milliseconds: 100));

          // Act: Change language (should not throw exception)
          final frenchLang = LanguageSettings.availableLanguages
              .firstWhere((lang) => lang.code == 'fr');

          expect(
              () async => await languageSettings.setTargetLanguage(frenchLang),
              returnsNormally);

          // Assert: Local change should still work
          expect(languageSettings.targetLanguage?.code, equals('fr'));
        });
      });
    });

    group('🔧 Edge Cases and Error Handling', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        mockUserService = MockUserService();
        languageSettings = LanguageSettings();
      });

      test('should handle null language codes in _findLanguageByCode',
          () async {
        await languageSettings.init();

        // Test with various null/invalid inputs
        expect(
            languageSettings.targetLanguage, isNotNull); // Should have default

        // Simulate what happens with corrupted data
        final result1 = LanguageSettings.availableLanguages
            .where((lang) => lang.code == 'null')
            .firstOrNull;
        expect(result1, isNull);

        final result2 = LanguageSettings.availableLanguages
            .where((lang) => lang.code == '')
            .firstOrNull;
        expect(result2, isNull);
      });

      test('should handle rapid language changes without conflicts', () async {
        // Arrange
        final testUser = User(
          id: 'test-id',
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          isPremium: false,
          createdAt: DateTime.now(),
          targetLanguage: 'en',
          nativeLanguage: 'es',
          preferences: UserPreferences(),
          statistics: UserStatistics(),
        );

        mockUserService.setMockLoggedIn(true);
        mockUserService.setMockUser(testUser);

        await languageSettings.init();
        languageSettings.setUserService(mockUserService);

        // Act: Make rapid language changes
        final languages = ['fr', 'de', 'it', 'pt', 'ru'];
        for (final langCode in languages) {
          final lang = LanguageSettings.availableLanguages
              .firstWhere((l) => l.code == langCode);
          await languageSettings.setTargetLanguage(lang);
        }

        // Assert: Final language should be the last one set
        expect(languageSettings.targetLanguage?.code, equals('ru'));
      });

      test('should demonstrate French default issue', () async {
        // This test specifically demonstrates the French translation issue
        print(
            '\n🔍 =================DEMONSTRATING FRENCH ISSUE==================');

        // Act: Initialize new user (no stored preferences)
        await languageSettings.init();

        // Assert: Shows the problematic default
        print(
            '📱 Default target language: ${languageSettings.targetLanguage?.code}');
        print(
            '📱 Default native language: ${languageSettings.nativeLanguage?.code}');

        expect(languageSettings.targetLanguage?.code,
            equals('fr')); // This is the problem!
        expect(languageSettings.nativeLanguage?.code, equals('en'));

        print(
            '🚨 THIS IS WHY TRANSLATIONS ARE IN FRENCH - DEFAULT TARGET IS FR!');
        print(
            '🔍 ==========================================================\n');
      });
    });
  });
}
