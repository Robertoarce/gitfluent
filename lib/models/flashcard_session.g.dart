// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlashcardSession _$FlashcardSessionFromJson(Map<String, dynamic> json) =>
    FlashcardSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      wordsStudied: (json['words_studied'] as num?)?.toInt() ?? 0,
      totalCards: (json['total_cards'] as num?)?.toInt() ?? 0,
      accuracyPercentage:
          (json['accuracy_percentage'] as num?)?.toDouble() ?? 0.0,
      sessionType: json['session_type'] as String? ?? 'timed',
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$FlashcardSessionToJson(FlashcardSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'session_date': instance.sessionDate.toIso8601String(),
      'duration_minutes': instance.durationMinutes,
      'words_studied': instance.wordsStudied,
      'total_cards': instance.totalCards,
      'accuracy_percentage': instance.accuracyPercentage,
      'session_type': instance.sessionType,
      'is_completed': instance.isCompleted,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

FlashcardSessionCard _$FlashcardSessionCardFromJson(
        Map<String, dynamic> json) =>
    FlashcardSessionCard(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      vocabularyItemId: json['vocabulary_item_id'] as String,
      questionType: json['question_type'] as String,
      responseTimeMs: (json['response_time_ms'] as num?)?.toInt() ?? 0,
      wasCorrect: json['was_correct'] as bool,
      difficultyRating: json['difficulty_rating'] as String?,
      shownAt: DateTime.parse(json['shown_at'] as String),
      answeredAt: json['answered_at'] == null
          ? null
          : DateTime.parse(json['answered_at'] as String),
    );

Map<String, dynamic> _$FlashcardSessionCardToJson(
        FlashcardSessionCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'session_id': instance.sessionId,
      'vocabulary_item_id': instance.vocabularyItemId,
      'question_type': instance.questionType,
      'response_time_ms': instance.responseTimeMs,
      'was_correct': instance.wasCorrect,
      'difficulty_rating': instance.difficultyRating,
      'shown_at': instance.shownAt.toIso8601String(),
      'answered_at': instance.answeredAt?.toIso8601String(),
    };
