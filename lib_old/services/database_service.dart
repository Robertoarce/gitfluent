import '../models/user.dart';
import '../models/user_vocabulary.dart';
import '../models/flashcard_session.dart';

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

  // Flashcard sessions
  Future<FlashcardSession> createFlashcardSession(FlashcardSession session);
  Future<FlashcardSession?> getFlashcardSession(String sessionId);
  Future<void> updateFlashcardSession(FlashcardSession session);
  Future<List<FlashcardSession>> getUserFlashcardSessions(String userId,
      {int limit = 50});
  Future<void> deleteFlashcardSession(String sessionId);

  // Flashcard session cards
  Future<FlashcardSessionCard> saveFlashcardSessionCard(
      FlashcardSessionCard card);
  Future<List<FlashcardSessionCard>> getSessionCards(String sessionId);
  Future<void> updateFlashcardSessionCard(FlashcardSessionCard card);
  Future<void> deleteFlashcardSessionCard(String cardId);

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
