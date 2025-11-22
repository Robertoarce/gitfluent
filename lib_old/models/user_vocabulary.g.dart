// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_vocabulary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserVocabularyItem _$UserVocabularyItemFromJson(Map<String, dynamic> json) =>
    UserVocabularyItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      word: json['word'] as String,
      baseForm: json['base_form'] as String,
      wordType: json['word_type'] as String,
      language: json['language'] as String,
      translations: (json['translations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      forms:
          (json['forms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      difficultyLevel: (json['difficulty_level'] as num?)?.toInt() ?? 1,
      masteryLevel: (json['mastery_level'] as num?)?.toInt() ?? 0,
      timesSeen: (json['times_seen'] as num?)?.toInt() ?? 1,
      timesCorrect: (json['times_correct'] as num?)?.toInt() ?? 0,
      lastSeen: DateTime.parse(json['last_seen'] as String),
      firstLearned: DateTime.parse(json['first_learned'] as String),
      nextReview: json['next_review'] == null
          ? null
          : DateTime.parse(json['next_review'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      exampleSentences: (json['example_sentences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sourceMessageId: json['source_message_id'] as String?,
    );

Map<String, dynamic> _$UserVocabularyItemToJson(UserVocabularyItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'word': instance.word,
      'base_form': instance.baseForm,
      'word_type': instance.wordType,
      'language': instance.language,
      'translations': instance.translations,
      'forms': instance.forms,
      'difficulty_level': instance.difficultyLevel,
      'mastery_level': instance.masteryLevel,
      'times_seen': instance.timesSeen,
      'times_correct': instance.timesCorrect,
      'last_seen': instance.lastSeen.toIso8601String(),
      'first_learned': instance.firstLearned.toIso8601String(),
      'next_review': instance.nextReview?.toIso8601String(),
      'is_favorite': instance.isFavorite,
      'tags': instance.tags,
      'example_sentences': instance.exampleSentences,
      'source_message_id': instance.sourceMessageId,
    };

UserVocabularyStats _$UserVocabularyStatsFromJson(Map<String, dynamic> json) =>
    UserVocabularyStats(
      userId: json['user_id'] as String,
      language: json['language'] as String,
      totalWords: (json['total_words'] as num?)?.toInt() ?? 0,
      masteredWords: (json['mastered_words'] as num?)?.toInt() ?? 0,
      learningWords: (json['learning_words'] as num?)?.toInt() ?? 0,
      newWords: (json['new_words'] as num?)?.toInt() ?? 0,
      wordsDueReview: (json['words_due_review'] as num?)?.toInt() ?? 0,
      averageMastery: (json['average_mastery'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      wordsByType: (json['words_by_type'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
    );

Map<String, dynamic> _$UserVocabularyStatsToJson(
        UserVocabularyStats instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'language': instance.language,
      'total_words': instance.totalWords,
      'mastered_words': instance.masteredWords,
      'learning_words': instance.learningWords,
      'new_words': instance.newWords,
      'words_due_review': instance.wordsDueReview,
      'average_mastery': instance.averageMastery,
      'last_updated': instance.lastUpdated.toIso8601String(),
      'words_by_type': instance.wordsByType,
    };
