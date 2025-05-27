import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get projectUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  // Collection names
  static const String usersTable = 'users';
  static const String vocabularyTable = 'user_vocabulary';
  static const String vocabularyStatsTable = 'vocabulary_stats';
  static const String chatHistoryTable = 'chat_history';
  
  // Storage buckets
  static const String profileImagesBucket = 'profile_images';
  
  // RLS Policies
  static const String usersPolicy = 'users_policy';
  static const String vocabularyPolicy = 'vocabulary_policy';
  static const String chatHistoryPolicy = 'chat_history_policy';
} 