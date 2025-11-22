import 'package:json_annotation/json_annotation.dart';

part 'language_response.g.dart';

@JsonSerializable()
class LanguageResponse {
  final List<String> corrections;
  @JsonKey(name: 'target_language_sentence')
  final String targetLanguageSentence;
  @JsonKey(name: 'native_language_translation')
  final String nativeLanguageTranslation;
  @JsonKey(name: 'vocabulary_breakdown')
  final List<VocabularyItem> vocabularyBreakdown;
  @JsonKey(name: 'additional_context')
  final String? additionalContext;
  @JsonKey(name: 'languages_used')
  final List<String>? languagesUsed;

  LanguageResponse({
    required this.corrections,
    required this.targetLanguageSentence,
    required this.nativeLanguageTranslation,
    required this.vocabularyBreakdown,
    this.additionalContext,
    this.languagesUsed,
  });

  factory LanguageResponse.fromJson(Map<String, dynamic> json) =>
      _$LanguageResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LanguageResponseToJson(this);
}

@JsonSerializable()
class VocabularyItem {
  final String word;
  @JsonKey(name: 'word_type')
  final String wordType;
  @JsonKey(name: 'base_form')
  final String baseForm;
  final List<String> forms;
  final List<String> translations;

  VocabularyItem({
    required this.word,
    required this.wordType,
    required this.baseForm,
    required this.forms,
    required this.translations,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) =>
      _$VocabularyItemFromJson(json);
  Map<String, dynamic> toJson() => _$VocabularyItemToJson(this);
}
