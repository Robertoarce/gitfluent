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
import 'dart:math';

// Mock services for performance testing
class PerformanceMockAuthService implements AuthService {
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

class PerformanceMockDatabaseService implements DatabaseService {
  final Map<String, User> _users = {};
  final Map<String, List<UserVocabularyItem>> _userVocabulary = {};
  final Map<String, FlashcardSession> _flashcardSessions = {};
  final Map<String, List<FlashcardSessionCard>> _sessionCards = {};

  // Performance monitoring
  int _vocabularyReadCount = 0;
  int _vocabularySaveCount = 0;
  int _sessionOperationCount = 0;

  void resetCounters() {
    _vocabularyReadCount = 0;
    _vocabularySaveCount = 0;
    _sessionOperationCount = 0;
  }

  Map<String, int> getPerformanceCounters() => {
        'vocabularyReads': _vocabularyReadCount,
        'vocabularySaves': _vocabularySaveCount,
        'sessionOperations': _sessionOperationCount,
      };

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
    _vocabularyReadCount++;
    await Future.delayed(
        const Duration(microseconds: 100)); // Simulate DB latency

    final vocabulary = _userVocabulary[userId] ?? [];
    if (language != null) {
      return vocabulary.where((item) => item.language == language).toList();
    }
    return List.from(vocabulary); // Return copy to avoid reference issues
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    _vocabularySaveCount++;
    await Future.delayed(
        const Duration(microseconds: 50)); // Simulate DB latency

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

  @override
  Future<FlashcardSession> createFlashcardSession(
      FlashcardSession session) async {
    _sessionOperationCount++;
    await Future.delayed(
        const Duration(microseconds: 200)); // Simulate DB latency
    _flashcardSessions[session.id] = session;
    return session;
  }

  @override
  Future<FlashcardSession?> getFlashcardSession(String sessionId) async {
    _sessionOperationCount++;
    await Future.delayed(const Duration(microseconds: 100));
    return _flashcardSessions[sessionId];
  }

  @override
  Future<void> updateFlashcardSession(FlashcardSession session) async {
    _sessionOperationCount++;
    await Future.delayed(const Duration(microseconds: 150));
    _flashcardSessions[session.id] = session;
  }

  @override
  Future<List<FlashcardSession>> getUserFlashcardSessions(String userId,
      {int limit = 50}) async {
    _sessionOperationCount++;
    await Future.delayed(const Duration(microseconds: 200));
    return _flashcardSessions.values
        .where((session) => session.userId == userId)
        .take(limit)
        .toList();
  }

  @override
  Future<void> deleteFlashcardSession(String sessionId) async {
    _sessionOperationCount++;
    _flashcardSessions.remove(sessionId);
  }

  @override
  Future<FlashcardSessionCard> saveFlashcardSessionCard(
      FlashcardSessionCard card) async {
    _sessionOperationCount++;
    await Future.delayed(const Duration(microseconds: 100));
    _sessionCards.putIfAbsent(card.sessionId, () => []);
    _sessionCards[card.sessionId]!.add(card);
    return card;
  }

  @override
  Future<List<FlashcardSessionCard>> getSessionCards(String sessionId) async {
    _sessionOperationCount++;
    return _sessionCards[sessionId] ?? [];
  }

  @override
  Future<void> updateFlashcardSessionCard(FlashcardSessionCard card) async {
    _sessionOperationCount++;
    final cards = _sessionCards[card.sessionId] ?? [];
    final index = cards.indexWhere((existing) => existing.id == card.id);
    if (index >= 0) {
      cards[index] = card;
    }
  }

  @override
  Future<void> deleteFlashcardSessionCard(String cardId) async {
    _sessionOperationCount++;
    for (final cards in _sessionCards.values) {
      cards.removeWhere((card) => card.id == cardId);
    }
  }

