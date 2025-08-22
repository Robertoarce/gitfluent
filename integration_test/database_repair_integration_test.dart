import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import '../lib/main.dart' as app;
import '../lib/services/supabase_database_service.dart';
import '../lib/models/user.dart';

/// INTEGRATION TEST for database repair
/// Run with: flutter test integration_test/database_repair_integration_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Database Repair Integration Test', () {
    testWidgets('should repair corrupted language values in real database',
        (WidgetTester tester) async {
      // Start the app to initialize Supabase
      await tester.pumpWidget(app.MyApp());
      await tester.pumpAndSettle();

      // Wait for initialization
      await Future.delayed(const Duration(seconds: 3));

      // Now perform the repair
      await repairCorruptedLanguageData();
    });
  });
}

/// Repair function that fixes the database
Future<void> repairCorruptedLanguageData() async {
  const userId = 'c3b402ea-2721-4529-a455-385f62c9b8b9';
  const correctTargetLanguage = 'ko'; // Korean
  const correctNativeLanguage = 'de'; // German

  try {
    print('🔧 Starting database repair for user $userId...');

    // Create database service (Supabase should be initialized by the app)
    final databaseService = SupabaseDatabaseService();

    // Get current user to see corruption
    final currentUser = await databaseService.getUserById(userId);
    if (currentUser == null) {
      print('❌ User not found: $userId');
      return;
    }

    print('🔍 BEFORE REPAIR - Current database values:');
    print('   target_language: "${currentUser.targetLanguage}"');
    print('   native_language: "${currentUser.nativeLanguage}"');

    // Check if repair is needed
    if (currentUser.targetLanguage == correctTargetLanguage &&
        currentUser.nativeLanguage == correctNativeLanguage) {
      print('✅ Database already has correct values - no repair needed!');
      return;
    }

    print('🔧 CORRUPTION DETECTED - Starting repair...');

    // Create repaired user
    final repairedUser = currentUser.copyWith(
      targetLanguage: correctTargetLanguage,
      nativeLanguage: correctNativeLanguage,
      supportLanguage1: null,
      supportLanguage2: null,
    );

    print('🔧 Applying repair with correct values:');
    print('   target_language: "${repairedUser.targetLanguage}" (Korean)');
    print('   native_language: "${repairedUser.nativeLanguage}" (German)');

    // Update database
    await databaseService.updateUser(repairedUser);

    print('✅ Database update completed!');

    // Verify the repair
    final verifiedUser = await databaseService.getUserById(userId);
    if (verifiedUser != null) {
      print('🔍 AFTER REPAIR - Database now contains:');
      print('   target_language: "${verifiedUser.targetLanguage}"');
      print('   native_language: "${verifiedUser.nativeLanguage}"');

      if (verifiedUser.targetLanguage == correctTargetLanguage &&
          verifiedUser.nativeLanguage == correctNativeLanguage) {
        print('✅ REPAIR VERIFICATION PASSED');
        print('✅ Language values successfully restored to:');
        print('✅   - Target: ko (Korean)');
        print('✅   - Native: de (German)');
        print('✅');
        print('✅ Restart your app to see the correct language settings!');
      } else {
        print('❌ REPAIR VERIFICATION FAILED');
      }
    }
  } catch (e) {
    print('❌ Database repair failed with error: $e');
    rethrow;
  }
}
