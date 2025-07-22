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
  VoidCallback? _userAuthListener;

  bool get isInitialized => _isInitialized;
  List<VocabularyItem> get items => List.unmodifiable(_items);

  // Set the user service for integration
  void setUserService(UserService userService) {
    // If there's an old listener and an old user service, remove it
    if (_userService != null && _userAuthListener != null) {
      _userService!.removeListener(_userAuthListener!);
    }

    _userService = userService;

    // Define the listener function
    _userAuthListener = () {
      // When UserService notifies, it means auth state might have changed
      _handleUserChange();
    };

    // Add the listener to the new UserService
    _userService!.addListener(_userAuthListener!);

    // Immediately handle the current user state, especially if a user is already logged in
    // or if switching users while the app is running.
    if (_isInitialized) {
      // Ensure prefs is available if _handleUserChange needs it immediately
      _handleUserChange();
    }
  }

  Future<void> _handleUserChange() async {
    debugPrint(
        'VocabularyService: Detected user change. Clearing local data and reloading.');
    _items = []; // Clear in-memory items
    if (_isInitialized) {
      // Ensure _prefs is available
      try {
        await _prefs.remove(_storageKey); // Clear from SharedPreferences
      } catch (e) {
        debugPrint('Error removing SharedPreferences key \$_storageKey: \$e');
      }
    }

    // Reload items (which will fetch for the new user if logged in, or load empty if not)
    // _loadItems also calls _sortItems and should be followed by notifyListeners
    // if it doesn't call it internally on all paths.
    // Since init calls _loadItems and then notifyListeners, we'll follow that pattern.
    if (_isInitialized) {
      await _loadItems();
      notifyListeners(); // Notify UI to rebuild
    } else {
      // If not initialized, init() will call _loadItems eventually.
      // However, if setUserService is called before init, _isInitialized will be false.
      // This state should ideally be handled by ensuring init() is called after setUserService or
      // by ensuring _loadItems can be safely called even if _prefs is not ready (which it can't currently).
      // For now, we assume init() runs and sets _isInitialized true before user changes become critical.
    }
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
      debugPrint(
          '🚀 VocabularyService: Immediately saving "$word" to all storage systems...');

      // Save to local storage first (immediate persistence)
      await _saveToLocalStorage(word, type, translation,
          definition: definition,
          conjugations: conjugations,
          conversationId: conversationId);
      debugPrint('✅ VocabularyService: Saved "$word" to local storage');

      // Save to Supabase immediately (don't wait for anything else)
      if (_userService != null && _userService!.isLoggedIn) {
        try {
          await _saveToUserSystem(word, type, translation,
              definition: definition,
              conjugations: conjugations,
              conversationId: conversationId);
          debugPrint(
              '✅ VocabularyService: Saved "$word" to Supabase successfully');
        } catch (supabaseError) {
          debugPrint(
              '❌ VocabularyService: Failed to save "$word" to Supabase: $supabaseError');
          // Don't throw - local storage still worked
          // The item will be re-synced when user comes back online or reloads
        }
      } else {
        debugPrint(
            '⚠️ VocabularyService: User not logged in, saved "$word" locally only');
      }

      // Notify UI immediately (optimistic update)
      notifyListeners();
      debugPrint(
          '🎯 VocabularyService: "$word" added/updated successfully and UI notified');
    } catch (e) {
      debugPrint(
          '💥 VocabularyService: Critical error adding/updating item "$word": $e');
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

      // Extract verb forms from conjugations (for immediate saving)
      List<String> forms = [];
      if (conjugations != null && wordType == 'verb') {
        if (conjugations.containsKey('forms')) {
          // If conjugations already has 'forms' key (from UserVocabularyItem conversion)
          forms = List<String>.from(conjugations['forms']);
          debugPrint(
              '📝 VocabularyService: Extracted ${forms.length} verb forms for "$word"');
        } else {
          // If conjugations has individual form keys (from vocabulary processor)
          forms = conjugations.values.map((v) => v.toString()).toList();
          debugPrint(
              '📝 VocabularyService: Converted ${forms.length} conjugations to forms for "$word"');
        }
      }

      // Create UserVocabularyItem immediately (optimized for speed)
      final vocabularyItem = UserVocabularyItem(
        id: const Uuid().v4(),
        userId: user.id,
        word: word,
        baseForm: word, // Could be improved with actual base form detection
        wordType: wordType,
        language: user.preferences.targetLanguage,
        translations: [translation],
        forms: forms, // Preserve all verb conjugations
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

      debugPrint(
          '💾 VocabularyService: About to save "$word" (${wordType}) with ${vocabularyItem.forms.length} forms to Supabase...');

      // Save immediately to Supabase
      await _userService!.saveVocabularyItem(vocabularyItem);

      debugPrint(
          '✅ VocabularyService: Successfully saved "$word" to Supabase with all data preserved');
      if (vocabularyItem.forms.isNotEmpty) {
        debugPrint(
            '🔤 VocabularyService: Verb forms saved: ${vocabularyItem.forms.take(3).join(", ")}${vocabularyItem.forms.length > 3 ? "..." : ""}');
      }
    } catch (e) {
      debugPrint('❌ VocabularyService: Failed to save "$word" to Supabase: $e');
      debugPrint('❌ VocabularyService: Error type: ${e.runtimeType}');
      // Don't rethrow - local storage should still work
      rethrow; // Actually, let's rethrow so the caller can handle it
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

  @override
  void dispose() {
    if (_userService != null && _userAuthListener != null) {
      _userService!.removeListener(_userAuthListener!);
    }
    super.dispose();
  }
}
