import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

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
    try {
      // Create a copy of the data to avoid modifying the original
      final Map<String, dynamic> processedData =
          Map<String, dynamic>.from(data);

      // Debug logs for tracing
      debugPrint(
          '[UserVocabularyItem.fromSupabase] Processing item: ${processedData['word']}');
      debugPrint(
          '[UserVocabularyItem.fromSupabase] Raw data for ${processedData['word']}: $data');

      // Ensure translations is a List<String>
      if (processedData['translations'] != null) {
        if (processedData['translations'] is List) {
          processedData['translations'] =
              (processedData['translations'] as List)
                  .map((e) => e.toString())
                  .toList();
        } else if (processedData['translations'] is String) {
          try {
            processedData['translations'] =
                List<String>.from(jsonDecode(processedData['translations']));
          } catch (_) {
            processedData['translations'] = [
              processedData['translations'].toString()
            ];
          }
        } else {
          processedData['translations'] = [];
        }
      } else {
        processedData['translations'] = [];
      }

      // Ensure forms is a List<String>
      if (processedData['forms'] != null) {
        if (processedData['forms'] is List) {
          processedData['forms'] = (processedData['forms'] as List)
              .map((e) => e.toString())
              .toList();
        } else if (processedData['forms'] is String) {
          try {
            processedData['forms'] =
                List<String>.from(jsonDecode(processedData['forms']));
          } catch (_) {
            processedData['forms'] = [processedData['forms'].toString()];
          }
        } else {
          processedData['forms'] = [];
        }
      } else {
        processedData['forms'] = [];
      }

      // Handle DateTime fields - keep as strings for the generated fromJson method
      // For last_seen
      dynamic lastSeenValue = processedData['last_seen'];
      if (lastSeenValue != null) {
        try {
          if (lastSeenValue is DateTime) {
            processedData['last_seen'] = lastSeenValue.toIso8601String();
          } else if (lastSeenValue is! String) {
            processedData['last_seen'] = lastSeenValue.toString();
          }
          // If it's already a string, keep it as is
        } catch (e) {
          debugPrint(
              '[UserVocabularyItem.fromSupabase] Error processing last_seen ($lastSeenValue): $e');
          processedData['last_seen'] = DateTime.now().toIso8601String();
        }
      } else {
        processedData['last_seen'] = DateTime.now().toIso8601String();
      }
      debugPrint(
          '[UserVocabularyItem.fromSupabase] Processed last_seen: ${processedData['last_seen']}');

      // For first_learned
      dynamic firstLearnedValue = processedData['first_learned'];
      if (firstLearnedValue != null) {
        try {
          if (firstLearnedValue is DateTime) {
            processedData['first_learned'] =
                firstLearnedValue.toIso8601String();
          } else if (firstLearnedValue is! String) {
            processedData['first_learned'] = firstLearnedValue.toString();
          }
          // If it's already a string, keep it as is
        } catch (e) {
          debugPrint(
              '[UserVocabularyItem.fromSupabase] Error processing first_learned ($firstLearnedValue): $e');
          processedData['first_learned'] = DateTime.now().toIso8601String();
        }
      } else {
        processedData['first_learned'] = DateTime.now().toIso8601String();
      }
      debugPrint(
          '[UserVocabularyItem.fromSupabase] Processed first_learned: ${processedData['first_learned']}');

      // For next_review
      dynamic nextReviewValue = processedData['next_review'];
      if (nextReviewValue != null) {
        try {
          if (nextReviewValue is DateTime) {
            processedData['next_review'] = nextReviewValue.toIso8601String();
          } else if (nextReviewValue is! String) {
            processedData['next_review'] = nextReviewValue.toString();
          }
          // If it's already a string, keep it as is
        } catch (e) {
          debugPrint(
              '[UserVocabularyItem.fromSupabase] Error processing next_review ($nextReviewValue): $e');
          processedData['next_review'] =
              DateTime.now().add(const Duration(days: 1)).toIso8601String();
        }
      } else {
        processedData['next_review'] = null; // nextReview can be null
      }
      debugPrint(
          '[UserVocabularyItem.fromSupabase] Processed next_review: ${processedData['next_review']}');

      // Ensure other required fields are present and correctly typed
      if (!processedData.containsKey('id') || processedData['id'] == null) {
        processedData['id'] = const Uuid().v4();
      }
      if (!processedData.containsKey('user_id') ||
          processedData['user_id'] == null) {
        processedData['user_id'] = 'unknown_user';
      }
      if (!processedData.containsKey('word') || processedData['word'] == null) {
        processedData['word'] = 'unknown_word';
      }
      if (!processedData.containsKey('base_form') ||
          processedData['base_form'] == null) {
        processedData['base_form'] = processedData['word'];
      }
      if (!processedData.containsKey('word_type') ||
          processedData['word_type'] == null) {
        processedData['word_type'] = 'unknown';
      }
      if (!processedData.containsKey('language') ||
          processedData['language'] == null) {
        processedData['language'] = 'en';
      }
      if (!processedData.containsKey('translations') ||
          processedData['translations'] == null) {
        processedData['translations'] = <String>[];
      }
      if (!processedData.containsKey('forms') ||
          processedData['forms'] == null) {
        processedData['forms'] = <String>[];
      }
      if (!processedData.containsKey('difficulty_level') ||
          processedData['difficulty_level'] == null) {
        processedData['difficulty_level'] = 1; // Default value
      }
      if (!processedData.containsKey('mastery_level') ||
          processedData['mastery_level'] == null) {
        processedData['mastery_level'] = 0; // Default value
      }
      if (!processedData.containsKey('times_seen') ||
          processedData['times_seen'] == null) {
        processedData['times_seen'] = 0; // Default value
      }
      if (!processedData.containsKey('times_correct') ||
          processedData['times_correct'] == null) {
        processedData['times_correct'] = 0; // Default value
      }
      if (!processedData.containsKey('is_favorite') ||
          processedData['is_favorite'] == null) {
        processedData['is_favorite'] = false; // Default value
      }
      if (!processedData.containsKey('tags') || processedData['tags'] == null) {
        processedData['tags'] = <String>[];
      }
      if (!processedData.containsKey('example_sentences') ||
          processedData['example_sentences'] == null) {
        processedData['example_sentences'] = <String>[];
      }

      final userVocabularyItem = UserVocabularyItem.fromJson(
          processedData); // Use the generated fromJson
      debugPrint(
          '[UserVocabularyItem.fromSupabase] Successfully parsed UserVocabularyItem for ${userVocabularyItem.word}');
      return userVocabularyItem;
    } catch (e) {
      debugPrint(
          '[UserVocabularyItem.fromSupabase] Critical error processing item: $e');
      debugPrint('[UserVocabularyItem.fromSupabase] Raw data: $data');

      // Return a minimal valid object to prevent crash, log missing data
      final String id = data['id']?.toString() ?? const Uuid().v4();
      final String userId = data['user_id']?.toString() ?? 'unknown_user';
      final String word = data['word']?.toString() ?? 'unknown_word';
      final String baseForm = data['base_form']?.toString() ?? word;
      final String wordType = data['word_type']?.toString() ?? 'unknown';
      final String language = data['language']?.toString() ?? 'en';

      debugPrint(
          '[UserVocabularyItem.fromSupabase] Returning fallback UserVocabularyItem due to error. Word: $word');

      return UserVocabularyItem(
        id: id,
        userId: userId,
        word: word,
        baseForm: baseForm,
        wordType: wordType,
        language: language,
        translations: (data['translations'] is List)
            ? List<String>.from(data['translations'])
            : [],
        forms: (data['forms'] is List) ? List<String>.from(data['forms']) : [],
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
        nextReview: null, // Default to null on error
        isFavorite: data['is_favorite'] as bool? ?? false,
        tags: (data['tags'] is List) ? List<String>.from(data['tags']) : [],
        exampleSentences: (data['example_sentences'] is List)
            ? List<String>.from(data['example_sentences'])
            : [],
        sourceMessageId: data['source_message_id']?.toString(),
      );
    }
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
    const performanceWeight =
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
    // Create a copy of the data to avoid modifying the original
    final Map<String, dynamic> processedData = Map<String, dynamic>.from(data);

    // Handle DateTime fields more robustly
    if (processedData['last_updated'] != null) {
      if (processedData['last_updated'] is String) {
        processedData['last_updated'] =
            DateTime.parse(processedData['last_updated']);
      } else if (processedData['last_updated'] is DateTime) {
        // Keep as is - it's already a DateTime
      } else {
        // Convert to string then parse to ensure compatibility
        processedData['last_updated'] =
            DateTime.parse(processedData['last_updated'].toString());
      }
    }

    return UserVocabularyStats.fromJson(processedData);
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
