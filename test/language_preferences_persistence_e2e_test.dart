import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llm_chat_app/services/language_settings_service.dart';
import 'package:llm_chat_app/services/user_service.dart';
import 'package:llm_chat_app/services/auth_service.dart';
import 'package:llm_chat_app/services/database_service.dart';
import 'package:llm_chat_app/models/user.dart';
import 'package:llm_chat_app/models/user_vocabulary.dart';
import 'package:llm_chat_app/models/flashcard_session.dart';

// Mock services for testing
class MockAuthService implements AuthService {
  User? _mockUser;
  bool _isLoggedIn = false;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  void setMockUser(User? user) {
    _mockUser = user;
    _isLoggedIn = user != null;
    _authStateController.add(user);
  }

  @override
  User? get currentUser => _mockUser;

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  bool get isLoggedIn => _isLoggedIn;

  @override
  Future<AuthResult> signInWithEmailAndPassword(
      String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResult> createUserWithEmailAndPassword(
      String email, String password, String firstName, String lastName) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    _mockUser = null;
    _isLoggedIn = false;
  }

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
  Future<void> cleanup() async {
    await _authStateController.close();
  }
}

class MockDatabaseService implements DatabaseService {
  final Map<String, User> _users = {};

  @override
  Future<User?> getUserById(String userId) async {
    await Future.delayed(
        const Duration(milliseconds: 10)); // Simulate network delay
    return _users[userId];
  }

  @override
  Future<String> createUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _users[user.id] = user;
    return user.id;
  }

  @override
  Future<void> updateUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _users[user.id] = user;
  }

  // Get the updated user preferences for testing
  User? getStoredUser(String userId) => _users[userId];

  @override
  Future<User?> getUserByEmail(String email) async => null;
  @override
  Future<void> deleteUser(String userId) async {}
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
  Future<void> saveChatMessage(
      String userId, Map<String, dynamic> message) async {}
  @override
  Future<List<Map<String, dynamic>>> getChatHistory(String userId,
          {int limit = 50}) async =>
      [];
  @override
  Future<void> deleteChatHistory(String userId) async {}
  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {}
  @override
  Future<bool> isPremiumUser(String userId) async => false;
  @override
  Future<void> cleanup() async {}

  // Flashcard methods
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
}

