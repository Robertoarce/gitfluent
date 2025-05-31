import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/vocabulary_item.dart';
import '../models/user_vocabulary.dart';
import 'user_service.dart';

class VocabularyService extends ChangeNotifier {
  static const String _storageKey = 'vocabulary_items';
  late SharedPreferences _prefs;
  List<VocabularyItem> _items = [];
  bool _isInitialized = false;
  UserService? _userService;

  bool get isInitialized => _isInitialized;
  List<VocabularyItem> get items => List.unmodifiable(_items);

  // Set the user service for integration
  void setUserService(UserService userService) {
    _userService = userService;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadItems();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadItems() async {
    try {
      final String? storedItems = _prefs.getString(_storageKey);
      if (storedItems != null) {
        final List<dynamic> decodedItems = jsonDecode(storedItems);
        _items =
            decodedItems.map((item) => VocabularyItem.fromJson(item)).toList();
      }

      // Fetch from user service if logged in
      if (_userService != null && _userService!.isLoggedIn) {
        final userVocabulary = await _userService!.getUserVocabulary();
        if (userVocabulary.isNotEmpty) {
          // Convert UserVocabularyItem to VocabularyItem and merge
          // For simplicity, we'll overwrite local items with server items.
          _items = userVocabulary
              .map(
                  (userItem) => VocabularyItem.fromUserVocabularyItem(userItem))
              .toList();
        }
      }
      _sortItems();
    } catch (e) {
      debugPrint('Error loading items: $e');
      _items = [];
    }
  }

  void _sortItems() {
    _items.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
  }

  Future<void> _saveItems() async {
    try {
      final String encodedItems =
          jsonEncode(_items.map((e) => e.toJson()).toList());
      await _prefs.setString(_storageKey, encodedItems);
    } catch (e) {
      debugPrint('Error saving items: $e');
    }
  }

  Future<void> addOrUpdateItem(
    String word,
    String type,
    String translation, {
    String? definition,
    Map<String, dynamic>? conjugations,
    String? conversationId,
  }) async {
    if (!_isInitialized) {
      debugPrint('VocabularyService not initialized');
      return;
    }

    try {
      // Save to local storage (legacy support)
      await _saveToLocalStorage(word, type, translation,
          definition: definition,
          conjugations: conjugations,
          conversationId: conversationId);

      // Save to user system if available
      if (_userService != null && _userService!.isLoggedIn) {
        await _saveToUserSystem(word, type, translation,
            definition: definition,
            conjugations: conjugations,
            conversationId: conversationId);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding/updating item: $e');
      rethrow;
    }
  }

  Future<void> _saveToLocalStorage(
    String word,
    String type,
    String translation, {
    String? definition,
    Map<String, dynamic>? conjugations,
    String? conversationId,
  }) async {
    final index = _items.indexWhere((item) =>
        item.word.toLowerCase() == word.toLowerCase() && item.type == type);

    final now = DateTime.now();

    if (index >= 0) {
      // Update existing item
      final existingItem = _items[index];
      // Only increment count if this is from a different conversation
      final shouldIncrement = conversationId != null &&
          existingItem.lastConversationId != conversationId;

      _items[index] = existingItem.copyWith(
        translation: translation,
        definition: definition,
        conjugations: conjugations,
        addedCount: shouldIncrement
            ? existingItem.addedCount + 1
            : existingItem.addedCount,
        lastAdded: shouldIncrement ? now : existingItem.lastAdded,
        lastConversationId: conversationId,
      );
    } else {
      // Add new item
      _items.add(VocabularyItem(
        word: word,
        type: type,
        translation: translation,
        definition: definition,
        conjugations: conjugations,
        addedCount: 1,
        lastAdded: now,
        lastConversationId: conversationId,
      ));
    }

    _sortItems();
    await _saveItems();
  }

  Future<void> _saveToUserSystem(
    String word,
    String type,
    String translation, {
    String? definition,
    Map<String, dynamic>? conjugations,
    String? conversationId,
  }) async {
    if (_userService == null || !_userService!.isLoggedIn) return;

    try {
      final user = _userService!.currentUser!;
      final now = DateTime.now();

      // Convert type to match UserVocabularyItem expectations
      String wordType = type;
      if (type == VocabularyItem.typeVerb) {
        wordType = 'verb';
      } else if (type == VocabularyItem.typeNoun) {
        wordType = 'noun';
      } else if (type == VocabularyItem.typeAdverb) {
        wordType = 'adverb';
      }

      // Create UserVocabularyItem
      final vocabularyItem = UserVocabularyItem(
        id: const Uuid().v4(),
        userId: user.id,
        word: word,
        baseForm: word, // Could be improved with actual base form detection
        wordType: wordType,
        language: user.preferences.targetLanguage,
        translations: [translation],
        forms: conjugations?.values.map((v) => v.toString()).toList() ?? [],
        difficultyLevel: 1,
        masteryLevel: 0,
        timesSeen: 1,
        timesCorrect: 0,
        lastSeen: now,
        firstLearned: now,
        nextReview: now.add(const Duration(days: 1)), // Review tomorrow
        isFavorite: false,
        tags: [],
        exampleSentences: definition != null ? [definition] : [],
        sourceMessageId: conversationId,
      );

      await _userService!.saveVocabularyItem(vocabularyItem);
      debugPrint('Saved vocabulary item to user system: $word');
    } catch (e) {
      debugPrint('Error saving to user system: $e');
      // Don't rethrow - local storage should still work
    }
  }

  Future<void> removeItem(String word, String type) async {
    if (!_isInitialized) return;

    try {
      _items.removeWhere((item) =>
          item.word.toLowerCase() == word.toLowerCase() && item.type == type);
      await _saveItems();
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing item: $e');
    }
  }

  Future<void> markReviewed(String word, String type) async {
    if (!_isInitialized) return;

    try {
      final index = _items.indexWhere((item) =>
          item.word.toLowerCase() == word.toLowerCase() && item.type == type);

      if (index >= 0) {
        _items[index] = _items[index].copyWith(
          addedCount: _items[index].addedCount + 1,
          lastAdded: DateTime.now(),
        );
        await _saveItems();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking item as reviewed: $e');
    }
  }

  List<VocabularyItem> getItemsByType(String type) {
    if (!_isInitialized) return [];
    return _items.where((item) => item.type == type).toList();
  }

  VocabularyItem? getItem(String word, String type) {
    try {
      return _items.firstWhere(
        (item) =>
            item.word.toLowerCase() == word.toLowerCase() && item.type == type,
      );
    } catch (e) {
      return null;
    }
  }

  // Get user vocabulary items if logged in
  Future<List<UserVocabularyItem>> getUserVocabulary({String? language}) async {
    if (_userService == null || !_userService!.isLoggedIn) {
      return [];
    }

    try {
      return await _userService!.getUserVocabulary(language: language);
    } catch (e) {
      debugPrint('Error getting user vocabulary: $e');
      return [];
    }
  }
}
