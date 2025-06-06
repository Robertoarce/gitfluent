import '../models/user.dart';
import '../models/user_vocabulary.dart';

/// Abstract database service interface
abstract class DatabaseService {
  // User management
  Future<User?> getUserById(String userId);
  Future<User?> getUserByEmail(String email);
  Future<String> createUser(User user);
  Future<void> updateUser(User user);
  Future<void> deleteUser(String userId);

  // Vocabulary management
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId,
      {String? language});
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item);
  Future<void> updateVocabularyItem(UserVocabularyItem item);
  Future<void> deleteVocabularyItem(String itemId);
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId,
      {String? language});

  // Statistics
  Future<UserVocabularyStats?> getUserVocabularyStats(
      String userId, String language);
  Future<void> updateVocabularyStats(UserVocabularyStats stats);

  // Chat history (for premium users)
  Future<void> saveChatMessage(String userId, Map<String, dynamic> message);
  Future<List<Map<String, dynamic>>> getChatHistory(String userId,
      {int limit = 50});
  Future<void> deleteChatHistory(String userId);

  // Premium features
  Future<void> updatePremiumStatus(String userId, bool isPremium);
  Future<bool> isPremiumUser(String userId);

  // Cleanup and maintenance
  Future<void> cleanup();
}
