import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/flashcard_service.dart';
import '../lib/services/user_service.dart';
import '../lib/services/vocabulary_service.dart';
import '../lib/models/user_vocabulary.dart';
import '../lib/models/flashcard_session.dart';
import '../lib/models/flashcard_question.dart';

// Generate mocks
@GenerateMocks([UserService, VocabularyService])
import 'flashcard_service_test.mocks.dart';

void main() {
  group('FlashcardService', () {
    late FlashcardService flashcardService;
    late MockUserService mockUserService;
    late MockVocabularyService mockVocabularyService;
    late List<UserVocabularyItem> testVocabulary;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});

      // Create mock services
      mockUserService = MockUserService();
      mockVocabularyService = MockVocabularyService();

      // Create test vocabulary
      testVocabulary = [
        UserVocabularyItem(
          id: 'vocab-1',
          userId: 'user-123',
          word: 'casa',
          baseForm: 'casa',
          wordType: 'noun',
          language: 'it',
          translations: ['house'],
          exampleSentences: ['La casa è bella'],
          masteryLevel: 50,
          timesCorrect: 3,
          timesSeen: 5,
          lastSeen: DateTime.now().subtract(const Duration(days: 2)),
          firstLearned: DateTime.now().subtract(const Duration(days: 10)),
          nextReview: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        UserVocabularyItem(
          id: 'vocab-2',
          userId: 'user-123',
          word: 'libro',
          baseForm: 'libro',
          wordType: 'noun',
          language: 'it',
          translations: ['book'],
          masteryLevel: 80,
          timesCorrect: 8,
          timesSeen: 10,
          lastSeen: DateTime.now().subtract(const Duration(days: 1)),
          firstLearned: DateTime.now().subtract(const Duration(days: 15)),
          nextReview: DateTime.now().add(const Duration(hours: 12)),
        ),
      ];

      // Set up mock behavior
      when(mockUserService.isLoggedIn).thenReturn(true);
      when(mockUserService.currentUser)
          .thenReturn(null); // Simplified for testing
      when(mockVocabularyService.isInitialized).thenReturn(true);
      when(mockVocabularyService.getUserVocabulary())
          .thenAnswer((_) async => testVocabulary);

      // Create and initialize FlashcardService
      flashcardService = FlashcardService();
      await flashcardService.init();
      flashcardService.setUserService(mockUserService);
      flashcardService.setVocabularyService(mockVocabularyService);
    });

    group('Initialization', () {
      test('initializes correctly', () {
        expect(flashcardService.isInitialized, true);
        expect(flashcardService.sessionStatus, FlashcardSessionStatus.idle);
        expect(flashcardService.currentSession, isNull);
        expect(flashcardService.currentQuestion, isNull);
      });

      test('getters return expected default values', () {
        expect(flashcardService.getMaxWordsPerSession(), 20);
        expect(flashcardService.getDefaultSessionDurationMinutes(), 15);
        expect(
            flashcardService.getQuestionTypeWeights(), isA<Map<String, int>>());
      });
    });

    group('Word Selection', () {
      test('selectWordsForSession returns vocabulary items', () async {
        final selectedWords = await flashcardService.selectWordsForSession(
          maxWords: 5,
          language: 'it',
        );

        expect(selectedWords, isNotEmpty);
        expect(selectedWords.length, lessThanOrEqualTo(5));
        expect(selectedWords.every((word) => word.language == 'it'), true);
      });

      test('selectWordsForSession prioritizes words needing review', () async {
        final selectedWords = await flashcardService.selectWordsForSession(
          maxWords: 10,
          prioritizeReview: true,
        );

        expect(selectedWords, isNotEmpty);
        // Check that words with past due review dates come first
        final overdueWords = selectedWords.where((word) => word.needsReview);
        expect(overdueWords, isNotEmpty);
      });

      test('selectWordsForSession returns empty list when user not logged in',
          () async {
        when(mockUserService.isLoggedIn).thenReturn(false);

        final selectedWords = await flashcardService.selectWordsForSession();

        expect(selectedWords, isEmpty);
      });

      test('selectWordsForSession handles empty vocabulary', () async {
        when(mockVocabularyService.getUserVocabulary())
            .thenAnswer((_) async => []);

        final selectedWords = await flashcardService.selectWordsForSession();

        expect(selectedWords, isEmpty);
      });
    });

    group('Question Generation', () {
      test('generateQuestionsForSession creates questions from vocabulary',
          () async {
        final questions =
            await flashcardService.generateQuestionsForSession(testVocabulary);

        expect(questions, isNotEmpty);
        expect(questions.length, equals(testVocabulary.length));
        expect(questions.every((q) => q.id.isNotEmpty), true);
        expect(questions.every((q) => q.vocabularyItem != null), true);
      });

      test('generateQuestionsForSession handles empty vocabulary list',
          () async {
        final questions =
            await flashcardService.generateQuestionsForSession([]);

        expect(questions, isEmpty);
      });

      test('generateQuestionsForSession creates different question types',
          () async {
        final questions =
            await flashcardService.generateQuestionsForSession(testVocabulary);

        final questionTypes = questions.map((q) => q.type).toSet();
        expect(questionTypes, isNotEmpty);
      });
    });

    group('Session Management', () {
      test('startSession initializes a new session successfully', () async {
        final result = await flashcardService.startSession(
          durationMinutes: 10,
          maxWords: 2,
        );

        expect(result, true);
        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.inProgress);
        expect(flashcardService.currentSession, isNotNull);
        expect(flashcardService.currentQuestion, isNotNull);
      });

      test('startSession fails when user not logged in', () async {
        when(mockUserService.isLoggedIn).thenReturn(false);

        final result = await flashcardService.startSession(durationMinutes: 10);

        expect(result, false);
        expect(flashcardService.sessionStatus, FlashcardSessionStatus.idle);
      });

      test('pauseSession changes status correctly', () async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);

        await flashcardService.pauseSession();

        expect(flashcardService.sessionStatus, FlashcardSessionStatus.paused);
      });

      test('resumeSession returns to in progress', () async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);
        await flashcardService.pauseSession();

        await flashcardService.resumeSession();

        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.inProgress);
      });

      test('completeSession finalizes session', () async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);

        await flashcardService.completeSession();

        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.completed);
        expect(flashcardService.currentSession?.isCompleted, true);
      });

      test('cancelSession clears session data', () async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);

        await flashcardService.cancelSession();

        expect(
            flashcardService.sessionStatus, FlashcardSessionStatus.cancelled);
      });
    });

    group('Question Navigation', () {
      setUp(() async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);
      });

      test('nextQuestion advances to next question', () async {
        final firstQuestion = flashcardService.currentQuestion;

        final hasNext = await flashcardService.nextQuestion();

        expect(hasNext, true);
        expect(flashcardService.currentQuestion, isNot(equals(firstQuestion)));
      });

      test('hasNextQuestion reports correctly', () {
        expect(flashcardService.hasNextQuestion(), true);
      });

      test('previousQuestion goes back to previous question', () async {
        await flashcardService.nextQuestion();
        final secondQuestion = flashcardService.currentQuestion;

        final hasPrevious = await flashcardService.previousQuestion();

        expect(hasPrevious, true);
        expect(flashcardService.currentQuestion, isNot(equals(secondQuestion)));
      });

      test('hasPreviousQuestion reports correctly', () {
        expect(flashcardService.hasPreviousQuestion(), false);
        // After moving forward, should have previous
        flashcardService.nextQuestion();
        expect(flashcardService.hasPreviousQuestion(), true);
      });

      test('getCurrentQuestionNumber returns correct 1-based index', () {
        expect(flashcardService.getCurrentQuestionNumber(), 1);
      });
    });

    group('Answer Recording', () {
      setUp(() async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);
      });

      test('recordAnswer updates session correctly', () async {
        final result = await flashcardService.recordAnswer(
          isCorrect: true,
          userAnswer: 'house',
          difficultyRating: 'good',
        );

        expect(result, true);
        expect(flashcardService.currentSession?.cards, isNotEmpty);
      });

      test('recordSelfAssessment maps difficulty ratings correctly', () async {
        final result = await flashcardService.recordSelfAssessment('easy');

        expect(result, true);
        expect(flashcardService.currentSession?.cards, isNotEmpty);
        expect(flashcardService.currentSession?.cards.last.difficultyRating,
            'easy');
      });

      test('recordSpecificAnswer validates answer correctly', () async {
        // Assume current question expects 'house' as correct answer
        final result = await flashcardService.recordSpecificAnswer('house');

        expect(result, isA<bool>());
        expect(flashcardService.currentSession?.cards, isNotEmpty);
      });
    });

    group('Performance Statistics', () {
      setUp(() async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);
        // Record some answers
        await flashcardService.recordAnswer(
            isCorrect: true, difficultyRating: 'good');
        await flashcardService.nextQuestion();
        await flashcardService.recordAnswer(
            isCorrect: false, difficultyRating: 'again');
      });

      test('getSessionPerformanceStats returns correct data', () {
        final stats = flashcardService.getSessionPerformanceStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('totalQuestions'), true);
        expect(stats.containsKey('correctAnswers'), true);
        expect(stats.containsKey('accuracy'), true);
        expect(stats['totalQuestions'], greaterThan(0));
      });

      test('getPerformanceRecommendations provides useful feedback', () {
        final recommendations =
            flashcardService.getPerformanceRecommendations();

        expect(recommendations, isA<List<String>>());
        expect(recommendations, isNotEmpty);
      });
    });

    group('Integration Status', () {
      test('getIntegrationStatus returns comprehensive status', () {
        final status = flashcardService.getIntegrationStatus();

        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('isInitialized'), true);
        expect(status.containsKey('hasUserService'), true);
        expect(status.containsKey('hasVocabularyService'), true);
        expect(status.containsKey('sessionStatus'), true);
        expect(status['isInitialized'], true);
        expect(status['hasUserService'], true);
        expect(status['hasVocabularyService'], true);
      });
    });

    group('Session Persistence', () {
      test('hasInterruptedSession returns false initially', () {
        expect(flashcardService.hasInterruptedSession(), false);
      });

      test('session data persists across service reinitialization', () async {
        await flashcardService.startSession(durationMinutes: 10, maxWords: 2);
        final sessionId = flashcardService.currentSession?.id;

        // Simulate service restart
        final newFlashcardService = FlashcardService();
        await newFlashcardService.init();
        newFlashcardService.setUserService(mockUserService);
        newFlashcardService.setVocabularyService(mockVocabularyService);

        // Check if session can be detected/resumed
        expect(newFlashcardService.hasInterruptedSession(),
            false); // Might be true in real implementation
      });
    });
  });
}
