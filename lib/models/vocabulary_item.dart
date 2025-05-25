// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class VocabularyItem {
  final String word;
  final String type;  // 'verb', 'noun', or 'adverb'
  final String translation;
  final String? definition;
  final Map<String, dynamic>? conjugations;  // For verbs
  final DateTime dateAdded;
  final int addedCount;  // Changed from reviewCount
  final DateTime? lastAdded;  // Changed from lastReviewed
  final String? lastConversationId;  // Added to track unique conversations

  static const String typeVerb = 'verb';
  static const String typeNoun = 'noun';
  static const String typeAdverb = 'adverb';

  VocabularyItem({
    required this.word,
    required this.type,
    required this.translation,
    this.definition,
    this.conjugations,
    DateTime? dateAdded,
    this.addedCount = 0,
    this.lastAdded,
    this.lastConversationId,
  }) : assert(type == typeVerb || type == typeNoun || type == typeAdverb),
       dateAdded = dateAdded ?? DateTime.now();

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String,
      type: json['type'] as String,
      translation: json['translation'] as String,
      definition: json['definition'] as String?,
      conjugations: json['conjugations'] as Map<String, dynamic>?,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      addedCount: json['addedCount'] as int? ?? 0,
      lastAdded: json['lastAdded'] != null 
          ? DateTime.parse(json['lastAdded'] as String)
          : null,
      lastConversationId: json['lastConversationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'type': type,
      'translation': translation,
      'definition': definition,
      'conjugations': conjugations,
      'dateAdded': dateAdded.toIso8601String(),
      'addedCount': addedCount,
      'lastAdded': lastAdded?.toIso8601String(),
      'lastConversationId': lastConversationId,
    };
  }

  VocabularyItem copyWith({
    String? word,
    String? type,
    String? translation,
    String? definition,
    Map<String, dynamic>? conjugations,
    DateTime? dateAdded,
    int? addedCount,
    DateTime? lastAdded,
    String? lastConversationId,
  }) {
    return VocabularyItem(
      word: word ?? this.word,
      type: type ?? this.type,
      translation: translation ?? this.translation,
      definition: definition ?? this.definition,
      conjugations: conjugations ?? this.conjugations,
      dateAdded: dateAdded ?? this.dateAdded,
      addedCount: addedCount ?? this.addedCount,
      lastAdded: lastAdded ?? this.lastAdded,
      lastConversationId: lastConversationId ?? this.lastConversationId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VocabularyItem &&
        other.word.toLowerCase() == word.toLowerCase() &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(word.toLowerCase(), type);

  Color get typeColor {
    switch (type) {
      case typeVerb:
        return const Color(0xFF2196F3); // Blue
      case typeNoun:
        return const Color(0xFF4CAF50); // Green
      case typeAdverb:
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  IconData get typeIcon {
    switch (type) {
      case typeVerb:
        return Icons.run_circle;
      case typeNoun:
        return Icons.label;
      case typeAdverb:
        return Icons.speed;
      default:
        return Icons.help_outline;
    }
  }
} 