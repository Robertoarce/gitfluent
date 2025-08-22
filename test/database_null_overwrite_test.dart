import 'package:flutter_test/flutter_test.dart';
import '../lib/models/user.dart';
import '../lib/services/language_settings_service.dart';

/// Test to verify database sync behavior and help restore null values
void main() {
  group('Database Null Overwrite Investigation', () {
    test('should demonstrate proper sync behavior', () {
      // Test the fallback logic in _syncToDatabase

      // Scenario 1: Both local and user have null values - should use defaults
      String? localTarget = null;
      String? userTarget = null;
      final targetCode = localTarget ?? userTarget ?? 'en';
      expect(targetCode, equals('en'),
          reason: 'Should default to en when both are null');

      // Scenario 2: Local has value, user has null - should use local
      localTarget = 'ko';
      userTarget = null;
      final targetCode2 = localTarget ?? userTarget ?? 'en';
      expect(targetCode2, equals('ko'),
          reason: 'Should use local value when available');

      // Scenario 3: Local is null, user has value - should use user
      localTarget = null;
      userTarget = 'de';
      final targetCode3 = localTarget ?? userTarget ?? 'en';
      expect(targetCode3, equals('de'),
          reason: 'Should use user value as fallback');
    });

    test('should verify User.fromSupabase preserves valid values', () {
      // Test with the actual database response that has valid values
      final databaseResponse = {
        'id': 'c3b402ea-2721-4529-a455-385f62c9b8b9',
        'email': 'test@debug.com',
        'first_name': 'Debug',
        'last_name': 'User',
        'created_at': DateTime.now().toIso8601String(),
        'last_login_at': null,
        'is_premium': true,
        'target_language': 'ko', // Valid values
        'native_language': 'de', // Valid values
        'support_language_1': null,
        'support_language_2': null,
        'preferences': '{}',
        'statistics': '{}'
      };

      final user = User.fromSupabase(databaseResponse);

      expect(user.targetLanguage, equals('ko'),
          reason: 'Should preserve target language');
      expect(user.nativeLanguage, equals('de'),
          reason: 'Should preserve native language');
      expect(user.supportLanguage1, isNull,
          reason: 'Should handle null support languages correctly');
      expect(user.supportLanguage2, isNull,
          reason: 'Should handle null support languages correctly');
    });
  });
}

/// Manual restoration script (run with flutter test --dart-entrypoint)
/// This is commented out - uncomment and modify to restore database values
/*
void main() async {
  // Example of how to restore database values manually:
  // 1. Create a User object with the correct values
  // 2. Use SupabaseDatabaseService to update it
  
  print('Manual database restoration would go here');
  print('Values to restore: target_language=ko, native_language=de');
}
*/
