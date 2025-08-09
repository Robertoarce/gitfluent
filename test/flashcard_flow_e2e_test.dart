import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llm_chat_app/services/flashcard_service.dart';
import 'package:llm_chat_app/services/user_service.dart';
import 'package:llm_chat_app/services/vocabulary_service.dart';
import 'package:llm_chat_app/services/auth_service.dart';
import 'package:llm_chat_app/services/database_service.dart';
import 'package:llm_chat_app/models/user.dart';
import 'package:llm_chat_app/models/user_vocabulary.dart';
import 'package:llm_chat_app/models/flashcard_session.dart';
import 'dart:async';

// Simple mock services for testing
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
          String email, String password) async =>
      throw UnimplementedError();
  @override
  Future<AuthResult> createUserWithEmailAndPassword(String email,
          String password, String firstName, String lastName) async =>
      throw UnimplementedError();
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
  final Map<String, List<UserVocabularyItem>> _userVocabulary = {};
  final Map<String, FlashcardSession> _flashcardSessions = {};
  final Map<String, List<FlashcardSessionCard>> _sessionCards = {};

  @override
  Future<User?> getUserById(String userId) async => _users[userId];

  @override
  Future<String> createUser(User user) async {
    _users[user.id] = user;
    return user.id;
  }

  @override
  Future<void> updateUser(User user) async => _users[user.id] = user;

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId,
      {String? language}) async {
    final vocabulary = _userVocabulary[userId] ?? [];
    if (language != null) {
      return vocabulary.where((item) => item.language == language).toList();
    }
    return vocabulary;
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    _userVocabulary.putIfAbsent(item.userId, () => []);
    final list = _userVocabulary[item.userId]!;
    final index = list.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
    return item;
  }

  // Flashcard-specific methods
  @override
  Future<FlashcardSession> createFlashcardSession(
      FlashcardSession session) async {
    _flashcardSessions[session.id] = session;
    return session;
  }

  @override
  Future<FlashcardSession?> getFlashcardSession(String sessionId) async =>
      _flashcardSessions[sessionId];

  @override
  Future<void> updateFlashcardSession(FlashcardSession session) async =>
      _flashcardSessions[session.id] = session;

  @override
  Future<List<FlashcardSession>> getUserFlashcardSessions(String userId,
      {int limit = 50}) async {
    return _flashcardSessions.values
        .where((session) => session.userId == userId)
        .take(limit)
        .toList();
  }

  @override
  Future<void> deleteFlashcardSession(String sessionId) async =>
      _flashcardSessions.remove(sessionId);

  @override
  Future<FlashcardSessionCard> saveFlashcardSessionCard(
      FlashcardSessionCard card) async {
    _sessionCards.putIfAbsent(card.sessionId, () => []);
    _sessionCards[card.sessionId]!.add(card);
    return card;
  }

  @override
  Future<List<FlashcardSessionCard>> getSessionCards(String sessionId) async =>
      _sessionCards[sessionId] ?? [];

  @override
  Future<void> updateFlashcardSessionCard(FlashcardSessionCard card) async {
    final cards = _sessionCards[card.sessionId] ?? [];
    final index = cards.indexWhere((existing) => existing.id == card.id);
    if (index >= 0) {
      cards[index] = card;
    }
  }

  @override
  Future<void> deleteFlashcardSessionCard(String cardId) async {
    for (final cards in _sessionCards.values) {
      cards.removeWhere((card) => card.id == cardId);
    }
  }

  // Unimplemented methods for this test
  @override
  Future<void> deleteUser(String userId) async => throw UnimplementedError();
  @override
  Future<void> saveChatMessage(String userId, dynamic message) async =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getChatHistory(String userId,
          {int limit = 50}) async =>
      throw UnimplementedError();
  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(
          String userId, String language) async =>
      throw UnimplementedError();
  @override
  Future<void> updateVocabularyStats(dynamic stats) async =>
      throw UnimplementedError();
  @override
  Future<bool> isPremiumUser(String userId) async => false;
  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async =>
      throw UnimplementedError();
  @override
  Future<void> cleanup() async {}
  @override
  Future<void> deleteChatHistory(String userId) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteVocabularyItem(String itemId) async =>
      throw UnimplementedError();
  @override
  Future<User?> getUserByEmail(String email) async =>
      throw UnimplementedError();
  @override
  Future<List<UserVocabularyItem>> searchUserVocabulary(
          String userId, String query,
          {String? language}) async =>
      throw UnimplementedError();
  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId,
          {String? language}) async =>
      throw UnimplementedError();
  @override
  Future<UserVocabularyItem> updateVocabularyItem(
          UserVocabularyItem item) async =>
      throw UnimplementedError();
}

