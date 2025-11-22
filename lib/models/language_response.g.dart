// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LanguageResponse _$LanguageResponseFromJson(Map<String, dynamic> json) =>
    LanguageResponse(
      corrections: (json['corrections'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      targetLanguageSentence: json['target_language_sentence'] as String,
      nativeLanguageTranslation: json['native_language_translation'] as String,
      vocabularyBreakdown: (json['vocabulary_breakdown'] as List<dynamic>)
          .map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      additionalContext: json['additional_context'] as String?,
      languagesUsed: (json['languages_used'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$LanguageResponseToJson(LanguageResponse instance) =>
    <String, dynamic>{
      'corrections': instance.corrections,
      'target_language_sentence': instance.targetLanguageSentence,
      'native_language_translation': instance.nativeLanguageTranslation,
      'vocabulary_breakdown': instance.vocabularyBreakdown,
      'additional_context': instance.additionalContext,
      'languages_used': instance.languagesUsed,
    };

VocabularyItem _$VocabularyItemFromJson(Map<String, dynamic> json) =>
    VocabularyItem(
      word: json['word'] as String,
      wordType: json['word_type'] as String,
      baseForm: json['base_form'] as String,
      forms: (json['forms'] as List<dynamic>).map((e) => e as String).toList(),
      translations: (json['translations'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$VocabularyItemToJson(VocabularyItem instance) =>
    <String, dynamic>{
      'word': instance.word,
      'word_type': instance.wordType,
      'base_form': instance.baseForm,
      'forms': instance.forms,
      'translations': instance.translations,
    };
