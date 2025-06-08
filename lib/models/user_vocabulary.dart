import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:llm_chat_app/services/logging_service.dart';

part 'user_vocabulary.g.dart';

@JsonSerializable()
class UserVocabularyItem {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String word;
  @JsonKey(name: 'base_form')
  final String baseForm;
  @JsonKey(name: 'word_type')
  final String wordType; // verb, noun, adjective, etc.
  final String language;
  final List<String> translations;
  final List<String> forms;
  @JsonKey(name: 'difficulty_level')
  final int difficultyLevel; // 1-5
  @JsonKey(name: 'mastery_level')
  final int masteryLevel; // 0-100
  @JsonKey(name: 'times_seen')
  final int timesSeen;
  @JsonKey(name: 'times_correct')
  final int timesCorrect;
  @JsonKey(name: 'last_seen')
  final DateTime lastSeen;
  @JsonKey(name: 'first_learned')
  final DateTime firstLearned;
  @JsonKey(name: 'next_review')
  final DateTime? nextReview;
  @JsonKey(name: 'is_favorite')
  final bool isFavorite;
  final List<String> tags;
  @JsonKey(name: 'example_sentences')
  final List<String> exampleSentences;
  @JsonKey(name: 'source_message_id')
  final String?
      sourceMessageId; // Reference to the chat message where it was learned

  UserVocabularyItem({
    required this.id,
    required this.userId,
    required this.word,
    required this.baseForm,
    required this.wordType,
    required this.language,
    this.translations = const [],
    this.forms = const [],
    this.difficultyLevel = 1,
    this.masteryLevel = 0,
    this.timesSeen = 1,
    this.timesCorrect = 0,
    required this.lastSeen,
    required this.firstLearned,
    this.nextReview,
    this.isFavorite = false,
    this.tags = const [],
    this.exampleSentences = const [],
    this.sourceMessageId,
  });

  factory UserVocabularyItem.fromJson(Map<String, dynamic> json) =>
      _$UserVocabularyItemFromJson(json);
  Map<String, dynamic> toJson() => _$UserVocabularyItemToJson(this);

  // Legacy methods for backward compatibility
  Map<String, dynamic> toMap() => toJson();
  factory UserVocabularyItem.fromMap(Map<String, dynamic> map) =>
      UserVocabularyItem.fromJson(map);

  // Supabase-specific methods
  Map<String, dynamic> toSupabase() {
    final json = toJson();
    json['last_seen'] = lastSeen.toIso8601String();
    json['first_learned'] = firstLearned.toIso8601String();
    json['next_review'] = nextReview?.toIso8601String();
    return json;
  }