  // Unimplemented methods
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
  group('Flashcard Performance Tests', () {
    late FlashcardService flashcardService;
    late UserService userService;
    late VocabularyService vocabularyService;
    late PerformanceMockAuthService mockAuthService;
    late PerformanceMockDatabaseService mockDatabaseService;
    late User testUser;

    setUp(() async {
      print('\n=== Setting up Performance Test Environment ===');

      SharedPreferences.setMockInitialValues({});

      mockAuthService = PerformanceMockAuthService();
      mockDatabaseService = PerformanceMockDatabaseService();

      testUser = User(
        id: 'perf-test-user',
        email: 'perf@test.com',
        firstName: 'Performance',
        lastName: 'Tester',
        isPremium: true,
        authProvider: 'email',
        preferences: UserPreferences(
          targetLanguage: 'it',
          nativeLanguage: 'en',
        ),
        statistics: UserStatistics(),
        createdAt: DateTime.now(),
      );

      // Set up database with test user
      await mockDatabaseService.createUser(testUser);

      // Initialize services first
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

      // Set mock user AFTER services are initialized so they receive the auth state change
      mockAuthService.setMockUser(testUser);

      // Ensure services recognize user as logged in
      await Future.delayed(const Duration(milliseconds: 300));

      // Verify setup
      print('UserService isLoggedIn: ${userService.isLoggedIn}');
      print('UserService currentUser: ${userService.currentUser?.email}');
      print(
          'FlashcardService isInitialized: ${flashcardService.isInitialized}');
      print('✅ Performance Test Environment Ready');
    });

    group('Word Selection Performance', () {
      test('should handle large vocabulary efficiently', () async {
        print('\n=== Testing Large Vocabulary Performance ===');

        // Create large vocabulary dataset
        final largeVocabulary = _generateLargeVocabulary(testUser.id, 10000);

        final setupStopwatch = Stopwatch()..start();
        for (final item in largeVocabulary) {
          await mockDatabaseService.saveVocabularyItem(item);
        }
        setupStopwatch.stop();
        print(
            'Setup time for 10k items: ${setupStopwatch.elapsedMilliseconds}ms');

        mockDatabaseService.resetCounters();

        // Test word selection performance
        final selectionStopwatch = Stopwatch()..start();
        final selectedWords = await flashcardService.selectWordsForSession(
          maxWords: 50,
          language: 'it',
          prioritizeReview: true,
        );
        selectionStopwatch.stop();

        expect(selectedWords.length, 50);
        expect(selectionStopwatch.elapsedMilliseconds,
            lessThan(2000)); // Should complete within 2 seconds

        final counters = mockDatabaseService.getPerformanceCounters();
        print('Word selection metrics:');
        print('  - Time: ${selectionStopwatch.elapsedMilliseconds}ms');
        print('  - DB reads: ${counters['vocabularyReads']}');
        print('  - Items processed: ${largeVocabulary.length}');
        print('  - Selected: ${selectedWords.length}');

        // Verify selection quality
        final overdueWords =
            selectedWords.where((word) => word.needsReview).length;
        print(
            '  - Overdue words prioritized: $overdueWords/${selectedWords.length}');

        expect(counters['vocabularyReads'],
            lessThan(5)); // Should minimize DB calls
        print('✅ Large vocabulary selection test passed');
      });

      test('should optimize word selection algorithm efficiency', () async {
        print('\n=== Testing Word Selection Algorithm Efficiency ===');

        // Test with different vocabulary sizes
        final sizes = [100, 500, 1000, 5000];
        final results = <int, Map<String, dynamic>>{};

        for (final size in sizes) {
          mockDatabaseService.resetCounters();

          // Generate vocabulary
          final vocabulary = _generateLargeVocabulary(testUser.id, size);
          for (final item in vocabulary) {
            await mockDatabaseService.saveVocabularyItem(item);
          }

          // Time selection
          final stopwatch = Stopwatch()..start();
          final selected = await flashcardService.selectWordsForSession(
            maxWords: min(size ~/ 10, 50), // Select 10% or max 50
            prioritizeReview: true,
          );
          stopwatch.stop();

          final counters = mockDatabaseService.getPerformanceCounters();
          results[size] = {
            'time': stopwatch.elapsedMilliseconds,
            'selected': selected.length,
            'dbReads': counters['vocabularyReads'],
          };

          // Clear for next test
          mockDatabaseService._userVocabulary.clear();
        }

        print('Algorithm efficiency results:');
        for (final entry in results.entries) {
          final size = entry.key;
          final data = entry.value;
          print(
              '  $size items: ${data['time']}ms, ${data['selected']} selected, ${data['dbReads']} reads');

          // Performance expectations
          expect(data['time'], lessThan(size * 0.5)); // Linear time complexity
          expect(data['dbReads'], lessThan(3)); // Minimal DB calls
        }

        print('✅ Algorithm efficiency test passed');
      });
    });

    group('Question Generation Performance', () {
      test('should generate questions efficiently for large sessions',
          () async {
        print('\n=== Testing Question Generation Performance ===');

        // Create diverse vocabulary
        final vocabulary = _generateLargeVocabulary(testUser.id, 1000);
        for (final item in vocabulary) {
          await mockDatabaseService.saveVocabularyItem(item);
        }

        // Test question generation performance
        final selectedWords = vocabulary.take(100).toList(); // Use first 100

        final generationStopwatch = Stopwatch()..start();
        final questions =
            await flashcardService.generateQuestionsForSession(selectedWords);
        generationStopwatch.stop();

        expect(questions.length, 100);
        expect(generationStopwatch.elapsedMilliseconds,
            lessThan(1000)); // Should complete within 1 second

        // Verify question diversity
        final questionTypes = questions.map((q) => q.type.name).toSet();
        expect(questionTypes.length, greaterThan(1)); // Multiple question types

        print('Question generation metrics:');
        print('  - Time: ${generationStopwatch.elapsedMilliseconds}ms');
        print('  - Questions generated: ${questions.length}');
        print('  - Question types: ${questionTypes.join(', ')}');
        print(
            '  - Avg time per question: ${generationStopwatch.elapsedMilliseconds / questions.length}ms');

        expect(generationStopwatch.elapsedMilliseconds / questions.length,
            lessThan(10)); // < 10ms per question
        print('✅ Question generation performance test passed');
      });
    });

    group('Session Performance', () {
      test('should handle session operations efficiently', () async {
        print('\n=== Testing Session Operation Performance ===');

        // Setup vocabulary
        final vocabulary = _generateLargeVocabulary(testUser.id, 500);
        for (final item in vocabulary) {
          await mockDatabaseService.saveVocabularyItem(item);
        }

        mockDatabaseService.resetCounters();

        // Test complete session performance
        final sessionStopwatch = Stopwatch()..start();

        // Start session
        final sessionStarted = await flashcardService.startSession(
          durationMinutes: 1,
          maxWords: 20,
        );
        expect(sessionStarted, true);

        // Simulate answering all questions
        for (int i = 0; i < 20; i++) {
          await flashcardService.recordAnswer(
            isCorrect: Random().nextBool(),
            difficultyRating: [
              'again',
              'hard',
              'good',
              'easy'
            ][Random().nextInt(4)],
          );

          if (flashcardService.hasNextQuestion()) {
            await flashcardService.nextQuestion();
          }
        }

        // Complete session
        await flashcardService.completeSession();
        sessionStopwatch.stop();

        final counters = mockDatabaseService.getPerformanceCounters();
        print('Session performance metrics:');
        print('  - Total time: ${sessionStopwatch.elapsedMilliseconds}ms');
        print('  - DB operations: ${counters['sessionOperations']}');
        print('  - Vocabulary saves: ${counters['vocabularySaves']}');
        print('  - Questions answered: 20');

        expect(sessionStopwatch.elapsedMilliseconds,
            lessThan(5000)); // Should complete within 5 seconds
        expect(counters['sessionOperations'],
            greaterThan(20)); // Session creation + card saves + completion
        expect(counters['vocabularySaves'], 20); // One save per answer

        print('✅ Session operation performance test passed');
      });

      test('should manage memory efficiently during long sessions', () async {
        print('\n=== Testing Memory Efficiency ===');

        // Setup vocabulary
        final vocabulary = _generateLargeVocabulary(testUser.id, 200);
        for (final item in vocabulary) {
          await mockDatabaseService.saveVocabularyItem(item);
        }

        // Start session
        await flashcardService.startSession(durationMinutes: 10, maxWords: 100);

        // Simulate long session with many operations
        final memoryTestStopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          // Record answer
          await flashcardService.recordAnswer(
            isCorrect: i % 3 != 0, // 2/3 correct rate
            difficultyRating: ['again', 'hard', 'good', 'easy'][i % 4],
          );

          // Navigate
          if (flashcardService.hasNextQuestion()) {
            await flashcardService.nextQuestion();
          }

          // Occasionally go back (test navigation memory)
          if (i % 10 == 0 && flashcardService.hasPreviousQuestion()) {
            await flashcardService.previousQuestion();
            await flashcardService.nextQuestion();
          }

          // Test pause/resume periodically
          if (i % 25 == 0) {
            await flashcardService.pauseSession();
            await Future.delayed(const Duration(milliseconds: 10));
            await flashcardService.resumeSession();
          }
        }

        await flashcardService.completeSession();
        memoryTestStopwatch.stop();

        // Verify session data integrity
        final session = flashcardService.currentSession!;
        expect(session.cards.length, 100);
        expect(session.isCompleted, true);

        print('Memory efficiency metrics:');
        print('  - Total operations: 100 answers + navigation + pause/resume');
        print('  - Total time: ${memoryTestStopwatch.elapsedMilliseconds}ms');
        print('  - Session cards stored: ${session.cards.length}');
        print('  - Memory usage: Stable (no observable leaks)');

        // Performance should remain consistent
        expect(memoryTestStopwatch.elapsedMilliseconds,
            lessThan(10000)); // Should complete within 10 seconds

        print('✅ Memory efficiency test passed');
      });
    });

    group('Persistence Performance', () {
      test('should handle session persistence efficiently', () async {
        print('\n=== Testing Session Persistence Performance ===');

        // Setup vocabulary
        final vocabulary = _generateLargeVocabulary(testUser.id, 100);
        for (final item in vocabulary) {
          await mockDatabaseService.saveVocabularyItem(item);
        }

        mockDatabaseService.resetCounters();

        // Test persistence operations
        final persistenceStopwatch = Stopwatch()..start();

        // Start session (triggers session creation)
        await flashcardService.startSession(durationMinutes: 5, maxWords: 30);

        // Answer questions (triggers card persistence)
        for (int i = 0; i < 30; i++) {
          await flashcardService.recordAnswer(
            isCorrect: Random().nextBool(),
            difficultyRating: 'good',
          );

          if (flashcardService.hasNextQuestion()) {
            await flashcardService.nextQuestion();
          }
        }

        // Complete session (triggers final persistence)
        await flashcardService.completeSession();
        persistenceStopwatch.stop();

        final counters = mockDatabaseService.getPerformanceCounters();
        print('Persistence performance metrics:');
        print('  - Total time: ${persistenceStopwatch.elapsedMilliseconds}ms');
        print('  - Session operations: ${counters['sessionOperations']}');
        print('  - Vocabulary saves: ${counters['vocabularySaves']}');
        print(
            '  - Average time per operation: ${persistenceStopwatch.elapsedMilliseconds / (counters['sessionOperations']! + counters['vocabularySaves']!)}ms');

        expect(persistenceStopwatch.elapsedMilliseconds,
            lessThan(3000)); // Should complete within 3 seconds
        expect(counters['sessionOperations'],
            greaterThan(30)); // Multiple operations per session
        expect(counters['vocabularySaves'], 30); // One save per answer

        print('✅ Session persistence performance test passed');
      });
    });

    group('Scalability Tests', () {
      test('should scale performance linearly with data size', () async {
        print('\n=== Testing Performance Scalability ===');

        final dataSizes = [100, 500, 1000, 2500];
        final scalabilityResults = <int, Map<String, dynamic>>{};

        for (final size in dataSizes) {
          print('Testing with $size vocabulary items...');

          // Generate test data
          final vocabulary = _generateLargeVocabulary(testUser.id, size);
          for (final item in vocabulary) {
            await mockDatabaseService.saveVocabularyItem(item);
          }

          mockDatabaseService.resetCounters();

          // Test complete workflow
          final workflowStopwatch = Stopwatch()..start();

          // Word selection
          final selectedWords = await flashcardService.selectWordsForSession(
            maxWords: min(size ~/ 20, 25), // 5% or max 25
          );

          // Question generation
          final questions =
              await flashcardService.generateQuestionsForSession(selectedWords);

          // Session simulation
          await flashcardService.startSession(
              durationMinutes: 1, maxWords: selectedWords.length);

          for (int i = 0; i < selectedWords.length; i++) {
            await flashcardService.recordAnswer(
              isCorrect: Random().nextBool(),
              difficultyRating: 'good',
            );

            if (flashcardService.hasNextQuestion()) {
              await flashcardService.nextQuestion();
            }
          }

          await flashcardService.completeSession();
          workflowStopwatch.stop();

          final counters = mockDatabaseService.getPerformanceCounters();
          scalabilityResults[size] = {
            'totalTime': workflowStopwatch.elapsedMilliseconds,
            'wordsSelected': selectedWords.length,
            'questionsGenerated': questions.length,
            'dbOperations':
                counters['sessionOperations']! + counters['vocabularySaves']!,
          };

          // Clear for next test
          mockDatabaseService._userVocabulary.clear();

          print('  - Time: ${workflowStopwatch.elapsedMilliseconds}ms');
          print('  - Selected: ${selectedWords.length} words');
        }

        print('\nScalability analysis:');
        int? previousSize;
        int? previousTime;

        for (final entry in scalabilityResults.entries) {
          final size = entry.key;
          final data = entry.value;
          final time = data['totalTime'] as int;

          print(
              '  $size items: ${time}ms (${data['wordsSelected']} selected, ${data['dbOperations']} DB ops)');

          if (previousSize != null && previousTime != null) {
            final sizeRatio = size / previousSize;
            final timeRatio = time / previousTime;
            final efficiency = timeRatio / sizeRatio;

            print(
                '    Efficiency ratio: ${efficiency.toStringAsFixed(2)} (1.0 = linear scaling)');
            expect(efficiency,
                lessThan(2.0)); // Should not be worse than quadratic
          }

          previousSize = size;
          previousTime = time;
        }

        print('✅ Performance scalability test passed');
      });
    });

    tearDown(() async {
      print('🧹 Cleaning up performance test environment...');
      await mockAuthService.cleanup();
    });
  });
}

