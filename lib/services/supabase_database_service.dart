import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_vocabulary.dart';
import 'database_service.dart';

class SupabaseDatabaseService implements DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Table names
  static const String _usersTable = 'users';
  static const String _vocabularyTable = 'user_vocabulary';
  static const String _vocabularyStatsTable = 'vocabulary_stats';
  static const String _chatHistoryTable = 'chat_history';

  @override
  Future<User?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from(_usersTable)
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        return User.fromSupabase(response);
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
      final response = await _supabase
          .from(_usersTable)
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (response != null) {
        return User.fromSupabase(response);
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
      await _supabase
          .from(_usersTable)
          .insert(user.toSupabase());
      return user.id;
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUser(User user) async {
    try {
      await _supabase
          .from(_usersTable)
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
          .from(_vocabularyTable)
          .delete()
          .eq('user_id', userId);
      
      // Delete user's vocabulary stats
      await _supabase
          .from(_vocabularyStatsTable)
          .delete()
          .eq('user_id', userId);
      
      // Delete user's chat history
      await _supabase
          .from(_chatHistoryTable)
          .delete()
          .eq('user_id', userId);
      
      // Delete user
      await _supabase
          .from(_usersTable)
          .delete()
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  @override
  Future<List<UserVocabularyItem>> getUserVocabulary(String userId, {String? language}) async {
    try {
      var query = _supabase
          .from(_vocabularyTable)
          .select()
          .eq('user_id', userId);
      
      if (language != null) {
        query = query.eq('language', language);
      }
      
      final response = await query;
      return (response as List)
          .map((item) => UserVocabularyItem.fromSupabase(item))
          .toList();
    } catch (e) {
      debugPrint('Error getting user vocabulary: $e');
      return [];
    }
  }

  @override
  Future<UserVocabularyItem> saveVocabularyItem(UserVocabularyItem item) async {
    try {
      await _supabase
          .from(_vocabularyTable)
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
          .from(_vocabularyTable)
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
          .from(_vocabularyTable)
          .delete()
          .eq('id', itemId);
    } catch (e) {
      debugPrint('Error deleting vocabulary item: $e');
      rethrow;
    }
  }

  @override
  Future<List<UserVocabularyItem>> getVocabularyDueForReview(String userId, {String? language}) async {
    try {
      var query = _supabase
          .from(_vocabularyTable)
          .select()
          .eq('user_id', userId)
          .lte('next_review', DateTime.now().toIso8601String());
      
      if (language != null) {
        query = query.eq('language', language);
      }
      
      final response = await query;
      return (response as List)
          .map((item) => UserVocabularyItem.fromSupabase(item))
          .toList();
    } catch (e) {
      debugPrint('Error getting vocabulary due for review: $e');
      return [];
    }
  }

  @override
  Future<UserVocabularyStats?> getUserVocabularyStats(String userId, String language) async {
    try {
      final response = await _supabase
          .from(_vocabularyStatsTable)
          .select()
          .eq('user_id', userId)
          .eq('language', language)
          .maybeSingle();
      
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
          .from(_vocabularyStatsTable)
          .upsert(stats.toSupabase());
    } catch (e) {
      debugPrint('Error updating vocabulary stats: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveChatMessage(String userId, Map<String, dynamic> message) async {
    try {
      await _supabase.from(_chatHistoryTable).insert({
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
          .from(_chatHistoryTable)
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  @override
  Future<void> deleteChatHistory(String userId) async {
    try {
      await _supabase
          .from(_chatHistoryTable)
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
      await _supabase
          .from(_usersTable)
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
          .from(_usersTable)
          .select('is_premium')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        return response['is_premium'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  @override
  Future<void> cleanup() async {
    // Supabase handles cleanup automatically
    // This method is here for interface compliance
  }

  // Supabase-specific helper methods
  Future<void> createTables() async {
    // Note: Supabase tables should be created through the Supabase dashboard
    // or using SQL migrations. This method is for documentation purposes.
    debugPrint('Supabase tables should be created through dashboard or SQL:');
    debugPrint('''
    -- Users table
    CREATE TABLE users (
      id UUID PRIMARY KEY,
      email VARCHAR UNIQUE NOT NULL,
      password_hash VARCHAR,
      first_name VARCHAR NOT NULL,
      last_name VARCHAR NOT NULL,
      is_premium BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      last_login_at TIMESTAMP WITH TIME ZONE,
      profile_image_url VARCHAR,
      auth_provider VARCHAR DEFAULT 'email',
      provider_id VARCHAR,
      preferences JSONB DEFAULT '{}',
      statistics JSONB DEFAULT '{}'
    );

    -- User vocabulary table
    CREATE TABLE user_vocabulary (
      id UUID PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      word VARCHAR NOT NULL,
      base_form VARCHAR NOT NULL,
      word_type VARCHAR NOT NULL,
      language VARCHAR NOT NULL,
      translations TEXT[],
      forms TEXT[],
      difficulty_level INTEGER DEFAULT 1,
      mastery_level INTEGER DEFAULT 0,
      times_seen INTEGER DEFAULT 1,
      times_correct INTEGER DEFAULT 0,
      last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      first_learned TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      next_review TIMESTAMP WITH TIME ZONE,
      is_favorite BOOLEAN DEFAULT FALSE,
      tags TEXT[],
      example_sentences TEXT[],
      source_message_id VARCHAR
    );

    -- Vocabulary stats table
    CREATE TABLE vocabulary_stats (
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      language VARCHAR NOT NULL,
      total_words INTEGER DEFAULT 0,
      mastered_words INTEGER DEFAULT 0,
      learning_words INTEGER DEFAULT 0,
      new_words INTEGER DEFAULT 0,
      words_due_review INTEGER DEFAULT 0,
      average_mastery DECIMAL DEFAULT 0.0,
      last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      words_by_type JSONB DEFAULT '{}',
      PRIMARY KEY (user_id, language)
    );

    -- Chat history table
    CREATE TABLE chat_history (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      message_data JSONB NOT NULL
    );

    -- Indexes
    CREATE INDEX idx_users_email ON users(email);
    CREATE INDEX idx_vocabulary_user_language ON user_vocabulary(user_id, language);
    CREATE INDEX idx_vocabulary_review ON user_vocabulary(user_id, next_review);
    CREATE INDEX idx_chat_history_user_time ON chat_history(user_id, timestamp);
    ''');
  }

  // RLS (Row Level Security) policies
  Future<void> createRLSPolicies() async {
    debugPrint('Supabase RLS policies should be created:');
    debugPrint('''
    -- Enable RLS
    ALTER TABLE users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE user_vocabulary ENABLE ROW LEVEL SECURITY;
    ALTER TABLE vocabulary_stats ENABLE ROW LEVEL SECURITY;
    ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

    -- Users can only access their own data
    CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (auth.uid() = id);
    CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

    -- Vocabulary policies
    CREATE POLICY "Users can view own vocabulary" ON user_vocabulary FOR SELECT USING (auth.uid() = user_id);
    CREATE POLICY "Users can insert own vocabulary" ON user_vocabulary FOR INSERT WITH CHECK (auth.uid() = user_id);
    CREATE POLICY "Users can update own vocabulary" ON user_vocabulary FOR UPDATE USING (auth.uid() = user_id);
    CREATE POLICY "Users can delete own vocabulary" ON user_vocabulary FOR DELETE USING (auth.uid() = user_id);

    -- Stats policies
    CREATE POLICY "Users can view own stats" ON vocabulary_stats FOR SELECT USING (auth.uid() = user_id);
    CREATE POLICY "Users can upsert own stats" ON vocabulary_stats FOR INSERT WITH CHECK (auth.uid() = user_id);
    CREATE POLICY "Users can update own stats" ON vocabulary_stats FOR UPDATE USING (auth.uid() = user_id);

    -- Chat history policies (only for premium users)
    CREATE POLICY "Premium users can view own chat history" ON chat_history FOR SELECT 
      USING (auth.uid() = user_id AND EXISTS (
        SELECT 1 FROM users WHERE id = auth.uid() AND is_premium = true
      ));
    CREATE POLICY "Premium users can insert own chat history" ON chat_history FOR INSERT 
      WITH CHECK (auth.uid() = user_id AND EXISTS (
        SELECT 1 FROM users WHERE id = auth.uid() AND is_premium = true
      ));
    ''');
  }
} 