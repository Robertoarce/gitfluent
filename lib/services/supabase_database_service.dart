import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart' as app_user;
import '../models/user_vocabulary.dart';
import 'database_service.dart';
import '../config/supabase_config.dart';

class SupabaseDatabaseService implements DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('id', userId)
          .single();
      
      if (response != null) {
        return app_user.User.fromSupabase(response);
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
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .upsert(user.toSupabase(), onConflict: 'id')
          .select()
          .single();
      return response['id'];
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
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
      await _supabase
          .from(SupabaseConfig.usersTable)
          .delete()
          .eq('id', userId);
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
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId, {String? language}) async {
    try {
      var query = _supabase
          .from(SupabaseConfig.vocabularyTable)
          .select()
          .eq('user_id', userId);
      
      if (language != null) {
        query = query.eq('language', language);
      }
      
      final response = await query;
      return response.map((item) => UserVocabularyItem.fromSupabase(item)).toList();
    } catch (e) {
      debugPrint('Error getting user vocabulary: $e');
      return [];
    }
  }

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId, {String? language}) async {
    try {
      var query = _supabase
          .from(SupabaseConfig.vocabularyTable)
          .select()
          .eq('user_id', userId)
          .lte('next_review', DateTime.now().toIso8601String());
      
      if (language != null) {
        query = query.eq('language', language);
      }
      
      final response = await query;
      return response.map((item) => UserVocabularyItem.fromSupabase(item)).toList();
    } catch (e) {
      debugPrint('Error getting vocabulary due for review: $e');
      return [];
    }
  }

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(String userId, String language) async {
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
  Future<void> saveChatMessage(String userId, Map<String, dynamic> message) async {
    try {
      await _supabase
          .from(SupabaseConfig.chatHistoryTable)
          .insert({
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
  Future<List<Map<String, dynamic>>> getChatHistory(String userId, {int limit = 50}) async {
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
          .update({'is_premium': isPremium})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error updating premium status: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isPremiumUser(String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('is_premium')
          .eq('id', userId)
          .single();
      
      return response['is_premium'] ?? false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  @override
  Future<void> cleanup() async {
    // Supabase handles cleanup automatically
  }
} 