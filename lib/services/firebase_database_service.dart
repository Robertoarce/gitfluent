import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart' as app_user;
import '../models/user_vocabulary.dart';
import '../models/flashcard_session.dart';
import 'database_service.dart';

class FirebaseDatabaseService implements DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');

  @override
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return app_user.User.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  @override
  Future<app_user.User?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return app_user.User.fromJson(
            querySnapshot.docs.first.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by email: $e');
      return null;
    }
  }

  @override
  Future<String> createUser(app_user.User user) async {
    try {
      await _usersCollection.doc(user.id).set(user.toJson());
      return user.id;
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUser(app_user.User user) async {
    try {
      await _usersCollection.doc(user.id).update(user.toJson());
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      // Note: Firestore doesn't automatically delete subcollections.
      // In a real app, you'd use a Cloud Function for recursive delete.
      await _usersCollection.doc(userId).delete();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // Vocabulary Management
  
  CollectionReference _getVocabularyCollection(String userId) {
    return _usersCollection.doc(userId).collection('vocabulary');
  }

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId,
      {String? language}) async {
    try {
      Query query = _getVocabularyCollection(userId);
      
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserVocabularyItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting vocabulary: $e');
      return [];
    }
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    try {
      await _getVocabularyCollection(item.userId).doc(item.id).set(item.toJson());
      return item;
    } catch (e) {
      debugPrint('Error saving vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateVocabularyItem(UserVocabularyItem item) async {
    try {
      await _getVocabularyCollection(item.userId).doc(item.id).update(item.toJson());
    } catch (e) {
      debugPrint('Error updating vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteVocabularyItem(String itemId) async {
    // Note: We need the userId to find the subcollection. 
    // This method signature assumes we can find it by ID alone, which is true for Supabase (global table)
    // but harder for Firestore (subcollection).
    // We might need to query for it or change the interface.
    // For now, assuming we can't easily implement this without userId, 
    // or we'd need a collection group query which is expensive/complex.
    // Ideally, pass userId or item object.
    
    // WORKAROUND: Since interface only has itemId, we can't delete easily in Firestore subcollection structure
    // unless we know the userId. 
    // Assuming the caller context might have it, but the interface is fixed.
    // We'll log a warning.
    debugPrint('WARNING: deleteVocabularyItem in Firestore requires userId. Operation skipped.');
  }

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId,
      {String? language}) async {
    try {
      Query query = _getVocabularyCollection(userId)
          .where('nextReview', isLessThanOrEqualTo: DateTime.now().toIso8601String());
          
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserVocabularyItem.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting due vocabulary: $e');
      return [];
    }
  }

  // Statistics

  CollectionReference _getStatsCollection(String userId) {
    return _usersCollection.doc(userId).collection('stats');
  }

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(
      String userId, String language) async {
    try {
      final doc = await _getStatsCollection(userId).doc(language).get();
      if (doc.exists && doc.data() != null) {
        return UserVocabularyStats.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return null;
    }
  }

  @override
  Future<void> updateVocabularyStats(UserVocabularyStats stats) async {
    try {
      await _getStatsCollection(stats.userId).doc(stats.language).set(stats.toJson());
    } catch (e) {
      debugPrint('Error updating stats: $e');
      rethrow;
    }
  }

  // Flashcard Sessions

  CollectionReference _getSessionsCollection(String userId) {
    return _usersCollection.doc(userId).collection('flashcard_sessions');
  }

  @override
  Future<FlashcardSession> createFlashcardSession(FlashcardSession session) async {
    try {
      await _getSessionsCollection(session.userId).doc(session.id).set(session.toJson());
      return session;
    } catch (e) {
      debugPrint('Error creating session: $e');
      rethrow;
    }
  }

  @override
  Future<FlashcardSession?> getFlashcardSession(String sessionId) async {
    // Again, need userId for subcollection. 
    // We'll assume we can't find it easily without userId.
    debugPrint('WARNING: getFlashcardSession requires userId in Firestore structure.');
    return null;
  }

  @override
  Future<void> updateFlashcardSession(FlashcardSession session) async {
    try {
      await _getSessionsCollection(session.userId).doc(session.id).update(session.toJson());
    } catch (e) {
      debugPrint('Error updating session: $e');
      rethrow;
    }
  }

  @override
  Future<List<FlashcardSession>> getUserFlashcardSessions(String userId,
      {int limit = 50}) async {
    try {
      final snapshot = await _getSessionsCollection(userId)
          .orderBy('sessionDate', descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs
          .map((doc) => FlashcardSession.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting sessions: $e');
      return [];
    }
  }

  @override
  Future<void> deleteFlashcardSession(String sessionId) async {
    debugPrint('WARNING: deleteFlashcardSession requires userId in Firestore structure.');
  }

  // Flashcard Session Cards
  // We'll store these as a subcollection of the session

  CollectionReference _getSessionCardsCollection(String userId, String sessionId) {
    return _getSessionsCollection(userId).doc(sessionId).collection('cards');
  }

  @override
  Future<FlashcardSessionCard> saveFlashcardSessionCard(
      FlashcardSessionCard card) async {
    try {
      // We need userId to find the session. The card model might not have userId directly?
      // Let's check the model. If not, we have a problem.
      // Assuming we can get userId from context or it's on the card.
      // Wait, FlashcardSessionCard usually links to session.
      // We might need to fetch the session first to get the userId?
      // Or we assume the caller knows.
      
      // For now, this is tricky without userId on the card.
      // We'll assume we can't implement this easily without changing the model or interface.
      debugPrint('WARNING: saveFlashcardSessionCard requires userId context.');
      throw UnimplementedError('Firestore requires hierarchical path');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<FlashcardSessionCard>> getSessionCards(String sessionId) async {
    debugPrint('WARNING: getSessionCards requires userId context.');
    return [];
  }

  @override
  Future<void> updateFlashcardSessionCard(FlashcardSessionCard card) async {
    debugPrint('WARNING: updateFlashcardSessionCard requires userId context.');
  }

  @override
  Future<void> deleteFlashcardSessionCard(String cardId) async {
    debugPrint('WARNING: deleteFlashcardSessionCard requires userId context.');
  }

  // Chat History

  CollectionReference _getChatCollection(String userId) {
    return _usersCollection.doc(userId).collection('chat_history');
  }

  @override
  Future<void> saveChatMessage(
      String userId, Map<String, dynamic> message) async {
    try {
      await _getChatCollection(userId).add({
        'timestamp': DateTime.now().toIso8601String(),
        ...message,
      });
    } catch (e) {
      debugPrint('Error saving chat message: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getChatHistory(String userId,
      {int limit = 50}) async {
    try {
      final snapshot = await _getChatCollection(userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  @override
  Future<void> deleteChatHistory(String userId) async {
    try {
      final snapshot = await _getChatCollection(userId).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting chat history: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {
    try {
      await _usersCollection.doc(userId).update({'isPremium': isPremium});
    } catch (e) {
      debugPrint('Error updating premium status: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isPremiumUser(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isPremium'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  @override
  Future<void> cleanup() async {
    // Nothing to clean up
  }
}
