import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:llm_chat_app/services/logging_service.dart';

class SupabaseConfig {
  static final LoggingService _logger = LoggingService();

  static String get projectUrl {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    _logger.log(
        LogCategory.supabase, 'SupabaseConfig: Using project URL: $url');
    return url;
  }

  static String get anonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    _logger.log(
        LogCategory.supabase, 'SupabaseConfig: Anon key length: ${key.length}');
    return key;
  }

  static String get serviceRoleKey {
    final key = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
    final keyLength = key.length;

    _logger.log(LogCategory.supabase,
        'SupabaseConfig: Service role key length: $keyLength');
    if (keyLength == 0) {
      _logger.log(LogCategory.supabase,
          'WARNING: SUPABASE_SERVICE_ROLE_KEY is empty! This will prevent user creation.',
          isError: true);
    } else if (keyLength < 10) {
      _logger.log(LogCategory.supabase,
          'WARNING: SUPABASE_SERVICE_ROLE_KEY seems too short! It may be invalid.',
          isError: true);
    } else {
      // Just show a few characters to avoid logging the entire key
      final keyStart = key.substring(0, 5);
      final keyEnd = key.substring(key.length - 3);
      _logger.log(LogCategory.supabase,
          'SupabaseConfig: Service role key: $keyStart...$keyEnd');
    }

    return key;
  }

  // Collection names
  static const String usersTable = 'users';
  static const String vocabularyTable = 'user_vocabulary';
  static const String vocabularyStatsTable = 'vocabulary_stats';
  static const String chatHistoryTable = 'chat_history';

  // Storage buckets
  static const String profileImagesBucket = 'profile-images';

  // RLS Policies
  static const String usersPolicy = 'users_policy';
  static const String vocabularyPolicy = 'vocabulary_policy';
  static const String chatHistoryPolicy = 'chat_history_policy';

  // Debug Supabase configuration
  static void logConfigInfo() {
    _logger.log(
        LogCategory.supabase, 'SupabaseConfig: Project URL: $projectUrl');
    _logger.log(LogCategory.supabase,
        'SupabaseConfig: Tables: $usersTable, $vocabularyTable, $vocabularyStatsTable, $chatHistoryTable');
    _logger.log(LogCategory.supabase,
        'SupabaseConfig: Anon key available: ${anonKey.isNotEmpty}');
    _logger.log(LogCategory.supabase,
        'SupabaseConfig: Service role key available: ${serviceRoleKey.isNotEmpty}');
  }
}
