import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart' as app_user;
import '../models/user_vocabulary.dart';
import '../models/flashcard_session.dart';
import 'database_service.dart';
import '../config/supabase_config.dart';

class SupabaseDatabaseService implements DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<app_user.User?> getUserById(String userId) async {
    try {
      debugPrint(
          '🚀 SupabaseDatabaseService.getUserById: CALLED for userId: $userId');
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('id', userId)
          .single();

      if (response != null) {
        // 🔍 DIRECT DATABASE DUMP - Let's see what's ACTUALLY stored
        debugPrint('🔍 RAW DATABASE DUMP for user $userId:');
        debugPrint(
            '   target_language: "${response['target_language']}" (type: ${response['target_language']?.runtimeType})');
        debugPrint(
            '   native_language: "${response['native_language']}" (type: ${response['native_language']?.runtimeType})');
        debugPrint(
            '   support_language_1: "${response['support_language_1']}" (type: ${response['support_language_1']?.runtimeType})');
        debugPrint(
            '   support_language_2: "${response['support_language_2']}" (type: ${response['support_language_2']?.runtimeType})');
        debugPrint('🔍 RAW RESPONSE: ${response.toString()}');

        debugPrint(
            '🚀 SupabaseDatabaseService: About to call User.fromSupabase...');
        final user = app_user.User.fromSupabase(response);
        debugPrint(
            '🚀 SupabaseDatabaseService: User.fromSupabase completed - target: "${user.targetLanguage}", native: "${user.nativeLanguage}"');
        return user;
      }
      debugPrint(
          '🚀 SupabaseDatabaseService: No response from database for user $userId');
      return null;
    } catch (e) {
      debugPrint(
          '🚨 SupabaseDatabaseService.getUserById: Error for user $userId: $e');
      return null;
    }
  }

  @override
  Future<app_user.User?> getUserByEmail(String email) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('email', email)
          .single();

      if (response != null) {
        return app_user.User.fromSupabase(response);
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
      debugPrint('=========== DATABASE USER CREATION START ===========');
      debugPrint(
          'SupabaseDatabaseService: Creating user in database, ID: ${user.id}, email: ${user.email}');

      // Convert user data for Supabase
      final userData = user.toSupabase();
      debugPrint('SupabaseDatabaseService: User data prepared for Supabase');

      // Try with normal client first
      try {
        debugPrint(
            'SupabaseDatabaseService: Attempting with normal client first');
        debugPrint(
            'SupabaseDatabaseService: Using table: ${SupabaseConfig.usersTable}');

        final response = await _supabase
            .from(SupabaseConfig.usersTable)
            .upsert(userData, onConflict: 'id')
            .select()
            .single();

        debugPrint(
            'SupabaseDatabaseService: User created successfully in database, response: ${response.toString()}');
        debugPrint(
            '=========== DATABASE USER CREATION END (SUCCESS) ===========');
        return response['id'];
      } catch (normalClientError) {
        // If the normal client fails, try with service role client
        debugPrint(
            'SupabaseDatabaseService: Normal client failed: $normalClientError');
        debugPrint(
            'SupabaseDatabaseService: Error type: ${normalClientError.runtimeType}');
        debugPrint('SupabaseDatabaseService: Trying with service role client');

        // Create a service role client that bypasses RLS
        debugPrint('SupabaseDatabaseService: Initializing service role client');
        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );

        debugPrint(
            'SupabaseDatabaseService: Service client initialized, attempting upsert');
        final response = await serviceClient
            .from(SupabaseConfig.usersTable)
            .upsert(userData, onConflict: 'id')
            .select()
            .single();

        debugPrint(
            'SupabaseDatabaseService: User created successfully with service role, response: ${response.toString()}');
        debugPrint(
            '=========== DATABASE USER CREATION END (SUCCESS WITH SERVICE ROLE) ===========');
        return response['id'];
      }
    } catch (e) {
      debugPrint('SupabaseDatabaseService: Error creating user: $e');
      debugPrint('SupabaseDatabaseService: Error type: ${e.runtimeType}');

      // Try a simpler insert if upsert failed
      try {
        debugPrint(
            'SupabaseDatabaseService: Attempting simple insert with service role as final fallback');
        // Create a service role client that bypasses RLS
        debugPrint(
            'SupabaseDatabaseService: Initializing service role client for final attempt');
        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );

        debugPrint(
            'SupabaseDatabaseService: Service client initialized, attempting simple insert');
        await serviceClient
            .from(SupabaseConfig.usersTable)
            .insert(user.toSupabase());

        debugPrint(
            'SupabaseDatabaseService: Simple insert with service role succeeded');
        debugPrint(
            '=========== DATABASE USER CREATION END (SUCCESS WITH INSERT FALLBACK) ===========');
        return user.id;
      } catch (innerError) {
        debugPrint('SupabaseDatabaseService: All attempts failed: $innerError');
        debugPrint(
            'SupabaseDatabaseService: Final error type: ${innerError.runtimeType}');
        debugPrint(
            '=========== DATABASE USER CREATION END (ALL ATTEMPTS FAILED) ===========');
        rethrow;
      }
    }
  }

  @override
  Future<void> updateUser(app_user.User user) async {
    try {
      await _supabase
          .from(SupabaseConfig.usersTable)
          .update(user.toSupabase())
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      // Delete user's vocabulary
      await _supabase
          .from(SupabaseConfig.vocabularyTable)
          .delete()
          .eq('user_id', userId);

      // Delete user's vocabulary stats
      await _supabase
          .from(SupabaseConfig.vocabularyStatsTable)
          .delete()
          .eq('user_id', userId);

      // Delete user's chat history
      await _supabase
          .from(SupabaseConfig.chatHistoryTable)
          .delete()
          .eq('user_id', userId);

      // Delete user
      await _supabase.from(SupabaseConfig.usersTable).delete().eq('id', userId);
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    try {
      await _supabase
          .from(SupabaseConfig.vocabularyTable)
          .upsert(item.toSupabase());
      return item;
    } catch (e) {
      debugPrint('Error saving vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateVocabularyItem(UserVocabularyItem item) async {
    try {
      await _supabase
          .from(SupabaseConfig.vocabularyTable)
          .update(item.toSupabase())
          .eq('id', item.id);
    } catch (e) {
      debugPrint('Error updating vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteVocabularyItem(String itemId) async {
    try {
      await _supabase
          .from(SupabaseConfig.vocabularyTable)
          .delete()
          .eq('id', itemId);
    } catch (e) {
      debugPrint('Error deleting vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId,
      {String? language}) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Getting vocabulary for user: $userId, language: ${language ?? "all"}');

      try {
        // Try with regular client first
        var query = _supabase
            .from(SupabaseConfig.vocabularyTable)
            .select()
            .eq('user_id', userId);

        if (language != null) {
          query = query.eq('language', language);
        }

        final response = await query;
        debugPrint(
            'SupabaseDatabaseService: Found ${response.length} vocabulary items with regular client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      } catch (normalClientError) {
        // If the normal client fails, try with service role client
        debugPrint(
            'SupabaseDatabaseService: Regular client failed getting vocabulary: $normalClientError');
        debugPrint('SupabaseDatabaseService: Trying with service role client');

        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );

        var query = serviceClient
            .from(SupabaseConfig.vocabularyTable)
            .select()
            .eq('user_id', userId);

        if (language != null) {
          query = query.eq('language', language);
        }

        final response = await query;
        debugPrint(
            'SupabaseDatabaseService: Found ${response.length} vocabulary items with service role client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      }
    } catch (e) {
      debugPrint('SupabaseDatabaseService: Error getting user vocabulary: $e');
      debugPrint('SupabaseDatabaseService: Error type: ${e.runtimeType}');
      return [];
    }
  }

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId,
      {String? language}) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Getting vocabulary due for review for user: $userId, language: ${language ?? "all"}');

      try {
        // Try with regular client first
        var query = _supabase
            .from(SupabaseConfig.vocabularyTable)
            .select()
            .eq('user_id', userId)
            .lte('next_review', DateTime.now().toIso8601String());

        if (language != null) {
          query = query.eq('language', language);
        }

        final response = await query;
        debugPrint(
            'SupabaseDatabaseService: Found ${response.length} vocabulary items due for review with regular client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      } catch (normalClientError) {
        // If the normal client fails, try with service role client
        debugPrint(
            'SupabaseDatabaseService: Regular client failed getting vocabulary due for review: $normalClientError');
        debugPrint('SupabaseDatabaseService: Trying with service role client');

        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );

        var query = serviceClient
            .from(SupabaseConfig.vocabularyTable)
            .select()
            .eq('user_id', userId)
            .lte('next_review', DateTime.now().toIso8601String());

        if (language != null) {
          query = query.eq('language', language);
        }

        final response = await query;
        debugPrint(
            'SupabaseDatabaseService: Found ${response.length} vocabulary items due for review with service role client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      }
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error getting vocabulary due for review: $e');
      debugPrint('SupabaseDatabaseService: Error type: ${e.runtimeType}');
      return [];
    }
  }

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(
      String userId, String language) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.vocabularyStatsTable)
          .select()
          .eq('user_id', userId)
          .eq('language', language)
          .single();

      if (response != null) {
        return UserVocabularyStats.fromSupabase(response);
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
      await _supabase
          .from(SupabaseConfig.vocabularyStatsTable)
          .upsert(stats.toSupabase());
    } catch (e) {
      debugPrint('Error updating vocabulary stats: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveChatMessage(
      String userId, Map<String, dynamic> message) async {
    try {
      await _supabase.from(SupabaseConfig.chatHistoryTable).insert({
        'user_id': userId,
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
      final response = await _supabase
          .from(SupabaseConfig.chatHistoryTable)
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(limit);

      return response;
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  @override
  Future<void> deleteChatHistory(String userId) async {
    try {
      await _supabase
          .from(SupabaseConfig.chatHistoryTable)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting chat history: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {
    try {
      // Use the service role client for premium updates
      final serviceClient = SupabaseClient(
        SupabaseConfig.projectUrl,
        SupabaseConfig.serviceRoleKey,
      );
      await serviceClient
          .from(SupabaseConfig.usersTable)
          .update({'is_premium': isPremium}).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating premium status: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isPremiumUser(String userId) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Checking premium status for user: $userId');

      try {
        // Try with regular client first
        final response = await _supabase
            .from(SupabaseConfig.usersTable)
            .select('is_premium')
            .eq('id', userId)
            .single();

        final isPremium = response['is_premium'] ?? false;
        debugPrint(
            'SupabaseDatabaseService: Premium status (regular client): $isPremium');
        return isPremium;
      } catch (normalClientError) {
        debugPrint(
            'SupabaseDatabaseService: Regular client failed to check premium, using service role: $normalClientError');

        // Use service role client as fallback
        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );

        final response = await serviceClient
            .from(SupabaseConfig.usersTable)
            .select('is_premium')
            .eq('id', userId)
            .single();

        final isPremium = response['is_premium'] ?? false;
        debugPrint(
            'SupabaseDatabaseService: Premium status (service role client): $isPremium');
        return isPremium;
      }
    } catch (e) {
      debugPrint('SupabaseDatabaseService: Error checking premium status: $e');
      return false;
    }
  }

  // Flashcard session operations
  @override
  Future<FlashcardSession> createFlashcardSession(
      FlashcardSession session) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Creating flashcard session for user: ${session.userId}');

      final response = await _supabase
          .from(SupabaseConfig.flashcardSessionsTable)
          .insert(session.toSupabase())
          .select()
          .single();

      debugPrint(
          'SupabaseDatabaseService: Flashcard session created successfully');
      return FlashcardSession.fromSupabase(response);
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error creating flashcard session: $e');
      rethrow;
    }
  }

  @override
  Future<FlashcardSession?> getFlashcardSession(String sessionId) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Getting flashcard session: $sessionId');

      final response = await _supabase
          .from(SupabaseConfig.flashcardSessionsTable)
          .select()
          .eq('id', sessionId)
          .single();

      if (response != null) {
        debugPrint('SupabaseDatabaseService: Flashcard session found');
        return FlashcardSession.fromSupabase(response);
      }
      return null;
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error getting flashcard session: $e');
      return null;
    }
  }

  @override
  Future<void> updateFlashcardSession(FlashcardSession session) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Updating flashcard session: ${session.id}');

      await _supabase
          .from(SupabaseConfig.flashcardSessionsTable)
          .update(session.toSupabase())
          .eq('id', session.id);

      debugPrint(
          'SupabaseDatabaseService: Flashcard session updated successfully');
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error updating flashcard session: $e');
      rethrow;
    }
  }

  @override
  Future<List<FlashcardSession>> getUserFlashcardSessions(String userId,
      {int limit = 50}) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Getting flashcard sessions for user: $userId (limit: $limit)');

      final response = await _supabase
          .from(SupabaseConfig.flashcardSessionsTable)
          .select()
          .eq('user_id', userId)
          .order('session_date', ascending: false)
          .limit(limit);

      debugPrint(
          'SupabaseDatabaseService: Found ${response.length} flashcard sessions');
      return response
          .map((item) => FlashcardSession.fromSupabase(item))
          .toList();
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error getting user flashcard sessions: $e');
      return [];
    }
  }

  @override
  Future<void> deleteFlashcardSession(String sessionId) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Deleting flashcard session: $sessionId');

      // Delete session cards first (cascade delete should handle this, but explicit delete for safety)
      await _supabase
          .from(SupabaseConfig.flashcardSessionCardsTable)
          .delete()
          .eq('session_id', sessionId);

      // Delete session
      await _supabase
          .from(SupabaseConfig.flashcardSessionsTable)
          .delete()
          .eq('id', sessionId);

      debugPrint(
          'SupabaseDatabaseService: Flashcard session deleted successfully');
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error deleting flashcard session: $e');
      rethrow;
    }
  }

  // Flashcard session card operations
  @override
  Future<FlashcardSessionCard> saveFlashcardSessionCard(
      FlashcardSessionCard card) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Saving flashcard session card for session: ${card.sessionId}');

      final response = await _supabase
          .from(SupabaseConfig.flashcardSessionCardsTable)
          .insert(card.toSupabase())
          .select()
          .single();

      debugPrint(
          'SupabaseDatabaseService: Flashcard session card saved successfully');
      return FlashcardSessionCard.fromSupabase(response);
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error saving flashcard session card: $e');
      rethrow;
    }
  }

  @override
  Future<List<FlashcardSessionCard>> getSessionCards(String sessionId) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Getting session cards for session: $sessionId');

      final response = await _supabase
          .from(SupabaseConfig.flashcardSessionCardsTable)
          .select()
          .eq('session_id', sessionId)
          .order('shown_at', ascending: true);

      debugPrint(
          'SupabaseDatabaseService: Found ${response.length} session cards');
      return response
          .map((item) => FlashcardSessionCard.fromSupabase(item))
          .toList();
    } catch (e) {
      debugPrint('SupabaseDatabaseService: Error getting session cards: $e');
      return [];
    }
  }

  @override
  Future<void> updateFlashcardSessionCard(FlashcardSessionCard card) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Updating flashcard session card: ${card.id}');

      await _supabase
          .from(SupabaseConfig.flashcardSessionCardsTable)
          .update(card.toSupabase())
          .eq('id', card.id);

      debugPrint(
          'SupabaseDatabaseService: Flashcard session card updated successfully');
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error updating flashcard session card: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteFlashcardSessionCard(String cardId) async {
    try {
      debugPrint(
          'SupabaseDatabaseService: Deleting flashcard session card: $cardId');

      await _supabase
          .from(SupabaseConfig.flashcardSessionCardsTable)
          .delete()
          .eq('id', cardId);

      debugPrint(
          'SupabaseDatabaseService: Flashcard session card deleted successfully');
    } catch (e) {
      debugPrint(
          'SupabaseDatabaseService: Error deleting flashcard session card: $e');
      rethrow;
    }
  }

  @override
  Future<void> cleanup() async {
    // Supabase handles cleanup automatically
  }
}
