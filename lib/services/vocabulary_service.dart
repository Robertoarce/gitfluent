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

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    try {
      return VocabularyItem(
        word: json['word'] as String,
        type: json['type'] as String,
        translation: json['translation'] as String,
        count: json['count'] as int,
        firstSeen: DateTime.parse(json['firstSeen'] as String),
        lastSeen: DateTime.parse(json['lastSeen'] as String),
      );
    } catch (e) {
      debugPrint('Error parsing VocabularyItem: $e');
      // Return a default item if parsing fails
      return VocabularyItem(
        word: json['word'] as String? ?? 'unknown',
        type: json['type'] as String? ?? 'noun',
        translation: json['translation'] as String? ?? 'unknown',
      );
    }
  }
}

class VocabularyService extends ChangeNotifier {
  SharedPreferences? _prefs;
  final Map<String, VocabularyItem> _vocabulary = {};
  static const String _storageKey = 'vocabulary';
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  Map<String, VocabularyItem> get vocabulary => Map.unmodifiable(_vocabulary);
  List<VocabularyItem> get verbs => 
      _vocabulary.values.where((item) => item.type == 'verb').toList();
  List<VocabularyItem> get nouns => 
      _vocabulary.values.where((item) => item.type == 'noun').toList();

  Future<void> init() async {
    try {
      debugPrint('Initializing VocabularyService...');
      _prefs = await SharedPreferences.getInstance();
      await _loadVocabulary();
      _isInitialized = true;
      debugPrint('VocabularyService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing VocabularyService: $e');
      _isInitialized = false;
    }
  }

  Future<void> _loadVocabulary() async {
    try {
      final String? vocabJson = _prefs?.getString(_storageKey);
      if (vocabJson != null) {
        debugPrint('Loading vocabulary from storage...');
        final Map<String, dynamic> vocabMap = json.decode(vocabJson);
        _vocabulary.clear();
        vocabMap.forEach((key, value) {
          try {
            _vocabulary[key] = VocabularyItem.fromJson(value);
          } catch (e) {
            debugPrint('Error loading vocabulary item: $e');
          }
        });
        debugPrint('Loaded ${_vocabulary.length} vocabulary items');
      } else {
        debugPrint('No vocabulary found in storage');
      }
    } catch (e) {
      debugPrint('Error loading vocabulary: $e');
    }
    notifyListeners();
  }

  Future<void> _saveVocabulary() async {
    try {
      if (_prefs == null) {
        debugPrint('SharedPreferences not initialized');
        return;
      }

      final Map<String, dynamic> vocabMap = {};
      _vocabulary.forEach((key, value) {
        vocabMap[key] = value.toJson();
      });
      
      final String jsonString = json.encode(vocabMap);
      await _prefs!.setString(_storageKey, jsonString);
      debugPrint('Saved ${_vocabulary.length} vocabulary items');
    } catch (e) {
      debugPrint('Error saving vocabulary: $e');
    }
    notifyListeners();
  }

  Future<void> addOrUpdateItem(String word, String type, String translation) async {
    if (!_isInitialized) {
      debugPrint('VocabularyService not initialized');
      return;
    }

    try {
      final normalizedWord = word.toLowerCase().trim();
      if (_vocabulary.containsKey(normalizedWord)) {
        final existingItem = _vocabulary[normalizedWord]!;
        _vocabulary[normalizedWord] = existingItem.copyWith(
          count: existingItem.count + 1,
          lastSeen: DateTime.now(),
          translation: translation.length > existingItem.translation.length 
              ? translation 
              : existingItem.translation,
        );
        debugPrint('Updated vocabulary item: $normalizedWord');
      } else {
        _vocabulary[normalizedWord] = VocabularyItem(
          word: normalizedWord,
          type: type,
          translation: translation,
        );
        debugPrint('Added new vocabulary item: $normalizedWord');
      }
      await _saveVocabulary();
    } catch (e) {
      debugPrint('Error adding/updating vocabulary item: $e');
    }
  }

  Future<void> removeItem(String word) async {
    if (!_isInitialized) {
      debugPrint('VocabularyService not initialized');
      return;
    }

    try {
      final normalizedWord = word.toLowerCase().trim();
      _vocabulary.remove(normalizedWord);
      debugPrint('Removed vocabulary item: $normalizedWord');
      await _saveVocabulary();
    } catch (e) {
      debugPrint('Error removing vocabulary item: $e');
    }
  }

  List<VocabularyItem> getMostFrequent({int limit = 10}) {
    if (!_isInitialized) {
      debugPrint('VocabularyService not initialized');
      return [];
    }

    final items = _vocabulary.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(limit).toList();
  }

  List<VocabularyItem> getRecentlyAdded({int limit = 10}) {
    if (!_isInitialized) {
      debugPrint('VocabularyService not initialized');
      return [];
    }

    final items = _vocabulary.values.toList()
      ..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));
    return items.take(limit).toList();
  }

  List<VocabularyItem> searchVocabulary(String query) {
    if (!_isInitialized) {
      debugPrint('VocabularyService not initialized');
      return [];
    }

    final normalizedQuery = query.toLowerCase().trim();
    return _vocabulary.values
        .where((item) => 
            item.word.toLowerCase().contains(normalizedQuery) ||
            item.translation.toLowerCase().contains(normalizedQuery))
        .toList();
  }
} 