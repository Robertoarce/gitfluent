import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/services/supabase_database_service.dart';
import '../lib/models/user.dart';
import '../lib/config/supabase_config.dart';
import '../lib/utils/debug_helper.dart';

/// EXECUTABLE DATABASE REPAIR SCRIPT
/// Run this with: flutter test test/execute_database_repair.dart
/// This will actually repair the corrupted database values
void main() async {
  // Setup test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database Repair Execution', () {
    setUpAll(() async {
      // Initialize debug helper
      await DebugHelper.initialize();

      // Load environment variables
      try {
        await dotenv.load(fileName: ".env");
        print('✅ Environment loaded successfully');
      } catch (e) {
        print('❌ Error loading .env file: $e');
        return;
      }

      // Initialize Supabase
      try {
        print('🔧 Initializing Supabase...');
        await Supabase.initialize(
          url: SupabaseConfig.projectUrl,
          anonKey: SupabaseConfig.anonKey,
        );
        print('✅ Supabase initialized successfully');
      } catch (e) {
        print('❌ Error initializing Supabase: $e');
        return;
      }
    });

    test('should repair corrupted database values', () async {
      print('🔧 EXECUTING DATABASE REPAIR...');
      print(
          '🔧 This will restore corrupted language values in your Supabase database');
      print('🔧');

      await repairCorruptedLanguageData();

      print('🔧');
      print('🔧 Database repair execution completed!');
      print(
          '🔧 Your app should now load the correct language settings: ko (Korean) and de (German)');
    });
  });
}

/// Repair function that actually fixes the database
Future<void> repairCorruptedLanguageData() async {
  const userId = 'c3b402ea-2721-4529-a455-385f62c9b8b9';
  const correctTargetLanguage = 'ko'; // Korean
  const correctNativeLanguage = 'de'; // German

  try {
    print('🔧 Starting database repair for user $userId...');

    // Create database service
    final databaseService = SupabaseDatabaseService();

    // Get current user to see corruption
    final currentUser = await databaseService.getUserById(userId);
    if (currentUser == null) {
      print('❌ User not found: $userId');
      print('❌ Make sure your Supabase connection is working');
      return;
    }

    print('🔍 BEFORE REPAIR - Current database values:');
    print('   target_language: "${currentUser.targetLanguage}"');
    print('   native_language: "${currentUser.nativeLanguage}"');
    print('   support_language_1: "${currentUser.supportLanguage1}"');
    print('   support_language_2: "${currentUser.supportLanguage2}"');

    // Check if repair is needed
    if (currentUser.targetLanguage == correctTargetLanguage &&
        currentUser.nativeLanguage == correctNativeLanguage) {
      print('✅ Database already has correct values - no repair needed!');
      return;
    }

    print('🔧 CORRUPTION DETECTED - Starting repair...');

    // Create repaired user with correct language values
    final repairedUser = currentUser.copyWith(
      targetLanguage: correctTargetLanguage,
      nativeLanguage: correctNativeLanguage,
      supportLanguage1: null, // Keep as null (original state)
      supportLanguage2: null, // Keep as null (original state)
    );

    print('🔧 Applying repair with correct values:');
    print('   target_language: "${repairedUser.targetLanguage}" (Korean)');
    print('   native_language: "${repairedUser.nativeLanguage}" (German)');
    print('   support_language_1: ${repairedUser.supportLanguage1}');
    print('   support_language_2: ${repairedUser.supportLanguage2}');

    // Update database with repaired values
    await databaseService.updateUser(repairedUser);

    print('✅ Database update completed!');

    // Verify the repair worked
    print('🔍 VERIFICATION - Reading back from database...');
    final verifiedUser = await databaseService.getUserById(userId);
    if (verifiedUser != null) {
      print('🔍 AFTER REPAIR - Database now contains:');
      print('   target_language: "${verifiedUser.targetLanguage}"');
      print('   native_language: "${verifiedUser.nativeLanguage}"');
      print('   support_language_1: "${verifiedUser.supportLanguage1}"');
      print('   support_language_2: "${verifiedUser.supportLanguage2}"');

      // Check if repair was successful
      if (verifiedUser.targetLanguage == correctTargetLanguage &&
          verifiedUser.nativeLanguage == correctNativeLanguage) {
        print('✅ REPAIR VERIFICATION PASSED');
        print('✅ Language values successfully restored to:');
        print('✅   - Target: ko (Korean)');
        print('✅   - Native: de (German)');
        print('✅');
        print('✅ Your app will now load these correct language settings!');
      } else {
        print('❌ REPAIR VERIFICATION FAILED');
        print('❌ Expected: target=ko, native=de');
        print(
            '❌ Got: target=${verifiedUser.targetLanguage}, native=${verifiedUser.nativeLanguage}');
      }
    } else {
      print(
          '❌ Could not verify repair - failed to read user back from database');
    }
  } catch (e) {
    print('❌ Database repair failed with error: $e');
    print('❌ This might be due to:');
    print('❌   - Supabase connection issues');
    print('❌   - Permission problems');
    print('❌   - Network connectivity');
    print('❌ Try checking your Supabase configuration and internet connection');
    rethrow;
  }
}
