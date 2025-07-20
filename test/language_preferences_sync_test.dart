import 'package:flutter_test/flutter_test.dart';
import 'package:llm_chat_app/services/language_settings_service.dart';
import 'package:llm_chat_app/services/user_service.dart';
import 'package:llm_chat_app/services/auth_service.dart';
import 'package:llm_chat_app/services/database_service.dart';
import 'package:llm_chat_app/models/user.dart';
import 'package:llm_chat_app/models/user_vocabulary.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock services for testing
class MockAuthService implements AuthService {
  User? _mockUser;

  void setMockUser(User? user) => _mockUser = user;

  @override
  User? get currentUser => _mockUser;

  @override
  Stream<User?> get authStateChanges => Stream.value(_mockUser);

  @override
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResult> createUserWithEmailAndPassword(String email, String password, String firstName, String lastName) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    _mockUser = null;
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResult> signInWithApple() async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateUserProfile({String? firstName, String? lastName, String? profileImageUrl}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAccount() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> isPremiumUser() async {
    return false;
  }

  @override
  Future<void> updatePremiumStatus(bool isPremium) async {
    throw UnimplementedError();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cleanup() async {}
}

class MockDatabaseService implements DatabaseService {
  final Map<String, User> _users = {};

  @override
  Future<User?> getUserById(String userId) async {
    return _users[userId];
  }

  @override
  Future<String> createUser(User user) async {
    _users[user.id] = user;
    return user.id;
  }

  @override
  Future<void> updateUser(User user) async {
    _users[user.id] = user;
  }

  @override
  Future<User?> getUserByEmail(String email) async {
    return null;
  }

  @override
  Future<void> deleteUser(String userId) async {}

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId, {String? language}) async {
    return [];
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    return item;
  }

  @override
  Future<void> updateVocabularyItem(UserVocabularyItem item) async {}

  @override
  Future<void> deleteVocabularyItem(String itemId) async {}

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId, {String? language}) async {
    return [];
  }

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(String userId, String language) async {
    return null;
  }

  @override
  Future<void> updateVocabularyStats(UserVocabularyStats stats) async {}

  @override
  Future<void> saveChatMessage(String userId, Map<String, dynamic> message) async {}

  @override
  Future<List<Map<String, dynamic>>> getChatHistory(String userId, {int limit = 50}) async {
    return [];
  }

  @override
  Future<void> deleteChatHistory(String userId) async {}

  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {}

  @override
  Future<bool> isPremiumUser(String userId) async {
    return false;
  }

  @override
  Future<void> cleanup() async {}
}

void main() {
  group('Language Preferences Synchronization Tests', () {
    late LanguageSettings languageSettings;
    late MockAuthService mockAuthService;
    late MockDatabaseService mockDatabaseService;
    late UserService userService;

    setUp(() async {
      // Set up SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      
      mockAuthService = MockAuthService();
      mockDatabaseService = MockDatabaseService();
      
      userService = UserService(
        authService: mockAuthService,
        databaseService: mockDatabaseService,
      );
      
      languageSettings = LanguageSettings();
      await languageSettings.init();
      languageSettings.setUserService(userService);
    });

    test('should load language preferences from user profile on login', () async {
      // Create a user with specific language preferences
      final user = User(
        id: 'test-user-id',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        createdAt: DateTime.now(),
        preferences: UserPreferences(
          targetLanguage: 'es', // Spanish
          nativeLanguage: 'fr',  // French
          supportLanguage1: 'de', // German
          supportLanguage2: 'pt', // Portuguese
        ),
        statistics: UserStatistics(),
      );

      // Create user in mock database
      await mockDatabaseService.createUser(user);
      mockAuthService.setMockUser(user);

      // Load preferences from user profile
      await languageSettings.loadFromUserPreferences(user.preferences);

      // Verify the language settings are updated
      expect(languageSettings.targetLanguage?.code, equals('es'));
      expect(languageSettings.nativeLanguage?.code, equals('fr'));
      expect(languageSettings.supportLanguage1?.code, equals('de'));
      expect(languageSettings.supportLanguage2?.code, equals('pt'));
    });

    test('should sync language preference changes to database when user is logged in', () async {
      // Create a logged in user
      final user = User(
        id: 'test-user-id',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        createdAt: DateTime.now(),
        preferences: UserPreferences(),
        statistics: UserStatistics(),
      );

      await mockDatabaseService.createUser(user);
      mockAuthService.setMockUser(user);
      
      // Find target language (Italian)
      final italianLanguage = LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'it');
      
      // Change target language
      await languageSettings.setTargetLanguage(italianLanguage);

      // Verify the change was synced to the mock database
      final updatedUser = await mockDatabaseService.getUserById(user.id);
      expect(updatedUser?.preferences.targetLanguage, equals('it'));
    });

    test('should handle multiple language preference updates correctly', () async {
      // Create a logged in user
      final user = User(
        id: 'test-user-id',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        createdAt: DateTime.now(),
        preferences: UserPreferences(),
        statistics: UserStatistics(),
      );

      await mockDatabaseService.createUser(user);
      mockAuthService.setMockUser(user);

      // Find languages
      final spanishLanguage = LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'es');
      final germanLanguage = LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'de');
      final frenchLanguage = LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'fr');

      // Change multiple languages
      await languageSettings.setTargetLanguage(spanishLanguage);
      await languageSettings.setNativeLanguage(germanLanguage);
      await languageSettings.setSupportLanguage1(frenchLanguage);

      // Verify all changes were synced to the database
      final updatedUser = await mockDatabaseService.getUserById(user.id);
      expect(updatedUser?.preferences.targetLanguage, equals('es'));
      expect(updatedUser?.preferences.nativeLanguage, equals('de'));
      expect(updatedUser?.preferences.supportLanguage1, equals('fr'));
    });

    test('should not sync to database when user is not logged in', () async {
      // Ensure no user is logged in
      mockAuthService.setMockUser(null);
      
      // Find a language
      final italianLanguage = LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'it');
      
      // Try to change language (should only update local SharedPreferences)
      await languageSettings.setTargetLanguage(italianLanguage);

      // Verify local setting is updated
      expect(languageSettings.targetLanguage?.code, equals('it'));
      
      // Database should be empty since no user was logged in
      expect(mockDatabaseService._users, isEmpty);
    });

    test('should handle null support languages correctly', () async {
      // Create a user with null support languages
      final user = User(
        id: 'test-user-id',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        createdAt: DateTime.now(),
        preferences: UserPreferences(
          targetLanguage: 'it',
          nativeLanguage: 'en',
          supportLanguage1: null,
          supportLanguage2: null,
        ),
        statistics: UserStatistics(),
      );

      await mockDatabaseService.createUser(user);
      mockAuthService.setMockUser(user);

      // Load preferences from user profile
      await languageSettings.loadFromUserPreferences(user.preferences);

      // Verify null support languages are handled correctly
      expect(languageSettings.targetLanguage?.code, equals('it'));
      expect(languageSettings.nativeLanguage?.code, equals('en'));
      expect(languageSettings.supportLanguage1, isNull);
      expect(languageSettings.supportLanguage2, isNull);

      // Now set and then remove a support language
      final spanishLanguage = LanguageSettings.availableLanguages.firstWhere((l) => l.code == 'es');
      await languageSettings.setSupportLanguage1(spanishLanguage);
      await languageSettings.setSupportLanguage1(null);

      // Verify the database reflects the null value
      final updatedUser = await mockDatabaseService.getUserById(user.id);
      expect(updatedUser?.preferences.supportLanguage1, isNull);
    });
  });
}