  factory UserVocabularyItem.fromSupabase(Map<String, dynamic> data) {
    final LoggingService logger = LoggingService();
    try {
      final processedData = Map<String, dynamic>.from(data);
      logger.log(LogCategory.database,
          '[UserVocabularyItem.fromSupabase] Processing item: ${processedData['word']}');

      // Ensure translations is a List<String>
      if (processedData['translations'] != null) {
        if (processedData['translations'] is List) {
          final translationsList = processedData['translations'] as List;
          processedData['translations'] =
              translationsList.map((e) => e.toString()).toList();
        } else if (processedData['translations'] is String) {
          // Handle string representation of list
          final translationsString = processedData['translations'] as String;
          if (translationsString.startsWith('[') &&
              translationsString.endsWith(']')) {
            // Try to parse as JSON
            try {
              final List parsed = jsonDecode(translationsString);
              processedData['translations'] =
                  parsed.map((e) => e.toString()).toList();
            } catch (_) {
              // Fallback if not valid JSON
              processedData['translations'] = [translationsString];
            }
          } else {
            processedData['translations'] = [translationsString];
          }
        } else {
          processedData['translations'] = [];
        }
      }

      // Ensure forms is a List<String>
      if (processedData['forms'] != null) {
        if (processedData['forms'] is List) {
          final formsList = processedData['forms'] as List;
          processedData['forms'] = formsList.map((e) => e.toString()).toList();
        } else if (processedData['forms'] is String) {
          // Handle string representation of list
          final formsString = processedData['forms'] as String;
          if (formsString.startsWith('[') && formsString.endsWith(']')) {
            // Try to parse as JSON
            try {
              final List parsed = jsonDecode(formsString);
              processedData['forms'] = parsed.map((e) => e.toString()).toList();
            } catch (_) {
              // Fallback if not valid JSON
              processedData['forms'] = [formsString];
            }
          } else {
            processedData['forms'] = [formsString];
          }
        } else {
          processedData['forms'] = [];
        }
      }

      // Handle DateTime fields more robustly
      if (processedData['last_seen'] != null) {
        try {
          if (processedData['last_seen'] is String) {
            processedData['last_seen'] =
                DateTime.parse(processedData['last_seen']);
          } else if (processedData['last_seen'] is DateTime) {
            // Keep as is - it's already a DateTime
          } else {
            // Convert to string then parse to ensure compatibility
            processedData['last_seen'] =
                DateTime.parse(processedData['last_seen'].toString());
          }
        } catch (e) {
          debugPrint(
              '[UserVocabularyItem.fromSupabase] Error parsing last_seen: $e');
          processedData['last_seen'] = DateTime.now();
        }
      } else {
        processedData['last_seen'] = DateTime.now();
      }

      if (processedData['first_learned'] != null) {
        try {
          if (processedData['first_learned'] is String) {
            processedData['first_learned'] =
                DateTime.parse(processedData['first_learned']);
          } else if (processedData['first_learned'] is DateTime) {
            // Keep as is - it's already a DateTime
          } else {
            // Convert to string then parse to ensure compatibility
            processedData['first_learned'] =
                DateTime.parse(processedData['first_learned'].toString());
          }
        } catch (e) {
          debugPrint(
              '[UserVocabularyItem.fromSupabase] Error parsing first_learned: $e');
          processedData['first_learned'] = DateTime.now();
        }
      } else {
        processedData['first_learned'] = DateTime.now();
      }

      if (processedData['next_review'] != null) {
        try {
          if (processedData['next_review'] is String) {
            processedData['next_review'] =
                DateTime.parse(processedData['next_review']);
          } else if (processedData['next_review'] is DateTime) {
            // Keep as is - it's already a DateTime
          } else {
            // Convert to string then parse to ensure compatibility
            processedData['next_review'] =
                DateTime.parse(processedData['next_review'].toString());
          }
        } catch (e) {
          debugPrint(
              '[UserVocabularyItem.fromSupabase] Error parsing next_review: $e');
          // Set default next review date to tomorrow
          processedData['next_review'] =
              DateTime.now().add(const Duration(days: 1));
        }
      }

      // Ensure other required fields are present
      if (!processedData.containsKey('id') || processedData['id'] == null) {
        processedData['id'] = const Uuid().v4();
      }

      if (!processedData.containsKey('word_type') ||
          processedData['word_type'] == null) {
        processedData['word_type'] = 'unknown';
      }

      return UserVocabularyItem.fromJson(processedData);
    } catch (e) {
      logger.log(LogCategory.database,
          '[UserVocabularyItem.fromSupabase] Critical error processing item: $e',
          isError: true);
      logger.log(LogCategory.database,
          '[UserVocabularyItem.fromSupabase] Raw data: $data',
          isError: true);

      // Return a minimal valid object
      return UserVocabularyItem(
        id: const Uuid().v4(),
        userId: data['user_id']?.toString() ?? 'unknown',
        word: data['word']?.toString() ?? 'unknown',
        baseForm: data['base_form']?.toString() ??
            data['word']?.toString() ??
            'unknown',
        wordType: data['word_type']?.toString() ?? 'unknown',
        language: data['language']?.toString() ?? 'en',
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
      );
    }
  }

  // Firebase-specific methods
  Map<String, dynamic> toFirestore() => toJson();

  factory UserVocabularyItem.fromFirestore(Map<String, dynamic> data) {
    // Handle Firebase Timestamp objects
    if (data['last_seen'] != null &&
        data['last_seen'].runtimeType.toString().contains('Timestamp')) {
      data['last_seen'] = (data['last_seen'] as dynamic).toDate();
    }
    if (data['first_learned'] != null &&
        data['first_learned'].runtimeType.toString().contains('Timestamp')) {
      data['first_learned'] = (data['first_learned'] as dynamic).toDate();
    }
    if (data['next_review'] != null &&
        data['next_review'].runtimeType.toString().contains('Timestamp')) {
      data['next_review'] = (data['next_review'] as dynamic).toDate();
    }
    return UserVocabularyItem.fromJson(data);
  }

