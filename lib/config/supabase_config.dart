import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get projectUrl {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    debugPrint('SupabaseConfig: Using project URL: $url');
    return url;
  }

  static String get anonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    debugPrint('SupabaseConfig: Anon key length: ${key.length}');
    return key;
  }

  static String get serviceRoleKey {
    final key = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
    final keyLength = key.length;

    debugPrint('SupabaseConfig: Service role key length: $keyLength');
    if (keyLength == 0) {
      debugPrint(
          'WARNING: SUPABASE_SERVICE_ROLE_KEY is empty! This will prevent user creation.');
    } else if (keyLength < 10) {
      debugPrint(
          'WARNING: SUPABASE_SERVICE_ROLE_KEY seems too short! It may be invalid.');
    } else {
      // Just show a few characters to avoid logging the entire key
      final keyStart = key.substring(0, 5);
      final keyEnd = key.substring(key.length - 3);
      debugPrint('SupabaseConfig: Service role key: $keyStart...$keyEnd');
    }

    return key;
  }

  // Collection names
  static const String usersTable = 'users';
  static const String vocabularyTable = 'user_vocabulary';
  static const String vocabularyStatsTable = 'vocabulary_stats';
  static const String chatHistoryTable = 'chat_history';
  static const String flashcardSessionsTable = 'flashcard_sessions';
  static const String flashcardSessionCardsTable = 'flashcard_session_cards';

  // Storage buckets
  static const String profileImagesBucket = 'profile-images';

  // RLS Policies
  static const String usersPolicy = 'users_policy';
  static const String vocabularyPolicy = 'vocabulary_policy';
  static const String chatHistoryPolicy = 'chat_history_policy';
  static const String flashcardSessionsPolicy = 'flashcard_sessions_policy';
  static const String flashcardSessionCardsPolicy =
      'flashcard_session_cards_policy';

  // Debug Supabase configuration
  static void logConfigInfo() {
    debugPrint('SupabaseConfig: Project URL: $projectUrl');
    debugPrint(
        'SupabaseConfig: Tables: $usersTable, $vocabularyTable, $vocabularyStatsTable, $chatHistoryTable, $flashcardSessionsTable, $flashcardSessionCardsTable');
    debugPrint('SupabaseConfig: Anon key available: ${anonKey.isNotEmpty}');
    debugPrint(
        'SupabaseConfig: Service role key available: ${serviceRoleKey.isNotEmpty}');
  }
}