void main() {
  group('Language Preferences Persistence E2E Tests', () {
    late MockAuthService mockAuthService;
    late MockDatabaseService mockDatabaseService;
    late UserService userService;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});

      mockAuthService = MockAuthService();
      mockDatabaseService = MockDatabaseService();
      userService = UserService(
        authService: mockAuthService,
        databaseService: mockDatabaseService,
      );
    });

    test('language preferences persist across app restart for logged-in user',
        () async {
      // Step 1: Create a logged-in user with default preferences
      final user = User(
        id: 'test-user-id',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        createdAt: DateTime.now(),
        preferences: UserPreferences(
          targetLanguage: 'it', // Italian
          nativeLanguage: 'en', // English
          supportLanguage1: 'es', // Spanish
          supportLanguage2: 'fr', // French
        ),
        statistics: UserStatistics(),
      );

      // Step 2: Set up user login and create first language settings instance
      await mockDatabaseService.createUser(user);
      mockAuthService.setMockUser(user);

      // Give time for UserService to receive the auth state change
      await Future.delayed(const Duration(milliseconds: 50));

      final languageSettings1 = LanguageSettings();
      await languageSettings1.init();
      languageSettings1.setUserService(userService);

      // Load user preferences (simulating app startup)
      await languageSettings1.loadFromUserPreferences(user.preferences);

      // Verify initial state
      expect(languageSettings1.targetLanguage?.code, equals('it')); // Italian
      expect(languageSettings1.nativeLanguage?.code, equals('en')); // English

      // Step 3: Change language preferences
      final spanishLang =
          LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'es');
      final germanLang =
          LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'de');

      await languageSettings1
          .setTargetLanguage(spanishLang); // Italian -> Spanish
      await languageSettings1
          .setNativeLanguage(germanLang); // English -> German

      // Step 4: Verify changes are synced to database
      final updatedUser = mockDatabaseService.getStoredUser(user.id);

      // Verify changes are properly stored

      expect(updatedUser?.preferences.targetLanguage, equals('es')); // Spanish
      expect(updatedUser?.preferences.nativeLanguage, equals('de')); // German

      // Support languages should remain unchanged since we only changed target and native
      expect(updatedUser?.preferences.supportLanguage1,
          equals('es')); // Spanish (unchanged)
      expect(updatedUser?.preferences.supportLanguage2,
          equals('fr')); // French (unchanged)

      // Step 5: Simulate app restart - create new language settings instance
      // (Simulating fresh app start with same user logged in)
      final languageSettings2 = LanguageSettings();
      await languageSettings2.init();
      languageSettings2.setUserService(userService);

      // Load user preferences from database (simulating app initialization after restart)
      final userFromDb = await mockDatabaseService.getUserById(user.id);
      await languageSettings2.loadFromUserPreferences(userFromDb!.preferences);

      // Step 6: Verify preferences were restored from database
      expect(languageSettings2.targetLanguage?.code, equals('es')); // Spanish
      expect(languageSettings2.nativeLanguage?.code, equals('de')); // German
      expect(languageSettings2.supportLanguage1?.code, equals('es')); // Spanish
      expect(languageSettings2.supportLanguage2?.code, equals('fr')); // French
    });

    test('language preferences persist locally for non-logged-in user',
        () async {
      // Step 1: Create language settings without logged-in user
      mockAuthService.setMockUser(null);

      final languageSettings1 = LanguageSettings();
      await languageSettings1.init();
      languageSettings1.setUserService(userService);

      // Step 2: Change language settings (should only save to SharedPreferences)
      final portugueseLang =
          LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'pt');
      final frenchLang =
          LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'fr');

      await languageSettings1.setTargetLanguage(portugueseLang); // Portuguese
      await languageSettings1.setNativeLanguage(frenchLang); // French

      // Step 3: Verify no user data in database (since not logged in)
      expect(mockDatabaseService._users, isEmpty);

      // Verify changes were made locally
      expect(
          languageSettings1.targetLanguage?.code, equals('pt')); // Portuguese
      expect(languageSettings1.nativeLanguage?.code, equals('fr')); // French

      // Step 4: Simulate app restart - create new language settings instance
      final languageSettings2 = LanguageSettings();
      await languageSettings2.init();
      languageSettings2.setUserService(userService);

      // Step 5: Verify preferences were restored from SharedPreferences
      expect(
          languageSettings2.targetLanguage?.code, equals('pt')); // Portuguese
      expect(languageSettings2.nativeLanguage?.code, equals('fr')); // French
    });

    test('language preferences sync from database to local on login', () async {
      // Step 1: Create user with specific preferences in database
      final user = User(
        id: 'test-user-id',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        createdAt: DateTime.now(),
        preferences: UserPreferences(
          targetLanguage: 'zh', // Chinese
          nativeLanguage: 'ja', // Japanese
          supportLanguage1: 'ko', // Korean
          supportLanguage2: 'vi', // Vietnamese
        ),
        statistics: UserStatistics(),
      );

      // Step 2: Start without login, set different local preferences
      mockAuthService.setMockUser(null);

      final languageSettings = LanguageSettings();
      await languageSettings.init();
      languageSettings.setUserService(userService);

      // Set different local preferences
      final italianLang =
          LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'it');
      final englishLang =
          LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'en');
      await languageSettings.setTargetLanguage(italianLang);
      await languageSettings.setNativeLanguage(englishLang);

      // Verify local settings are different from database user
      expect(languageSettings.targetLanguage?.code, equals('it')); // Italian
      expect(languageSettings.nativeLanguage?.code, equals('en')); // English

      // Step 3: Simulate user login
      await mockDatabaseService.createUser(user);
      mockAuthService.setMockUser(user);

      // Load user preferences (simulating what happens in app initialization)
      await languageSettings.loadFromUserPreferences(user.preferences);

      // Step 4: Verify database preferences override local preferences
      expect(languageSettings.targetLanguage?.code, equals('zh')); // Chinese
      expect(languageSettings.nativeLanguage?.code, equals('ja')); // Japanese
      expect(languageSettings.supportLanguage1?.code, equals('ko')); // Korean
      expect(
          languageSettings.supportLanguage2?.code, equals('vi')); // Vietnamese
    });
  });
}