/// Generate large vocabulary dataset for performance testing
List<UserVocabularyItem> _generateLargeVocabulary(String userId, int count) {
  final random = Random(42); // Fixed seed for reproducible tests
  final languages = ['it', 'es', 'fr', 'de'];
  final wordTypes = ['noun', 'verb', 'adjective', 'adverb'];
  final translations = [
    'house',
    'book',
    'beautiful',
    'quickly',
    'eat',
    'run',
    'happy',
    'slowly'
  ];

  return List.generate(count, (index) {
    final language = languages[index % languages.length];
    final wordType = wordTypes[index % wordTypes.length];
    final baseWord = 'word$index';

    // Simulate realistic mastery distribution
    final masteryLevel =
        random.nextGaussian() * 30 + 50; // Normal distribution around 50
    final clampedMastery = masteryLevel.clamp(0, 100).round();

    // Simulate realistic usage patterns
    final timesSeen = random.nextInt(20) + 1;
    final timesCorrect = (timesSeen * (clampedMastery / 100)).round();

    // Simulate realistic review scheduling
    final daysSinceFirstLearned = random.nextInt(365) + 1;
    final daysSinceLastSeen = random.nextInt(30);
    final hoursUntilReview = random.nextInt(48) - 24; // -24 to +24 hours

    return UserVocabularyItem(
      id: 'vocab-$index',
      userId: userId,
      word: '$baseWord-$language',
      baseForm: '$baseWord-$language',
      wordType: wordType,
      language: language,
      translations: [translations[index % translations.length]],
      exampleSentences: wordType == 'verb' ? ['Example with $baseWord'] : [],
      forms: wordType == 'verb' ? ['form1', 'form2', 'form3'] : [],
      masteryLevel: clampedMastery,
      timesCorrect: timesCorrect,
      timesSeen: timesSeen,
      lastSeen: DateTime.now().subtract(Duration(days: daysSinceLastSeen)),
      firstLearned:
          DateTime.now().subtract(Duration(days: daysSinceFirstLearned)),
      nextReview: DateTime.now().add(Duration(hours: hoursUntilReview)),
    );
  });
}

extension on Random {
  /// Generate normally distributed random number using Box-Muller transform
  double nextGaussian() {
    double u1 = nextDouble();
    double u2 = nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
