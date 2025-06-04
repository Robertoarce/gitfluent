import 'package:flutter/foundation.dart';

class ConversationResponse {
  final String response;
  final String translation;
  final List<NewVocabularyItem> newVocabulary;
  final List<CorrectionItem> corrections;
  final String followUpQuestion;

  ConversationResponse({
    required this.response,
    required this.translation,
    required this.newVocabulary,
    required this.corrections,
    required this.followUpQuestion,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) {
    var newVocabularyList = json['new_vocabulary'] as List?;
    List<NewVocabularyItem> newVocabularyItems = newVocabularyList != null
        ? newVocabularyList.map((i) => NewVocabularyItem.fromJson(i)).toList()
        : [];

    var correctionsList = json['corrections'] as List?;
    List<CorrectionItem> correctionItems = correctionsList != null
        ? correctionsList.map((i) => CorrectionItem.fromJson(i)).toList()
        : [];

    return ConversationResponse(
      response: json['response'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      newVocabulary: newVocabularyItems,
      corrections: correctionItems,
      followUpQuestion: json['follow_up_question'] as String? ?? '',
    );
  }
}

class NewVocabularyItem {
  final String word;
  final String meaning;
  final String example;

  NewVocabularyItem({
    required this.word,
    required this.meaning,
    required this.example,
  });

  factory NewVocabularyItem.fromJson(Map<String, dynamic> json) {
    return NewVocabularyItem(
      word: json['word'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      example: json['example'] as String? ?? '',
    );
  }
}

class CorrectionItem {
  final String incorrect;
  final String correct;
  final String explanation;

  CorrectionItem({
    required this.incorrect,
    required this.correct,
    required this.explanation,
  });

  factory CorrectionItem.fromJson(Map<String, dynamic> json) {
    return CorrectionItem(
      incorrect: json['incorrect'] as String? ?? '',
      correct: json['correct'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }
} 