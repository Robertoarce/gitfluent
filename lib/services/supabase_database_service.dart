import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart' as app_user;
import '../models/user_vocabulary.dart';
import 'database_service.dart';
import '../config/supabase_config.dart';
import 'logging_service.dart';

class SupabaseDatabaseService implements DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LoggingService _logger = LoggingService();

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
      _logger.log(LogCategory.database, 'Error getting user by ID: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error getting user by email: $e',
          isError: true);
      return null;
    }
  }

  @override
  Future<String> createUser(app_user.User user) async {
    try {
      _logger.log(LogCategory.database,
          '=========== DATABASE USER CREATION START ===========');
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Creating user in database, ID: ${user.id}, email: ${user.email}');

      // Convert user data for Supabase
      final userData = user.toSupabase();
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: User data prepared for Supabase');

      // Try with normal client first
      try {
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Attempting with normal client first');
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Using table: ${SupabaseConfig.usersTable}');

        final response = await _supabase
            .from(SupabaseConfig.usersTable)
            .upsert(userData, onConflict: 'id')
            .select()
            .single();

        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: User created successfully in database, response: ${response.toString()}');
        _logger.log(LogCategory.database,
            '=========== DATABASE USER CREATION END (SUCCESS) ===========');
        return response['id'];
      } catch (normalClientError) {
        // If the normal client fails, try with service role client
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Normal client failed: $normalClientError',
            isError: true);
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Error type: ${normalClientError.runtimeType}',
            isError: true);
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Trying with service role client');

        // Create a service role client that bypasses RLS
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Initializing service role client');
        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );

        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Service client initialized, attempting upsert');
        final response = await serviceClient
            .from(SupabaseConfig.usersTable)
            .upsert(userData, onConflict: 'id')
            .select()
            .single();

        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: User created successfully with service role, response: ${response.toString()}');
        _logger.log(LogCategory.database,
            '=========== DATABASE USER CREATION END (SUCCESS WITH SERVICE ROLE) ===========');
        return response['id'];
      }
    } catch (e) {
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Error creating user: $e',
          isError: true);
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Error type: ${e.runtimeType}',
          isError: true);

      // Try a simpler insert if upsert failed
      try {
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Attempting simple insert with service role as final fallback');
        // Create a service role client that bypasses RLS
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Initializing service role client for final attempt');
        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );

        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Service client initialized, attempting simple insert');
        await serviceClient
            .from(SupabaseConfig.usersTable)
            .insert(user.toSupabase());

        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Simple insert with service role succeeded');
        _logger.log(LogCategory.database,
            '=========== DATABASE USER CREATION END (SUCCESS WITH INSERT FALLBACK) ===========');
        return user.id;
      } catch (innerError) {
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: All attempts failed: $innerError',
            isError: true);
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Final error type: ${innerError.runtimeType}',
            isError: true);
        _logger.log(LogCategory.database,
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
      _logger.log(LogCategory.database, 'Error updating user: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error deleting user: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error saving vocabulary item: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error updating vocabulary item: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error deleting vocabulary item: $e',
          isError: true);
      rethrow;
    }
  }

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId,
      {String? language}) async {
    try {
      _logger.log(LogCategory.database,
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
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Found ${response.length} vocabulary items with regular client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      } catch (normalClientError) {
        // If the normal client fails, try with service role client
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Regular client failed getting vocabulary: $normalClientError',
            isError: true);
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Trying with service role client');

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
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Found ${response.length} vocabulary items with service role client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      }
    } catch (e) {
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Error getting user vocabulary: $e',
          isError: true);
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Error type: ${e.runtimeType}',
          isError: true);
      return [];
    }
  }

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId,
      {String? language}) async {
    try {
      _logger.log(LogCategory.database,
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
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Found ${response.length} vocabulary items due for review with regular client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      } catch (normalClientError) {
        // If the normal client fails, try with service role client
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Regular client failed getting vocabulary due for review: $normalClientError',
            isError: true);
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Trying with service role client');

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
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Found ${response.length} vocabulary items due for review with service role client');
        return response
            .map((item) => UserVocabularyItem.fromSupabase(item))
            .toList();
      }
    } catch (e) {
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Error getting vocabulary due for review: $e',
          isError: true);
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Error type: ${e.runtimeType}',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error getting vocabulary stats: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error updating vocabulary stats: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error saving chat message: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error getting chat history: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error deleting chat history: $e',
          isError: true);
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
      _logger.log(LogCategory.database, 'Error updating premium status: $e',
          isError: true);
      rethrow;
    }
  }

  @override
  Future<bool> isPremiumUser(String userId) async {
    try {
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Checking premium status for user: $userId');

      try {
        // Try with regular client first
        final response = await _supabase
            .from(SupabaseConfig.usersTable)
            .select('is_premium')
            .eq('id', userId)
            .single();

        final isPremium = response['is_premium'] ?? false;
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Premium status (regular client): $isPremium');
        return isPremium;
      } catch (normalClientError) {
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Regular client failed to check premium, using service role: $normalClientError',
            isError: true);

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
        _logger.log(LogCategory.database,
            'SupabaseDatabaseService: Premium status (service role client): $isPremium');
        return isPremium;
      }
    } catch (e) {
      _logger.log(LogCategory.database,
          'SupabaseDatabaseService: Error checking premium status: $e',
          isError: true);
      return false;
    }
  }

  @override
  Future<void> cleanup() async {
    // Supabase handles cleanup automatically
  }
}
