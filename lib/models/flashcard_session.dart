import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'flashcard_session.g.dart';

@JsonSerializable()
class FlashcardSession {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'session_date')
  final DateTime sessionDate;
  @JsonKey(name: 'duration_minutes')
  final int durationMinutes;
  @JsonKey(name: 'words_studied')
  final int wordsStudied;
  @JsonKey(name: 'total_cards')
  final int totalCards;
  @JsonKey(name: 'accuracy_percentage')
  final double accuracyPercentage;
  @JsonKey(name: 'session_type')
  final String sessionType; // 'timed', 'count-based', etc.
  @JsonKey(name: 'is_completed')
  final bool isCompleted;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Runtime-only properties for session management
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<FlashcardSessionCard> cards;

  FlashcardSession({
    required this.id,
    required this.userId,
    required this.sessionDate,
    required this.durationMinutes,
    this.wordsStudied = 0,
    this.totalCards = 0,
    this.accuracyPercentage = 0.0,
    this.sessionType = 'timed',
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.cards = const [],
  });

  factory FlashcardSession.create({
    required String userId,
    required int durationMinutes,
    String sessionType = 'timed',
  }) {
    final now = DateTime.now();
    return FlashcardSession(
      id: const Uuid().v4(),
      userId: userId,
      sessionDate: now,
      durationMinutes: durationMinutes,
      sessionType: sessionType,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory FlashcardSession.fromJson(Map<String, dynamic> json) =>
      _$FlashcardSessionFromJson(json);
  Map<String, dynamic> toJson() => _$FlashcardSessionToJson(this);

  // Supabase-specific methods
  Map<String, dynamic> toSupabase() {
    final json = toJson();
    json['session_date'] = sessionDate.toIso8601String();
    json['created_at'] = createdAt.toIso8601String();
    json['updated_at'] = updatedAt.toIso8601String();
    return json;
  }

  factory FlashcardSession.fromSupabase(Map<String, dynamic> data) {
    final Map<String, dynamic> processedData = Map<String, dynamic>.from(data);

    // Handle DateTime fields
    for (final field in ['session_date', 'created_at', 'updated_at']) {
      if (processedData[field] != null) {
        if (processedData[field] is String) {
          processedData[field] = DateTime.parse(processedData[field]);
        }
      }
    }

    return FlashcardSession.fromJson(processedData);
  }

  FlashcardSession copyWith({
    String? id,
    String? userId,
    DateTime? sessionDate,
    int? durationMinutes,
    int? wordsStudied,
    int? totalCards,
    double? accuracyPercentage,
    String? sessionType,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<FlashcardSessionCard>? cards,
  }) {
    return FlashcardSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionDate: sessionDate ?? this.sessionDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      wordsStudied: wordsStudied ?? this.wordsStudied,
      totalCards: totalCards ?? this.totalCards,
      accuracyPercentage: accuracyPercentage ?? this.accuracyPercentage,
      sessionType: sessionType ?? this.sessionType,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cards: cards ?? this.cards,
    );
  }

  // Helper methods for session statistics
  double get completionPercentage =>
      totalCards > 0 ? (wordsStudied / totalCards) * 100 : 0;

  int get correctAnswers => cards.where((card) => card.wasCorrect).length;

  int get incorrectAnswers => cards.where((card) => !card.wasCorrect).length;

  double get averageResponseTime {
    if (cards.isEmpty) return 0;
    final totalTime =
        cards.map((card) => card.responseTimeMs).reduce((a, b) => a + b);
    return totalTime / cards.length;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlashcardSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class FlashcardSessionCard {
  final String id;
  @JsonKey(name: 'session_id')
  final String sessionId;
  @JsonKey(name: 'vocabulary_item_id')
  final String vocabularyItemId;
  @JsonKey(name: 'question_type')
  final String
      questionType; // 'traditional', 'multiple_choice', 'fill_blank', 'reverse'
  @JsonKey(name: 'response_time_ms')
  final int responseTimeMs;
  @JsonKey(name: 'was_correct')
  final bool wasCorrect;
  @JsonKey(name: 'difficulty_rating')
  final String? difficultyRating; // 'again', 'hard', 'good', 'easy'
  @JsonKey(name: 'shown_at')
  final DateTime shownAt;
  @JsonKey(name: 'answered_at')
  final DateTime? answeredAt;

  FlashcardSessionCard({
    required this.id,
    required this.sessionId,
    required this.vocabularyItemId,
    required this.questionType,
    this.responseTimeMs = 0,
    required this.wasCorrect,
    this.difficultyRating,
    required this.shownAt,
    this.answeredAt,
  });

  factory FlashcardSessionCard.create({
    required String sessionId,
    required String vocabularyItemId,
    required String questionType,
    required bool wasCorrect,
    String? difficultyRating,
    int responseTimeMs = 0,
  }) {
    final now = DateTime.now();
    return FlashcardSessionCard(
      id: const Uuid().v4(),
      sessionId: sessionId,
      vocabularyItemId: vocabularyItemId,
      questionType: questionType,
      wasCorrect: wasCorrect,
      difficultyRating: difficultyRating,
      responseTimeMs: responseTimeMs,
      shownAt: now,
      answeredAt: now,
    );
  }

  factory FlashcardSessionCard.fromJson(Map<String, dynamic> json) =>
      _$FlashcardSessionCardFromJson(json);
  Map<String, dynamic> toJson() => _$FlashcardSessionCardToJson(this);

  // Supabase-specific methods
  Map<String, dynamic> toSupabase() {
    final json = toJson();
    json['shown_at'] = shownAt.toIso8601String();
    if (answeredAt != null) {
      json['answered_at'] = answeredAt!.toIso8601String();
    }
    return json;
  }

  factory FlashcardSessionCard.fromSupabase(Map<String, dynamic> data) {
    final Map<String, dynamic> processedData = Map<String, dynamic>.from(data);

    // Handle DateTime fields
    for (final field in ['shown_at', 'answered_at']) {
      if (processedData[field] != null) {
        if (processedData[field] is String) {
          processedData[field] = DateTime.parse(processedData[field]);
        }
      }
    }

    return FlashcardSessionCard.fromJson(processedData);
  }

  FlashcardSessionCard copyWith({
    String? id,
    String? sessionId,
    String? vocabularyItemId,
    String? questionType,
    int? responseTimeMs,
    bool? wasCorrect,
    String? difficultyRating,
    DateTime? shownAt,
    DateTime? answeredAt,
  }) {
    return FlashcardSessionCard(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      vocabularyItemId: vocabularyItemId ?? this.vocabularyItemId,
      questionType: questionType ?? this.questionType,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      wasCorrect: wasCorrect ?? this.wasCorrect,
      difficultyRating: difficultyRating ?? this.difficultyRating,
      shownAt: shownAt ?? this.shownAt,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlashcardSessionCard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
