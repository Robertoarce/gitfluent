import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VocabularyItem {
  final String word;
  final String type; // 'verb' or 'noun'
  final String translation;
  int count;
  final DateTime firstSeen;
  DateTime lastSeen;

  VocabularyItem({
    required this.word,
    required this.type,
    required this.translation,
    this.count = 1,
    DateTime? firstSeen,
    DateTime? lastSeen,
  })  : firstSeen = firstSeen ?? DateTime.now(),
        lastSeen = lastSeen ?? DateTime.now();

  VocabularyItem copyWith({
    String? word,
    String? type,
    String? translation,
    int? count,
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) {
    return VocabularyItem(
      word: word ?? this.word,
      type: type ?? this.type,
      translation: translation ?? this.translation,
      count: count ?? this.count,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'type': type,
        'translation': translation,
        'count': count,
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory VocabularyItem.fromJson(Map<String, dynamic> json) => VocabularyItem(
        word: json['word'],
        type: json['type'],
        translation: json['translation'],
        count: json['count'],
        firstSeen: DateTime.parse(json['firstSeen']),
        lastSeen: DateTime.parse(json['lastSeen']),
      );
}

class VocabularyService extends ChangeNotifier {
  late SharedPreferences _prefs;
  final Map<String, VocabularyItem> _vocabulary = {};
  static const String _storageKey = 'vocabulary';

  Map<String, VocabularyItem> get vocabulary => Map.unmodifiable(_vocabulary);
  List<VocabularyItem> get verbs => 
      _vocabulary.values.where((item) => item.type == 'verb').toList();
  List<VocabularyItem> get nouns => 
      _vocabulary.values.where((item) => item.type == 'noun').toList();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    final String? vocabJson = _prefs.getString(_storageKey);
    if (vocabJson != null) {
      final Map<String, dynamic> vocabMap = json.decode(vocabJson);
      vocabMap.forEach((key, value) {
        _vocabulary[key] = VocabularyItem.fromJson(value);
      });
    }
    notifyListeners();
  }

  Future<void> _saveVocabulary() async {
    final Map<String, dynamic> vocabMap = {};
    _vocabulary.forEach((key, value) {
      vocabMap[key] = value.toJson();
    });
    await _prefs.setString(_storageKey, json.encode(vocabMap));
    notifyListeners();
  }

  Future<void> addOrUpdateItem(String word, String type, String translation) async {
    final normalizedWord = word.toLowerCase().trim();
    if (_vocabulary.containsKey(normalizedWord)) {
      final existingItem = _vocabulary[normalizedWord]!;
      _vocabulary[normalizedWord] = existingItem.copyWith(
        count: existingItem.count + 1,
        lastSeen: DateTime.now(),
        // Update translation only if it's more complete
        translation: translation.length > existingItem.translation.length 
            ? translation 
            : existingItem.translation,
      );
    } else {
      _vocabulary[normalizedWord] = VocabularyItem(
        word: normalizedWord,
        type: type,
        translation: translation,
      );
    }
    await _saveVocabulary();
  }

  Future<void> removeItem(String word) async {
    final normalizedWord = word.toLowerCase().trim();
    _vocabulary.remove(normalizedWord);
    await _saveVocabulary();
  }

  List<VocabularyItem> getMostFrequent({int limit = 10}) {
    final items = _vocabulary.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(limit).toList();
  }

  List<VocabularyItem> getRecentlyAdded({int limit = 10}) {
    final items = _vocabulary.values.toList()
      ..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));
    return items.take(limit).toList();
  }

  List<VocabularyItem> searchVocabulary(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    return _vocabulary.values
        .where((item) => 
            item.word.toLowerCase().contains(normalizedQuery) ||
            item.translation.toLowerCase().contains(normalizedQuery))
        .toList();
  }
} 