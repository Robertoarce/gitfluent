import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vocabulary_item.dart';

class VocabularyService extends ChangeNotifier {
  static const String _storageKey = 'vocabulary_items';
  late SharedPreferences _prefs;
  List<VocabularyItem> _items = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<VocabularyItem> get items => List.unmodifiable(_items);

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
        _items = decodedItems
            .map((item) => VocabularyItem.fromJson(item))
            .toList();
        _sortItems();
      }
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
      final String encodedItems = jsonEncode(_items.map((e) => e.toJson()).toList());
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
      final index = _items.indexWhere((item) => 
          item.word.toLowerCase() == word.toLowerCase() && 
          item.type == type);

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
          addedCount: shouldIncrement ? existingItem.addedCount + 1 : existingItem.addedCount,
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding/updating item: $e');
    }
  }

  Future<void> removeItem(String word, String type) async {
    if (!_isInitialized) return;

    try {
      _items.removeWhere((item) => 
          item.word.toLowerCase() == word.toLowerCase() && 
          item.type == type);
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
          item.word.toLowerCase() == word.toLowerCase() && 
          item.type == type);

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
        (item) => item.word.toLowerCase() == word.toLowerCase() && item.type == type,
      );
    } catch (e) {
      return null;
    }
  }
} 