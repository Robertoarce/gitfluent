import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_vocabulary.dart';
import 'database_service.dart';

class FirebaseDatabaseService implements DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _vocabularyCollection = 'user_vocabulary';
  static const String _vocabularyStatsCollection = 'vocabulary_stats';
  static const String _chatHistoryCollection = 'chat_history';

  @override
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return User.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  @override
  Future<User?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return User.fromFirestore(query.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by email: $e');
      return null;
    }
  }

  @override
  Future<String> createUser(User user) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(user.id);
      await docRef.set(user.toFirestore());
      return user.id;
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUser(User user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.id)
          .update(user.toFirestore());
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete user document
      batch.delete(_firestore.collection(_usersCollection).doc(userId));
      
      // Delete user's vocabulary
      final vocabularyQuery = await _firestore
          .collection(_vocabularyCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      
      for (final doc in vocabularyQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's vocabulary stats
      final statsQuery = await _firestore
          .collection(_vocabularyStatsCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      
      for (final doc in statsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's chat history
      final chatQuery = await _firestore
          .collection(_chatHistoryCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      
      for (final doc in chatQuery.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId, {String? language}) async {
    try {
      Query query = _firestore
          .collection(_vocabularyCollection)
          .where('user_id', isEqualTo: userId);
      
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserVocabularyItem.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting user vocabulary: $e');
      return [];
    }
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    try {
      await _firestore
          .collection(_vocabularyCollection)
          .doc(item.id)
          .set(item.toFirestore());
      return item;
    } catch (e) {
      debugPrint('Error saving vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateVocabularyItem(UserVocabularyItem item) async {
    try {
      await _firestore
          .collection(_vocabularyCollection)
          .doc(item.id)
          .update(item.toFirestore());
    } catch (e) {
      debugPrint('Error updating vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteVocabularyItem(String itemId) async {
    try {
      await _firestore.collection(_vocabularyCollection).doc(itemId).delete();
    } catch (e) {
      debugPrint('Error deleting vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId, {String? language}) async {
    try {
      Query query = _firestore
          .collection(_vocabularyCollection)
          .where('user_id', isEqualTo: userId)
          .where('next_review', isLessThanOrEqualTo: Timestamp.now());
      
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserVocabularyItem.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting vocabulary due for review: $e');
      return [];
    }
  }

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(String userId, String language) async {
    try {
      final doc = await _firestore
          .collection(_vocabularyStatsCollection)
          .doc('${userId}_$language')
          .get();
      
      if (doc.exists && doc.data() != null) {
        return UserVocabularyStats.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting vocabulary stats: $e');
      return null;
    }
  }

  @override
  Future<void> updateVocabularyStats(UserVocabularyStats stats) async {
    try {
      await _firestore
          .collection(_vocabularyStatsCollection)
          .doc('${stats.userId}_${stats.language}')
          .set(stats.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating vocabulary stats: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveChatMessage(String userId, Map<String, dynamic> message) async {
    try {
      await _firestore.collection(_chatHistoryCollection).add({
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
        ...message,
      });
    } catch (e) {
      debugPrint('Error saving chat message: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getChatHistory(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(_chatHistoryCollection)
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  @override
  Future<void> deleteChatHistory(String userId) async {
    try {
      final query = await _firestore
          .collection(_chatHistoryCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting chat history: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'is_premium': isPremium,
      });
    } catch (e) {
      debugPrint('Error updating premium status: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isPremiumUser(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['is_premium'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  @override
  Future<void> cleanup() async {
    // Firebase handles cleanup automatically
    // This method is here for interface compliance
  }

  // Firebase-specific helper methods
  Future<void> createIndexes() async {
    // Note: Firestore indexes should be created through the Firebase console
    // or using the Firebase CLI. This method is for documentation purposes.
    debugPrint('Firestore indexes should be created through Firebase console:');
    debugPrint('- users: email');
    debugPrint('- user_vocabulary: user_id, language, next_review');
    debugPrint('- vocabulary_stats: user_id');
    debugPrint('- chat_history: user_id, timestamp');
  }
} 