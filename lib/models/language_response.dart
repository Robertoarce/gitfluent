// Model class for the language learning response in JSON format
class LanguageResponse {
  final List<String> corrections;
  final String targetLanguageSentence;
  final String nativeLanguageTranslation;
  final List<VocabularyBreakdown> vocabularyBreakdown;
  final String? additionalContext;

  LanguageResponse({
    required this.corrections,
    required this.targetLanguageSentence,
    required this.nativeLanguageTranslation,
    required this.vocabularyBreakdown,
    this.additionalContext,
  });

  factory LanguageResponse.fromJson(Map<String, dynamic> json) {
    return LanguageResponse(
      corrections: List<String>.from(json['corrections'] ?? []),
      targetLanguageSentence: json['target_language_sentence'] ?? '',
      nativeLanguageTranslation: json['native_language_translation'] ?? '',
      vocabularyBreakdown: (json['vocabulary_breakdown'] as List?)
          ?.map((item) => VocabularyBreakdown.fromJson(item))
          .toList() ?? [],
      additionalContext: json['additional_context'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'corrections': corrections,
      'target_language_sentence': targetLanguageSentence,
      'native_language_translation': nativeLanguageTranslation,
      'vocabulary_breakdown': vocabularyBreakdown.map((v) => v.toJson()).toList(),
      'additional_context': additionalContext,
    };
  }
}

class VocabularyBreakdown {
  final String word;
  final String wordType;
  final String baseForm;
  final List<String> forms;
  final List<String> translations;

  VocabularyBreakdown({
    required this.word,
    required this.wordType,
    required this.baseForm,
    required this.forms,
    required this.translations,
  });

  factory VocabularyBreakdown.fromJson(Map<String, dynamic> json) {
    return VocabularyBreakdown(
      word: json['word'] ?? '',
      wordType: json['word_type'] ?? '',
      baseForm: json['base_form'] ?? '',
      forms: List<String>.from(json['forms'] ?? []),
      translations: List<String>.from(json['translations'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'word_type': wordType,
      'base_form': baseForm,
      'forms': forms,
      'translations': translations,
    };
  }
} 