  UserVocabularyItem copyWith({
    String? id,
    String? userId,
    String? word,
    String? baseForm,
    String? wordType,
    String? language,
    List<String>? translations,
    List<String>? forms,
    int? difficultyLevel,
    int? masteryLevel,
    int? timesSeen,
    int? timesCorrect,
    DateTime? lastSeen,
    DateTime? firstLearned,
    DateTime? nextReview,
    bool? isFavorite,
    List<String>? tags,
    List<String>? exampleSentences,
    String? sourceMessageId,
  }) {
    return UserVocabularyItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      word: word ?? this.word,
      baseForm: baseForm ?? this.baseForm,
      wordType: wordType ?? this.wordType,
      language: language ?? this.language,
      translations: translations ?? this.translations,
      forms: forms ?? this.forms,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      timesSeen: timesSeen ?? this.timesSeen,
      timesCorrect: timesCorrect ?? this.timesCorrect,
      lastSeen: lastSeen ?? this.lastSeen,
      firstLearned: firstLearned ?? this.firstLearned,
      nextReview: nextReview ?? this.nextReview,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      exampleSentences: exampleSentences ?? this.exampleSentences,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
    );
  }

  // Calculate accuracy percentage
  double get accuracy => timesSeen > 0 ? (timesCorrect / timesSeen) * 100 : 0;

  // Check if word needs review based on spaced repetition
  bool get needsReview =>
      nextReview != null && DateTime.now().isAfter(nextReview!);

  // Calculate next review date based on mastery level
  DateTime calculateNextReview() {
    final now = DateTime.now();
    final days = switch (masteryLevel) {
      >= 90 => 30, // Mastered - review monthly
      >= 70 => 14, // Good - review bi-weekly
      >= 50 => 7, // Fair - review weekly
      >= 30 => 3, // Poor - review every 3 days
      _ => 1, // New/Very poor - review daily
    };
    return now.add(Duration(days: days));
  }

  // Update mastery level based on performance
  UserVocabularyItem updateMastery(bool wasCorrect) {
    final newTimesSeen = timesSeen + 1;
    final newTimesCorrect = wasCorrect ? timesCorrect + 1 : timesCorrect;
    final newAccuracy = (newTimesCorrect / newTimesSeen) * 100;

    // Calculate new mastery level (weighted average of current mastery and recent performance)
    final performanceWeight =
        0.3; // How much recent performance affects mastery
    final currentWeight = 1 - performanceWeight;
    final newMasteryLevel =
        ((masteryLevel * currentWeight) + (newAccuracy * performanceWeight))
            .round();

    return copyWith(
      timesSeen: newTimesSeen,
      timesCorrect: newTimesCorrect,
      masteryLevel: newMasteryLevel.clamp(0, 100),
      lastSeen: DateTime.now(),
      nextReview: calculateNextReview(),
    );
  }
}

@JsonSerializable()
class UserVocabularyStats {
  @JsonKey(name: 'user_id')
  final String userId;
  final String language;
  @JsonKey(name: 'total_words')
  final int totalWords;
  @JsonKey(name: 'mastered_words')
  final int masteredWords; // mastery >= 90
  @JsonKey(name: 'learning_words')
  final int learningWords; // mastery 30-89
  @JsonKey(name: 'new_words')
  final int newWords; // mastery < 30
  @JsonKey(name: 'words_due_review')
  final int wordsDueReview;
  @JsonKey(name: 'average_mastery')
  final double averageMastery;
  @JsonKey(name: 'last_updated')
  final DateTime lastUpdated;
  @JsonKey(name: 'words_by_type')
  final Map<String, int> wordsByType; // verb: 50, noun: 30, etc.

  UserVocabularyStats({
    required this.userId,
    required this.language,
    this.totalWords = 0,
    this.masteredWords = 0,
    this.learningWords = 0,
    this.newWords = 0,
    this.wordsDueReview = 0,
    this.averageMastery = 0.0,
    required this.lastUpdated,
    this.wordsByType = const {},
  });

  factory UserVocabularyStats.fromJson(Map<String, dynamic> json) =>
      _$UserVocabularyStatsFromJson(json);
  Map<String, dynamic> toJson() => _$UserVocabularyStatsToJson(this);

  // Legacy methods for backward compatibility
  Map<String, dynamic> toMap() => toJson();
  factory UserVocabularyStats.fromMap(Map<String, dynamic> map) =>
      UserVocabularyStats.fromJson(map);

  // Supabase-specific methods
  Map<String, dynamic> toSupabase() {
    final json = toJson();
    json['last_updated'] = lastUpdated.toIso8601String();
    return json;
  }

  factory UserVocabularyStats.fromSupabase(Map<String, dynamic> data) {
    return UserVocabularyStats.fromJson(data);
  }

  // Firebase-specific methods
  Map<String, dynamic> toFirestore() => toJson();

  factory UserVocabularyStats.fromFirestore(Map<String, dynamic> data) {
    if (data['last_updated'] != null &&
        data['last_updated'].runtimeType.toString().contains('Timestamp')) {
      data['last_updated'] = (data['last_updated'] as dynamic).toDate();
    }
    return UserVocabularyStats.fromJson(data);
  }

  UserVocabularyStats copyWith({
    String? userId,
    String? language,
    int? totalWords,
    int? masteredWords,
    int? learningWords,
    int? newWords,
    int? wordsDueReview,
    double? averageMastery,
    DateTime? lastUpdated,
    Map<String, int>? wordsByType,
  }) {
    return UserVocabularyStats(
      userId: userId ?? this.userId,
      language: language ?? this.language,
      totalWords: totalWords ?? this.totalWords,
      masteredWords: masteredWords ?? this.masteredWords,
      learningWords: learningWords ?? this.learningWords,
      newWords: newWords ?? this.newWords,
      wordsDueReview: wordsDueReview ?? this.wordsDueReview,
      averageMastery: averageMastery ?? this.averageMastery,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      wordsByType: wordsByType ?? this.wordsByType,
    );
  }

  // Calculate progress percentage
  double get progressPercentage =>
      totalWords > 0 ? (masteredWords / totalWords) * 100 : 0;

  // Get learning efficiency (mastered words per total study time)
  double getLearningEfficiency(int totalStudyTimeMinutes) {
    return totalStudyTimeMinutes > 0
        ? masteredWords / (totalStudyTimeMinutes / 60.0)
        : 0;
  }
}
