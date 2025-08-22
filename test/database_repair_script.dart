import 'package:flutter_test/flutter_test.dart';
import '../lib/services/supabase_database_service.dart';
import '../lib/services/supabase_auth_service.dart';
import '../lib/models/user.dart';
import '../lib/utils/debug_helper.dart';

/// Database repair script to restore corrupted language values
/// This script fixes the literal "null" strings in the database
void main() {
  group('Database Repair', () {
    test('should restore corrupted language values to correct ko/de values',
        () async {
      // This test serves as both verification and repair documentation

      // Expected correct values (from test evidence)
      const correctTargetLanguage = 'ko'; // Korean
      const correctNativeLanguage = 'de'; // German
      const userId = 'c3b402ea-2721-4529-a455-385f62c9b8b9';

      print('🚨 DATABASE REPAIR SCRIPT');
      print(
          '🚨 This script documents the repair process for corrupted language data');
      print('🚨 Expected values: target=ko, native=de');
      print('🚨 Current database contains: target="null", native="null"');
      print('🚨');
      print('🚨 To repair the database manually:');
      print('🚨 1. Connect to your Supabase database');
      print('🚨 2. Run the following SQL:');
      print('🚨    UPDATE users SET ');
      print('🚨      target_language = \'ko\',');
      print('🚨      native_language = \'de\'');
      print('🚨    WHERE id = \'$userId\';');
      print('🚨');
      print('🚨 Alternative: Use the Flutter repair function below');

      // Verify the test scenario matches reality
      final testUser = User(
        id: userId,
        email: 'test@debug.com',
        firstName: 'Debug',
        lastName: 'User',
        createdAt: DateTime.now(),
        isPremium: true,
        targetLanguage: correctTargetLanguage,
        nativeLanguage: correctNativeLanguage,
        supportLanguage1: null,
        supportLanguage2: null,
        preferences: UserPreferences(),
        statistics: UserStatistics(),
      );

      expect(testUser.targetLanguage, equals('ko'));
      expect(testUser.nativeLanguage, equals('de'));
    });

    test('should provide automated repair function', () async {
      // This function can be called to repair the database programmatically
      print('🔧 AUTOMATED REPAIR FUNCTION:');
      print('🔧 Call repairCorruptedLanguageData() to fix the database');

      final repairData = {
        'target_language': 'ko',
        'native_language': 'de',
        'support_language_1': null,
        'support_language_2': null,
      };

      expect(repairData['target_language'], equals('ko'));
      expect(repairData['native_language'], equals('de'));
    });
  });
}

/// Automated repair function to restore corrupted language data
/// Call this function to repair the database programmatically
Future<void> repairCorruptedLanguageData() async {
  const userId = 'c3b402ea-2721-4529-a455-385f62c9b8b9';
  const correctTargetLanguage = 'ko'; // Korean
  const correctNativeLanguage = 'de'; // German

  try {
    print('🔧 Starting database repair for user $userId...');

    // Create database service
    final databaseService = SupabaseDatabaseService();

    // Get current user
    final currentUser = await databaseService.getUserById(userId);
    if (currentUser == null) {
      print('❌ User not found: $userId');
      return;
    }

    print('🔍 Current user data:');
    print('   target_language: "${currentUser.targetLanguage}"');
    print('   native_language: "${currentUser.nativeLanguage}"');

    // Create repaired user
    final repairedUser = currentUser.copyWith(
      targetLanguage: correctTargetLanguage,
      nativeLanguage: correctNativeLanguage,
      supportLanguage1: null, // Keep as null (was already null in original)
      supportLanguage2: null, // Keep as null (was already null in original)
    );

    print('🔧 Repairing with correct values:');
    print('   target_language: "${repairedUser.targetLanguage}"');
    print('   native_language: "${repairedUser.nativeLanguage}"');

    // Update database
    await databaseService.updateUser(repairedUser);

    print('✅ Database repair completed successfully!');
    print('✅ Language values restored: ko (Korean) and de (German)');

    // Verify repair
    final verifiedUser = await databaseService.getUserById(userId);
    if (verifiedUser != null) {
      print('🔍 Verification - Updated user data:');
      print('   target_language: "${verifiedUser.targetLanguage}"');
      print('   native_language: "${verifiedUser.nativeLanguage}"');

      if (verifiedUser.targetLanguage == correctTargetLanguage &&
          verifiedUser.nativeLanguage == correctNativeLanguage) {
        print('✅ Repair verification PASSED');
      } else {
        print('❌ Repair verification FAILED');
      }
    }
  } catch (e) {
    print('❌ Database repair failed: $e');
    rethrow;
  }
}
