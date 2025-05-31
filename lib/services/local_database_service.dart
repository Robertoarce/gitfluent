import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_vocabulary.dart';
import 'database_service.dart';

/// Simple in-memory database service for testing
class LocalDatabaseService implements DatabaseService {
  // In-memory storage
  final Map<String, User> _users = {};
  final Map<String, List<UserVocabularyItem>> _userVocabulary = {};
  final Map<String, UserVocabularyStats> _vocabularyStats = {};
  final Map<String, List<Map<String, dynamic>>> _chatHistory = {};

  @override
  Future<User?> getUserById(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate network delay
    return _users[userId];
  }

  @override
  Future<User?> getUserByEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _users.values.where((user) => user.email == email).firstOrNull;
  }

  @override
  Future<String> createUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _users[user.id] = user;
    _userVocabulary[user.id] = [];
    _chatHistory[user.id] = [];
    debugPrint('LocalDB: Created user ${user.email} with ID ${user.id}');
    return user.id;
  }

  @override
  Future<void> updateUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _users[user.id] = user;
    debugPrint('LocalDB: Updated user ${user.email}');
  }

  @override
  Future<void> deleteUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _users.remove(userId);
    _userVocabulary.remove(userId);
    _vocabularyStats.removeWhere((key, value) => key.startsWith('${userId}_'));
    _chatHistory.remove(userId);
    debugPrint('LocalDB: Deleted user $userId');
  }

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId, {String? language}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final vocabulary = _userVocabulary[userId] ?? [];
    
    if (language != null) {
      return vocabulary.where((item) => item.language == language).toList();
    }
    return vocabulary;
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    await Future.delayed(const Duration(milliseconds: 150));
    
    if (!_userVocabulary.containsKey(item.userId)) {
      _userVocabulary[item.userId] = [];
    }
    
    // Remove existing item with same ID if it exists
    _userVocabulary[item.userId]!.removeWhere((existing) => existing.id == item.id);
    
    // Add the new/updated item
    _userVocabulary[item.userId]!.add(item);
    
    debugPrint('LocalDB: Saved vocabulary item ${item.word} for user ${item.userId}');
    return item;
  }

  @override
  Future<void> updateVocabularyItem(UserVocabularyItem item) async {
    await saveVocabularyItem(item); // Same implementation for local storage
  }

  @override
  Future<void> deleteVocabularyItem(String itemId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    for (final vocabulary in _userVocabulary.values) {
      vocabulary.removeWhere((item) => item.id == itemId);
    }
    debugPrint('LocalDB: Deleted vocabulary item $itemId');
  }

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId, {String? language}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final vocabulary = await getUserVocabulary(userId, language: language);
    final now = DateTime.now();
    
    return vocabulary.where((item) => 
      item.nextReview != null && now.isAfter(item.nextReview!)
    ).toList();
  }

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(String userId, String language) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _vocabularyStats['${userId}_$language'];
  }

  @override
  Future<void> updateVocabularyStats(UserVocabularyStats stats) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _vocabularyStats['${stats.userId}_${stats.language}'] = stats;
    debugPrint('LocalDB: Updated vocabulary stats for user ${stats.userId}, language ${stats.language}');
  }

  @override
  Future<void> saveChatMessage(String userId, Map<String, dynamic> message) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!_chatHistory.containsKey(userId)) {
      _chatHistory[userId] = [];
    }
    
    final messageWithTimestamp = {
      ...message,
      'timestamp': DateTime.now().toIso8601String(),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    _chatHistory[userId]!.add(messageWithTimestamp);
    debugPrint('LocalDB: Saved chat message for user $userId');
  }

  @override
  Future<List<Map<String, dynamic>>> getChatHistory(String userId, {int limit = 50}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final history = _chatHistory[userId] ?? [];
    
    // Sort by timestamp (newest first) and limit
    history.sort((a, b) => 
      DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp']))
    );
    
    return history.take(limit).toList();
  }

  @override
  Future<void> deleteChatHistory(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _chatHistory[userId] = [];
    debugPrint('LocalDB: Deleted chat history for user $userId');
  }

  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final user = _users[userId];
    if (user != null) {
      _users[userId] = user.copyWith(isPremium: isPremium);
      debugPrint('LocalDB: Updated premium status for user $userId to $isPremium');
    }
  }

  @override
  Future<bool> isPremiumUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _users[userId]?.isPremium ?? false;
  }

  @override
  Future<void> cleanup() async {
    // For local storage, we might want to persist data or clear it
    debugPrint('LocalDB: Cleanup called');
  }

  // Additional helper methods for testing
  void clearAllData() {
    _users.clear();
    _userVocabulary.clear();
    _vocabularyStats.clear();
    _chatHistory.clear();
    debugPrint('LocalDB: Cleared all data');
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'users_count': _users.length,
      'vocabulary_items_count': _userVocabulary.values.fold(0, (sum, list) => sum + list.length),
      'stats_count': _vocabularyStats.length,
      'chat_messages_count': _chatHistory.values.fold(0, (sum, list) => sum + list.length),
    };
  }

  void printDebugInfo() {
    final info = getDebugInfo();
    debugPrint('LocalDB Debug Info: $info');
  }
} 