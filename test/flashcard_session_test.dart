import 'package:flutter_test/flutter_test.dart';
import 'package:llm_chat_app/models/flashcard_session.dart';

void main() {
  group('FlashcardSession', () {
    late FlashcardSession testSession;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 1, 15, 10, 30);
      testSession = FlashcardSession(
        id: 'session-123',
        userId: 'user-456',
        sessionDate: testDate,
        durationMinutes: 15,
        wordsStudied: 10,
        totalCards: 12,
        accuracyPercentage: 83.33,
        sessionType: 'timed',
        isCompleted: true,
        createdAt: testDate,
        updatedAt: testDate.add(const Duration(minutes: 15)),
      );
    });

    test('constructor sets all properties correctly', () {
      expect(testSession.id, 'session-123');
      expect(testSession.userId, 'user-456');
      expect(testSession.sessionDate, testDate);
      expect(testSession.durationMinutes, 15);
      expect(testSession.wordsStudied, 10);
      expect(testSession.totalCards, 12);
      expect(testSession.accuracyPercentage, 83.33);
      expect(testSession.sessionType, 'timed');
      expect(testSession.isCompleted, true);
      expect(testSession.createdAt, testDate);
      expect(testSession.updatedAt, testDate.add(const Duration(minutes: 15)));
      expect(testSession.cards, isEmpty);
    });

    test('constructor uses default values correctly', () {
      final minimalSession = FlashcardSession(
        id: 'minimal',
        userId: 'user',
        sessionDate: testDate,
        durationMinutes: 5,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(minimalSession.wordsStudied, 0);
      expect(minimalSession.totalCards, 0);
      expect(minimalSession.accuracyPercentage, 0.0);
      expect(minimalSession.sessionType, 'timed');
      expect(minimalSession.isCompleted, false);
      expect(minimalSession.cards, isEmpty);
    });

    test('create factory constructor generates correct session', () {
      final createdSession = FlashcardSession.create(
        userId: 'test-user',
        durationMinutes: 20,
        sessionType: 'count-based',
      );

      expect(createdSession.id, isNotEmpty);
      expect(createdSession.userId, 'test-user');
      expect(createdSession.durationMinutes, 20);
      expect(createdSession.sessionType, 'count-based');
      expect(createdSession.wordsStudied, 0);
      expect(createdSession.totalCards, 0);
      expect(createdSession.accuracyPercentage, 0.0);
      expect(createdSession.isCompleted, false);
      expect(createdSession.cards, isEmpty);

      // Check that dates are recent (within last minute)
      final now = DateTime.now();
      expect(createdSession.sessionDate.difference(now).inMinutes.abs(),
          lessThan(1));
      expect(createdSession.createdAt.difference(now).inMinutes.abs(),
          lessThan(1));
      expect(createdSession.updatedAt.difference(now).inMinutes.abs(),
          lessThan(1));
    });

    test('copyWith updates specified properties only', () {
      final updatedSession = testSession.copyWith(
        wordsStudied: 15,
        accuracyPercentage: 90.0,
        isCompleted: false,
      );

      expect(updatedSession.id, testSession.id);
      expect(updatedSession.userId, testSession.userId);
      expect(updatedSession.wordsStudied, 15); // Updated
      expect(updatedSession.totalCards, testSession.totalCards); // Unchanged
      expect(updatedSession.accuracyPercentage, 90.0); // Updated
      expect(updatedSession.isCompleted, false); // Updated
      expect(updatedSession.sessionType, testSession.sessionType); // Unchanged
    });

    test('toJson serializes correctly', () {
      final json = testSession.toJson();

      expect(json['id'], 'session-123');
      expect(json['user_id'], 'user-456');
      expect(json['duration_minutes'], 15);
      expect(json['words_studied'], 10);
      expect(json['total_cards'], 12);
      expect(json['accuracy_percentage'], 83.33);
      expect(json['session_type'], 'timed');
      expect(json['is_completed'], true);
      expect(json['session_date'], testDate.toIso8601String());
      expect(json['created_at'], testDate.toIso8601String());
      expect(json['updated_at'],
          testDate.add(const Duration(minutes: 15)).toIso8601String());
      expect(json, isNot(contains('cards'))); // Should be excluded from JSON
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'session-789',
        'user_id': 'user-abc',
        'session_date': '2024-01-16T14:30:00.000Z',
        'duration_minutes': 25,
        'words_studied': 20,
        'total_cards': 22,
        'accuracy_percentage': 95.45,
        'session_type': 'count-based',
        'is_completed': true,
        'created_at': '2024-01-16T14:00:00.000Z',
        'updated_at': '2024-01-16T14:25:00.000Z',
      };

      final session = FlashcardSession.fromJson(json);

      expect(session.id, 'session-789');
      expect(session.userId, 'user-abc');
      expect(session.durationMinutes, 25);
      expect(session.wordsStudied, 20);
      expect(session.totalCards, 22);
      expect(session.accuracyPercentage, 95.45);
      expect(session.sessionType, 'count-based');
      expect(session.isCompleted, true);
      expect(session.cards, isEmpty);
    });

    test('toSupabase formats for database correctly', () {
      final supabaseData = testSession.toSupabase();

      expect(supabaseData['id'], 'session-123');
      expect(supabaseData['user_id'], 'user-456');
      expect(supabaseData['session_date'], testDate.toIso8601String());
      expect(supabaseData['duration_minutes'], 15);
      expect(supabaseData['words_studied'], 10);
      expect(supabaseData['total_cards'], 12);
      expect(supabaseData['accuracy_percentage'], 83.33);
      expect(supabaseData['session_type'], 'timed');
      expect(supabaseData['is_completed'], true);
      expect(supabaseData['created_at'], testDate.toIso8601String());
      expect(supabaseData['updated_at'],
          testDate.add(const Duration(minutes: 15)).toIso8601String());
    });

    test('fromSupabase creates session from database data', () {
      final supabaseData = {
        'id': 'db-session-123',
        'user_id': 'db-user-456',
        'session_date': '2024-01-17T09:15:00.000Z',
        'duration_minutes': 30,
        'words_studied': 25,
        'total_cards': 28,
        'accuracy_percentage': 89.29,
        'session_type': 'mixed',
        'is_completed': false,
        'created_at': '2024-01-17T09:00:00.000Z',
        'updated_at': '2024-01-17T09:30:00.000Z',
      };

      final session = FlashcardSession.fromSupabase(supabaseData);

      expect(session.id, 'db-session-123');
      expect(session.userId, 'db-user-456');
      expect(session.durationMinutes, 30);
      expect(session.wordsStudied, 25);
      expect(session.totalCards, 28);
      expect(session.accuracyPercentage, 89.29);
      expect(session.sessionType, 'mixed');
      expect(session.isCompleted, false);
    });

    test('getters compute derived values correctly', () {
      final card1 = FlashcardSessionCard.create(
        sessionId: 'test-session',
        vocabularyItemId: 'vocab-1',
        questionType: 'traditional',
        responseTimeMs: 3000,
        wasCorrect: true,
        difficultyRating: 'good',
      );

      final card2 = FlashcardSessionCard.create(
        sessionId: 'test-session',
        vocabularyItemId: 'vocab-2',
        questionType: 'multiple-choice',
        responseTimeMs: 5000,
        wasCorrect: false,
        difficultyRating: 'hard',
      );

      final completedSession = testSession.copyWith(
        wordsStudied: 12,
        totalCards: 15,
        accuracyPercentage: 80.0,
        cards: [card1, card2],
      );

      expect(completedSession.completionPercentage, 80.0); // 12/15 * 100
      expect(completedSession.correctAnswers, 1); // One correct card
      expect(completedSession.incorrectAnswers, 1); // One incorrect card
      expect(completedSession.averageResponseTime, 4000.0); // (3000 + 5000) / 2
    });

    test('getters handle edge cases correctly', () {
      final emptySession = FlashcardSession.create(
        userId: 'test',
        durationMinutes: 10,
      );

      expect(emptySession.completionPercentage, 0.0);
      expect(emptySession.correctAnswers, 0);
      expect(emptySession.incorrectAnswers, 0);
      expect(emptySession.averageResponseTime, 0.0);
    });
  });

  group('FlashcardSessionCard', () {
    late FlashcardSessionCard testCard;
    late DateTime testTime;

    setUp(() {
      testTime = DateTime(2024, 1, 15, 11, 0);
      testCard = FlashcardSessionCard(
        id: 'card-123',
        sessionId: 'session-456',
        vocabularyItemId: 'vocab-789',
        questionType: 'traditional',
        responseTimeMs: 3500,
        wasCorrect: true,
        difficultyRating: 'good',
        shownAt: testTime,
        answeredAt: testTime.add(const Duration(milliseconds: 3500)),
      );
    });

    test('constructor sets all properties correctly', () {
      expect(testCard.id, 'card-123');
      expect(testCard.sessionId, 'session-456');
      expect(testCard.vocabularyItemId, 'vocab-789');
      expect(testCard.questionType, 'traditional');
      expect(testCard.responseTimeMs, 3500);
      expect(testCard.wasCorrect, true);
      expect(testCard.difficultyRating, 'good');
      expect(testCard.shownAt, testTime);
      expect(testCard.answeredAt,
          testTime.add(const Duration(milliseconds: 3500)));
    });

    test('create factory constructor generates correct card', () {
      final createdCard = FlashcardSessionCard.create(
        sessionId: 'new-session',
        vocabularyItemId: 'new-vocab',
        questionType: 'multiple-choice',
        responseTimeMs: 2000,
        wasCorrect: false,
        difficultyRating: 'hard',
      );

      expect(createdCard.id, isNotEmpty);
      expect(createdCard.sessionId, 'new-session');
      expect(createdCard.vocabularyItemId, 'new-vocab');
      expect(createdCard.questionType, 'multiple-choice');
      expect(createdCard.responseTimeMs, 2000);
      expect(createdCard.wasCorrect, false);
      expect(createdCard.difficultyRating, 'hard');

      // Check that timestamps are recent
      final now = DateTime.now();
      expect(createdCard.shownAt.difference(now).inMinutes.abs(), lessThan(1));
      expect(createdCard.answeredAt?.difference(now).inMinutes.abs() ?? 0,
          lessThan(1));
    });

    test('copyWith updates specified properties only', () {
      final updatedCard = testCard.copyWith(
        wasCorrect: false,
        difficultyRating: 'again',
        responseTimeMs: 5000,
      );

      expect(updatedCard.id, testCard.id);
      expect(updatedCard.sessionId, testCard.sessionId);
      expect(updatedCard.vocabularyItemId, testCard.vocabularyItemId);
      expect(updatedCard.wasCorrect, false); // Updated
      expect(updatedCard.difficultyRating, 'again'); // Updated
      expect(updatedCard.responseTimeMs, 5000); // Updated
      expect(updatedCard.questionType, testCard.questionType); // Unchanged
    });

    test('toJson serializes correctly', () {
      final json = testCard.toJson();

      expect(json['id'], 'card-123');
      expect(json['session_id'], 'session-456');
      expect(json['vocabulary_item_id'], 'vocab-789');
      expect(json['question_type'], 'traditional');
      expect(json['response_time_ms'], 3500);
      expect(json['was_correct'], true);
      expect(json['difficulty_rating'], 'good');
      expect(json['shown_at'], testTime.toIso8601String());
      expect(json['answered_at'],
          testTime.add(const Duration(milliseconds: 3500)).toIso8601String());
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'json-card-456',
        'session_id': 'json-session-789',
        'vocabulary_item_id': 'json-vocab-123',
        'question_type': 'fill-in-blank',
        'response_time_ms': 4200,
        'was_correct': false,
        'difficulty_rating': 'hard',
        'shown_at': '2024-01-18T13:45:00.000Z',
        'answered_at': '2024-01-18T13:45:04.200Z',
      };

      final card = FlashcardSessionCard.fromJson(json);

      expect(card.id, 'json-card-456');
      expect(card.sessionId, 'json-session-789');
      expect(card.vocabularyItemId, 'json-vocab-123');
      expect(card.questionType, 'fill-in-blank');
      expect(card.responseTimeMs, 4200);
      expect(card.wasCorrect, false);
      expect(card.difficultyRating, 'hard');
    });

    test('toSupabase formats for database correctly', () {
      final supabaseData = testCard.toSupabase();

      expect(supabaseData['id'], 'card-123');
      expect(supabaseData['session_id'], 'session-456');
      expect(supabaseData['vocabulary_item_id'], 'vocab-789');
      expect(supabaseData['question_type'], 'traditional');
      expect(supabaseData['response_time_ms'], 3500);
      expect(supabaseData['was_correct'], true);
      expect(supabaseData['difficulty_rating'], 'good');
      expect(supabaseData['shown_at'], testTime.toIso8601String());
      expect(supabaseData['answered_at'],
          testTime.add(const Duration(milliseconds: 3500)).toIso8601String());
    });

    test('fromSupabase creates card from database data', () {
      final supabaseData = {
        'id': 'db-card-789',
        'session_id': 'db-session-123',
        'vocabulary_item_id': 'db-vocab-456',
        'question_type': 'reverse',
        'response_time_ms': 1800,
        'was_correct': true,
        'difficulty_rating': 'easy',
        'shown_at': '2024-01-19T16:20:00.000Z',
        'answered_at': '2024-01-19T16:20:01.800Z',
      };

      final card = FlashcardSessionCard.fromSupabase(supabaseData);

      expect(card.id, 'db-card-789');
      expect(card.sessionId, 'db-session-123');
      expect(card.vocabularyItemId, 'db-vocab-456');
      expect(card.questionType, 'reverse');
      expect(card.responseTimeMs, 1800);
      expect(card.wasCorrect, true);
      expect(card.difficultyRating, 'easy');
    });

    test('basic properties are accessible', () {
      expect(testCard.responseTimeMs, 3500);
      expect(testCard.wasCorrect, true);
      expect(testCard.difficultyRating, 'good');
      expect(testCard.questionType, 'traditional');
      expect(testCard.shownAt, testTime);
      expect(testCard.answeredAt,
          testTime.add(const Duration(milliseconds: 3500)));
    });

    test('timestamps can be compared for response time calculation', () {
      final responseTimeMs =
          testCard.answeredAt?.difference(testCard.shownAt).inMilliseconds ?? 0;
      expect(responseTimeMs, 3500);
    });
  });
}
