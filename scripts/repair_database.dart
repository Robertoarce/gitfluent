#!/usr/bin/env dart

/// Simple database repair script
/// Run with: dart scripts/repair_database.dart
/// This repairs the corrupted language values directly

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔧 DATABASE REPAIR SCRIPT');
  print('🔧 This script provides the SQL command to fix your database');
  print('🔧');

  final sqlCommand = '''
UPDATE users SET 
  target_language = 'ko',
  native_language = 'de'
WHERE id = 'c3b402ea-2721-4529-a455-385f62c9b8b9';
''';

  print('🚨 MANUAL FIX REQUIRED');
  print('🚨 Your database contains corrupted language values ("null" strings)');
  print('🚨 Current state: target_language="null", native_language="null"');
  print('🚨 Correct values: target_language="ko", native_language="de"');
  print('🚨');
  print('🔧 SOLUTION: Run this SQL in your Supabase dashboard:');
  print('🔧');
  print(sqlCommand);
  print('🔧');
  print('✅ Steps to fix:');
  print('✅ 1. Go to Supabase Dashboard → SQL Editor');
  print('✅ 2. Copy and paste the SQL command above');
  print('✅ 3. Click "Run"');
  print('✅ 4. Restart your Flutter app');
  print('✅');
  print('✅ Expected result: App will show Korean (target) and German (native)');
  print('✅ The enhanced safeguards will prevent future corruption');

  // Write SQL to file for easy copying
  final file = File('database_repair.sql');
  await file.writeAsString(sqlCommand);
  print('📄 SQL command also saved to: database_repair.sql');
}