void main() {
  group('Flashcard Flow End-to-End Tests', () {
    late FlashcardService flashcardService;
    late UserService userService;
    late VocabularyService vocabularyService;
    late MockAuthService mockAuthService;
    late MockDatabaseService mockDatabaseService;
    late User testUser;
    late List<UserVocabularyItem> testVocabulary;

    setUp(() async {
      print('\n=== Setting up Flashcard E2E Test Environment ===');

      // Clear SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Create mock services
      mockAuthService = MockAuthService();
      mockDatabaseService = MockDatabaseService();

      // Create test user
      testUser = User(
        id: 'test-user-123',
        email: 'flashcard@test.com',
        firstName: 'Test',
        lastName: 'User',
        isPremium: true,
        authProvider: 'email',
        preferences: UserPreferences(
          targetLanguage: 'it',
          nativeLanguage: 'en',
        ),
        statistics: UserStatistics(),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      // Set up test vocabulary with different mastery levels
      testVocabulary = [
        UserVocabularyItem(
          id: 'vocab-1',
          userId: testUser.id,
          word: 'casa',
          baseForm: 'casa',
          wordType: 'noun',
          language: 'it',
          translations: ['house'],
          exampleSentences: ['La casa è bella'],
          masteryLevel: 20, // Low mastery - needs review
          timesCorrect: 1,
          timesSeen: 5,
          lastSeen: DateTime.now().subtract(const Duration(days: 2)),
          firstLearned: DateTime.now().subtract(const Duration(days: 10)),
          nextReview:
              DateTime.now().subtract(const Duration(hours: 1)), // Overdue
        ),
        UserVocabularyItem(
          id: 'vocab-2',
          userId: testUser.id,
          word: 'libro',
          baseForm: 'libro',
          wordType: 'noun',
          language: 'it',
          translations: ['book'],
          masteryLevel: 80, // High mastery
          timesCorrect: 8,
          timesSeen: 10,
          lastSeen: DateTime.now().subtract(const Duration(days: 1)),
          firstLearned: DateTime.now().subtract(const Duration(days: 20)),
          nextReview: DateTime.now().add(const Duration(days: 2)), // Future
        ),
        UserVocabularyItem(
          id: 'vocab-3',
          userId: testUser.id,
          word: 'bello',
          baseForm: 'bello',
          wordType: 'adjective',
          language: 'it',
          translations: ['beautiful'],
          masteryLevel: 40, // Medium mastery
          timesCorrect: 3,
          timesSeen: 7,
          lastSeen: DateTime.now().subtract(const Duration(hours: 8)),
          firstLearned: DateTime.now().subtract(const Duration(days: 5)),
          nextReview: DateTime.now()
              .subtract(const Duration(minutes: 30)), // Recently due
        ),
      ];

      // Set up database with test data
      await mockDatabaseService.createUser(testUser);
      for (final vocabItem in testVocabulary) {
        await mockDatabaseService.saveVocabularyItem(vocabItem);
      }

      // Set up auth service
      mockAuthService.setMockUser(testUser);

      // Create real services with mock dependencies
      userService = UserService(
        authService: mockAuthService,
        databaseService: mockDatabaseService,
      );

      vocabularyService = VocabularyService();
      await vocabularyService.init();
      vocabularyService.setUserService(userService);

      flashcardService = FlashcardService();
      await flashcardService.init();
      flashcardService.setUserService(userService);
      flashcardService.setVocabularyService(vocabularyService);

      // Wait for services to sync user state
      await Future.delayed(const Duration(milliseconds: 200));

      print('✅ E2E Test Environment Ready');
    });

    group('Complete Flashcard Flow', () {
      test('should complete a full flashcard session from start to finish',
          () async {
        print('\n=== Testing Complete Flashcard Session Flow ===');

        // Verify initial state
        expect(flashcardService.isInitialized, true);
        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.notStarted);
        expect(flashcardService.currentSession, isNull);

        // Start a flashcard session
        print('📚 Starting flashcard session...');
        final sessionStarted = await flashcardService.startSession(
          durationMinutes: 10,
          maxWords: 3,
          language: 'it',
          prioritizeReview: true,
        );

        expect(sessionStarted, true);
        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.inProgress);
        expect(flashcardService.currentSession, isNotNull);
        expect(flashcardService.currentQuestion, isNotNull);

        print('✅ Session started successfully');

        // Navigate through questions and record answers
        print('📝 Answering questions...');

        // Question 1
        expect(flashcardService.getCurrentQuestionNumber(), 1);
        final firstQuestion = flashcardService.currentQuestion!;
        print('Q1: ${firstQuestion.question} (${firstQuestion.type.name})');

        await flashcardService.recordAnswer(
          isCorrect: true,
          difficultyRating: 'good',
        );
        expect(flashcardService.currentSession!.cards.length, 1);
        print('✅ Q1 answered correctly');

        // Question 2
        await flashcardService.nextQuestion();
        expect(flashcardService.getCurrentQuestionNumber(), 2);

        await flashcardService.recordAnswer(
          isCorrect: false,
          difficultyRating: 'again',
        );
        expect(flashcardService.currentSession!.cards.length, 2);
        print('❌ Q2 answered incorrectly');

        // Question 3
        await flashcardService.nextQuestion();
        expect(flashcardService.getCurrentQuestionNumber(), 3);

        await flashcardService.recordSelfAssessment('easy');
        expect(flashcardService.currentSession!.cards.length, 3);
        print('✅ Q3 self-assessed as easy');

        // Complete the session
        print('🏁 Completing session...');
        await flashcardService.completeSession();

        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.completed);
        expect(flashcardService.currentSession!.isCompleted, true);

        // Verify session statistics
        final stats = flashcardService.getSessionPerformanceStats();
        expect(stats['totalQuestions'], 3);
        expect(stats['correctAnswers'], 2); // Q1 and Q3 were correct
        print(
            '📊 Session completed: ${stats['correctAnswers']}/${stats['totalQuestions']} correct');

        // Verify data persistence
        final persistedSession = await mockDatabaseService
            .getFlashcardSession(flashcardService.currentSession!.id);
        expect(persistedSession, isNotNull);
        expect(persistedSession!.isCompleted, true);

        final sessionCards =
            await mockDatabaseService.getSessionCards(persistedSession.id);
        expect(sessionCards.length, 3);
        print('✅ Session data persisted successfully');

        print('🎉 Complete flashcard flow test passed!');
      });

      test('should handle session pause and resume correctly', () async {
        print('\n=== Testing Session Pause/Resume ===');

        // Start session
        await flashcardService.startSession(durationMinutes: 15, maxWords: 2);
        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.inProgress);

        // Answer first question
        await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');
        await flashcardService.nextQuestion();

        // Pause session
        print('⏸️ Pausing session...');
        await flashcardService.pauseSession();
        expect(flashcardService.sessionStatus, FlashcardSessionStatus.paused);

        // Try to answer while paused (should fail)
        final pausedAnswer = await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');
        expect(pausedAnswer, false);

        // Resume session
        print('▶️ Resuming session...');
        await flashcardService.resumeSession();
        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.inProgress);

        // Answer should work now
        final resumedAnswer = await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');
        expect(resumedAnswer, true);

        await flashcardService.completeSession();
        print('✅ Pause/Resume test passed');
      });

      test('should handle session cancellation properly', () async {
        print('\n=== Testing Session Cancellation ===');

        // Start session and answer one question
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);
        await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');

        // Cancel session
        print('🚫 Cancelling session...');
        await flashcardService.cancelSession();
        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.cancelled);

        // Verify cannot answer after cancellation
        final cancelledAnswer = await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');
        expect(cancelledAnswer, false);

        print('✅ Session cancellation test passed');
      });
    });

    group('Integration and Data Flow', () {
      test('should update vocabulary mastery levels based on performance',
          () async {
        print('\n=== Testing Vocabulary Mastery Updates ===');

        // Get initial mastery levels
        final initialVocabulary =
            await mockDatabaseService.getUserVocabulary(testUser.id);
        final initialMastery = {
          for (var item in initialVocabulary) item.id: item.masteryLevel
        };

        // Complete a session with mixed performance
        await flashcardService.startSession(durationMinutes: 10, maxWords: 3);

        // Correct answer should increase mastery
        await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'easy');
        await flashcardService.nextQuestion();

        // Incorrect answer should decrease mastery
        await flashcardService.recordAnswer(
            isCorrect: false, difficultyRating: 'again');
        await flashcardService.nextQuestion();

        // Good answer should moderately increase mastery
        await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');

        await flashcardService.completeSession();

        // Verify mastery levels changed appropriately
        final updatedVocabulary =
            await mockDatabaseService.getUserVocabulary(testUser.id);
        bool masteryChanged = false;
        for (var item in updatedVocabulary) {
          if (initialMastery[item.id] != item.masteryLevel) {
            masteryChanged = true;
            print(
                '  ${item.word}: ${initialMastery[item.id]} → ${item.masteryLevel}');
          }
        }

        expect(masteryChanged, true);
        print('✅ Vocabulary mastery updates verified');
      });

      test('should provide accurate integration status throughout session',
          () async {
        print('\n=== Testing Integration Status Monitoring ===');

        // Initial status
        var status = flashcardService.getIntegrationStatus();
        expect(status['isInitialized'], true);
        expect(status['hasUserService'], true);
        expect(status['hasVocabularyService'], true);
        expect(status['userLoggedIn'], true);
        expect(status['sessionStatus'], 'notStarted');
        print('  Initial status: ${status['sessionStatus']}');

        // During session
        await flashcardService.startSession(durationMinutes: 5, maxWords: 1);
        status = flashcardService.getIntegrationStatus();
        expect(status['currentSessionActive'], true);
        expect(status['sessionStatus'], 'inProgress');
        expect(status['questionsLoaded'], greaterThan(0));
        print('  Active status: ${status['sessionStatus']}');

        // After completion
        await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');
        await flashcardService.completeSession();
        status = flashcardService.getIntegrationStatus();
        expect(status['sessionStatus'], 'completed');
        print('  Final status: ${status['sessionStatus']}');

        print('✅ Integration status monitoring verified');
      });

      test('should handle error scenarios gracefully', () async {
        print('\n=== Testing Error Handling ===');

        // Test starting session with no vocabulary
        final originalVocab = testVocabulary.toList();
        mockDatabaseService._userVocabulary.clear();

        final noVocabResult =
            await flashcardService.startSession(durationMinutes: 10);
        expect(noVocabResult, false);
        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.notStarted);
        print('  No vocabulary scenario handled correctly');

        // Restore vocabulary for other tests
        for (final item in originalVocab) {
          await mockDatabaseService.saveVocabularyItem(item);
        }

        print('✅ Error handling test passed');
      });
    });

    tearDown(() async {
      print('🧹 Cleaning up test environment...');
      await mockAuthService.cleanup();
    });
  });
}
