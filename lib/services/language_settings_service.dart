import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/debug_helper.dart';
import 'user_service.dart';

class Language {
  final String code;
  final String name;

  const Language(this.code, this.name);
}

class LanguageSettings extends ChangeNotifier {
  static const List<Language> availableLanguages = [
    Language('en', 'English'),
    Language('es', 'Spanish'),
    Language('fr', 'French'),
    Language('de', 'German'),
    Language('it', 'Italian'),
    Language('pt', 'Portuguese'),
    Language('ru', 'Russian'),
    Language('zh', 'Chinese'),
    Language('ja', 'Japanese'),
    Language('ko', 'Korean'),
    Language('nl', 'Dutch'),
    Language('el', 'Greek'),
    Language('he', 'Hebrew'),
    Language('hi', 'Hindi'),
    Language('ga', 'Irish'),
    Language('pl', 'Polish'),
    Language('sv', 'Swedish'),
    Language('vi', 'Vietnamese'),
  ];

  late SharedPreferences _prefs;
  Language? _targetLanguage;
  Language? _nativeLanguage;
  Language? _supportLanguage1;
  Language? _supportLanguage2;

  UserService? _userService;
  bool _isLoadingFromUser = false;

  // Getters
  Language? get targetLanguage => _targetLanguage;
  Language? get nativeLanguage => _nativeLanguage;
  Language? get supportLanguage1 => _supportLanguage1;
  Language? get supportLanguage2 => _supportLanguage2;

  // Set UserService for database synchronization
  void setUserService(UserService userService) {
    debugPrint(
        '🔗 LanguageSettings.setUserService: Connecting to UserService...');
    _userService = userService;

    // Listen to user changes so we can load preferences when user logs in
    _userService!.addListener(_handleUserChange);

    // If user is already logged in, immediately load their preferences
    if (_userService != null &&
        _userService!.isLoggedIn &&
        _userService!.currentUser != null) {
      debugPrint(
          '🔗 LanguageSettings.setUserService: User already logged in, loading preferences...');
      debugPrint(
          '🔗 LanguageSettings.setUserService: User: ${_userService!.currentUser!.email}');

      // Use Future.microtask to avoid calling async method in sync context
      Future.microtask(() async {
        try {
          await loadFromUserPreferences(_userService!.currentUser!);
          debugPrint(
              '✅ LanguageSettings.setUserService: Successfully auto-loaded user preferences');
        } catch (e) {
          debugPrint(
              '❌ LanguageSettings.setUserService: Error auto-loading user preferences: $e');
        }
      });
    } else {
      debugPrint(
          '🔗 LanguageSettings.setUserService: No user logged in, keeping current settings');
    }
  }

  // Handle user login/logout changes
  void _handleUserChange() {
    if (_userService?.isLoggedIn == true && _userService?.currentUser != null) {
      debugPrint(
          '🔗 LanguageSettings._handleUserChange: User logged in, loading preferences from database');
      // User just logged in - load their preferences from database
      Future.microtask(() async {
        try {
          await loadFromUserPreferences(_userService!.currentUser!);
          debugPrint(
              '✅ LanguageSettings._handleUserChange: Successfully loaded user preferences from database');
        } catch (e) {
          debugPrint(
              '❌ LanguageSettings._handleUserChange: Error loading user preferences: $e');
        }
      });
    } else {
      debugPrint(
          '🔗 LanguageSettings._handleUserChange: User logged out, keeping local settings');
    }
  }

  // Load preferences from user's database profile
  Future<void> loadFromUserPreferences(User user) async {
    // Prevent multiple simultaneous calls
    if (_isLoadingFromUser) {
      DebugHelper.printDebug('language_settings',
          '⏸️ LanguageSettings.loadFromUserPreferences: Already loading, skipping duplicate call');
      return;
    }

    _isLoadingFromUser = true;

    try {
      DebugHelper.printDebug('language_settings',
          '🌍 LanguageSettings.loadFromUserPreferences: Starting to load preferences from user data...');
      DebugHelper.printDebug('language_settings',
          '🔍 USER OBJECT INFO: id=${user.id}, email=${user.email}');
      DebugHelper.printDebug('language_settings',
          '🌍 LanguageSettings.loadFromUserPreferences: Raw language fields from user:');
      DebugHelper.printDebug('language_settings',
          '   - targetLanguage: "${user.targetLanguage}" (${user.targetLanguage?.runtimeType})');
      DebugHelper.printDebug('language_settings',
          '   - nativeLanguage: "${user.nativeLanguage}" (${user.nativeLanguage?.runtimeType})');
      DebugHelper.printDebug('language_settings',
          '   - supportLanguage1: "${user.supportLanguage1}" (${user.supportLanguage1?.runtimeType})');
      DebugHelper.printDebug('language_settings',
          '   - supportLanguage2: "${user.supportLanguage2}" (${user.supportLanguage2?.runtimeType})');

      // Smart override: Only use database values if they're valid, preserve existing good values
      final dbTargetLanguage = _findLanguageByCode(user.targetLanguage);
      final dbNativeLanguage = _findLanguageByCode(user.nativeLanguage);
      final dbSupportLanguage1 = _findLanguageByCode(user.supportLanguage1);
      final dbSupportLanguage2 = _findLanguageByCode(user.supportLanguage2);

      // Enhanced logic: Use database values if valid, otherwise keep existing
      if (dbTargetLanguage != null) {
        _targetLanguage = dbTargetLanguage;
        await _prefs.setString('target_language', dbTargetLanguage.code);
        DebugHelper.printDebug('language_settings',
            '✅ Using valid target language from database: ${dbTargetLanguage.code}');
      } else {
        DebugHelper.printDebug('language_settings',
            '⚠️ Database target language invalid: "${user.targetLanguage}", keeping existing: ${_targetLanguage?.code}');
        // If we have no local language either, this suggests a new user or corruption
        if (_targetLanguage == null) {
          DebugHelper.printDebug('language_settings',
              '🔄 No local target language either, this may indicate corruption recovery needed');
        }
      }

      if (dbNativeLanguage != null) {
        _nativeLanguage = dbNativeLanguage;
        await _prefs.setString('native_language', dbNativeLanguage.code);
        DebugHelper.printDebug('language_settings',
            '✅ Using valid native language from database: ${dbNativeLanguage.code}');
      } else {
        DebugHelper.printDebug('language_settings',
            '⚠️ Database native language invalid: "${user.nativeLanguage}", keeping existing: ${_nativeLanguage?.code}');
        // If we have no local language either, this suggests a new user or corruption
        if (_nativeLanguage == null) {
          DebugHelper.printDebug('language_settings',
              '🔄 No local native language either, this may indicate corruption recovery needed');
        }
      }

      // Handle support languages (these can be null)
      if (dbSupportLanguage1 != null) {
        _supportLanguage1 = dbSupportLanguage1;
        await _prefs.setString('support_language_1', dbSupportLanguage1.code);
        DebugHelper.printDebug('language_settings',
            '✅ Using valid support language 1 from database: ${dbSupportLanguage1.code}');
      } else {
        DebugHelper.printDebug('language_settings',
            '⚠️ Database support language 1 invalid: "${user.supportLanguage1}", keeping existing: ${_supportLanguage1?.code}');
      }

      if (dbSupportLanguage2 != null) {
        _supportLanguage2 = dbSupportLanguage2;
        await _prefs.setString('support_language_2', dbSupportLanguage2.code);
        DebugHelper.printDebug('language_settings',
            '✅ Using valid support language 2 from database: ${dbSupportLanguage2.code}');
      } else {
        DebugHelper.printDebug('language_settings',
            '⚠️ Database support language 2 invalid: "${user.supportLanguage2}", keeping existing: ${_supportLanguage2?.code}');
      }

      DebugHelper.printDebug('language_settings',
          '🌍 LanguageSettings.loadFromUserPreferences: Final language objects:');
      DebugHelper.printDebug('language_settings',
          '   - _targetLanguage: ${_targetLanguage?.code} (${_targetLanguage?.name})');
      DebugHelper.printDebug('language_settings',
          '   - _nativeLanguage: ${_nativeLanguage?.code} (${_nativeLanguage?.name})');
      DebugHelper.printDebug('language_settings',
          '   - _supportLanguage1: ${_supportLanguage1?.code} (${_supportLanguage1?.name})');
      DebugHelper.printDebug('language_settings',
          '   - _supportLanguage2: ${_supportLanguage2?.code} (${_supportLanguage2?.name})');

      debugPrint(
          '🌍 LanguageSettings.loadFromUserPreferences: Updated SharedPreferences with user data');
      debugPrint(
          '🌍 LanguageSettings.loadFromUserPreferences: Calling notifyListeners() to update UI...');

      notifyListeners();

      debugPrint(
          '✅ LanguageSettings.loadFromUserPreferences: Successfully completed loading preferences from user data');
    } finally {
      _isLoadingFromUser = false;
    }
  }

  // Sync current settings to database
  Future<void> _syncToDatabase() async {
    if (_userService == null || !_userService!.isLoggedIn) return;

    final currentUser = _userService!.currentUser;
    if (currentUser == null) return;

    // CRITICAL FIX: Don't sync while loading from user preferences to prevent overwriting database values
    if (_isLoadingFromUser) {
      DebugHelper.printDebug('language_settings',
          '⏸️ _syncToDatabase: Skipping sync while loading from user preferences to prevent overwriting database values');
      return;
    }

    // IMPROVED: Better safeguards against null corruption
    // Only sync if we have valid local values to prevent writing nulls to database
    if (_targetLanguage == null || _nativeLanguage == null) {
      DebugHelper.printDebug('language_settings',
          '⚠️ _syncToDatabase: Skipping sync - missing required language values (target: ${_targetLanguage?.code}, native: ${_nativeLanguage?.code})');
      return;
    }

    // Prepare values to sync - NEVER send null, always use current valid values or existing database values
    final targetCode = _targetLanguage?.code ?? currentUser.targetLanguage;
    final nativeCode = _nativeLanguage?.code ?? currentUser.nativeLanguage;
    final support1Code =
        _supportLanguage1?.code; // Can be null for support languages
    final support2Code =
        _supportLanguage2?.code; // Can be null for support languages

    // SAFEGUARD: Don't sync if target or native would be null
    if (targetCode == null || nativeCode == null) {
      DebugHelper.printDebug('language_settings',
          '🚨 _syncToDatabase: BLOCKING sync - would write null values to database! target=$targetCode, native=$nativeCode');
      return;
    }

    // 🚨 DEBUG: Track exactly what values we're about to send to database
    debugPrint('🚨 _syncToDatabase: CRITICAL DEBUG TRACKING:');
    debugPrint(
        '🚨   Local state: _targetLanguage=${_targetLanguage?.code}, _nativeLanguage=${_nativeLanguage?.code}');
    debugPrint(
        '🚨   CurrentUser: target=${currentUser.targetLanguage}, native=${currentUser.nativeLanguage}');
    debugPrint(
        '🚨   Final codes: target=$targetCode, native=$nativeCode, support1=$support1Code, support2=$support2Code');

    // Check if values have actually changed to avoid unnecessary DB writes
    final hasChanges = currentUser.targetLanguage != targetCode ||
        currentUser.nativeLanguage != nativeCode ||
        currentUser.supportLanguage1 != support1Code ||
        currentUser.supportLanguage2 != support2Code;

    debugPrint('🚨   hasChanges: $hasChanges');
    debugPrint(
        '🚨   Comparison: currentUser.target(${currentUser.targetLanguage}) != targetCode($targetCode) = ${currentUser.targetLanguage != targetCode}');

    if (!hasChanges) {
      debugPrint(
          'LanguageSettings: No changes detected, skipping database sync');
      return;
    }

    debugPrint(
        '🚨 _syncToDatabase: SENDING TO DATABASE - target: $targetCode, native: $nativeCode');

    try {
      await _userService!.updateLanguageSettings(
        targetLanguage: targetCode,
        nativeLanguage: nativeCode,
        supportLanguage1: support1Code,
        supportLanguage2: support2Code,
      );
      debugPrint(
          'LanguageSettings: Successfully synced language settings to database');
    } catch (e) {
      debugPrint(
          'LanguageSettings: Failed to sync language settings to database: $e');
    }
  }

  // Initialize preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLanguages();

    // ONLY set default languages if this is a completely new installation
    // (no languages in SharedPreferences) AND we don't expect user data to load soon
    // For logged-in users, their preferences will be loaded from database via setUserService
    final hasAnyStoredLanguages = _prefs.getString('target_language') != null ||
        _prefs.getString('native_language') != null;

    if (!hasAnyStoredLanguages) {
      debugPrint(
          'LanguageSettings.init: No stored languages found, setting defaults for new user');
      // Set defaults WITHOUT syncing to database (user might not be logged in yet)
      _targetLanguage = availableLanguages.firstWhere((l) => l.code == 'fr');
      _nativeLanguage = availableLanguages.firstWhere((l) => l.code == 'en');

      // Store in SharedPreferences only
      await _prefs.setString('target_language', 'fr');
      await _prefs.setString('native_language', 'en');
      notifyListeners();
    }
    // Don't set default support languages - let them remain null unless user explicitly sets them
  }

  void _loadLanguages() {
    final targetCode = _prefs.getString('target_language');
    final nativeCode = _prefs.getString('native_language');
    final support1Code = _prefs.getString('support_language_1');
    final support2Code = _prefs.getString('support_language_2');

    _targetLanguage = _findLanguageByCode(targetCode);
    _nativeLanguage = _findLanguageByCode(nativeCode);
    _supportLanguage1 = _findLanguageByCode(support1Code);
    _supportLanguage2 = _findLanguageByCode(support2Code);

    notifyListeners();
  }

  Language? _findLanguageByCode(String? code) {
    // ENHANCED: Better detection of invalid values
    if (code == null || code == 'null' || code.isEmpty || code.trim().isEmpty) {
      return null;
    }
    try {
      return availableLanguages.firstWhere((lang) => lang.code == code);
    } catch (_) {
      // Invalid language code
      DebugHelper.printDebug('language_settings',
          '⚠️ _findLanguageByCode: Invalid language code: "$code"');
      return null;
    }
  }

  // Setters
  Future<void> setTargetLanguage(Language language) async {
    DebugHelper.printDebug('language_settings',
        '🎯 setTargetLanguage: Setting target language to ${language.code} (${language.name})');
    _targetLanguage = language;
    await _prefs.setString('target_language', language.code);
    DebugHelper.printDebug('language_settings',
        '💾 setTargetLanguage: Saved to SharedPreferences');
    await _syncToDatabase();
    DebugHelper.printDebug(
        'language_settings', '🔄 setTargetLanguage: Synced to database');
    notifyListeners();
    DebugHelper.printDebug(
        'language_settings', '🔔 setTargetLanguage: Notified UI listeners');
  }

  Future<void> setNativeLanguage(Language language) async {
    DebugHelper.printDebug('language_settings',
        '🏠 setNativeLanguage: Setting native language to ${language.code} (${language.name})');
    _nativeLanguage = language;
    await _prefs.setString('native_language', language.code);
    DebugHelper.printDebug('language_settings',
        '💾 setNativeLanguage: Saved to SharedPreferences');
    await _syncToDatabase();
    DebugHelper.printDebug(
        'language_settings', '🔄 setNativeLanguage: Synced to database');
    notifyListeners();
    DebugHelper.printDebug(
        'language_settings', '🔔 setNativeLanguage: Notified UI listeners');
  }

  Future<void> setSupportLanguage1(Language? language) async {
    _supportLanguage1 = language;
    if (language != null) {
      await _prefs.setString('support_language_1', language.code);
    } else {
      await _prefs.remove('support_language_1');
    }
    await _syncToDatabase();
    notifyListeners();
  }

  Future<void> setSupportLanguage2(Language? language) async {
    _supportLanguage2 = language;
    if (language != null) {
      await _prefs.setString('support_language_2', language.code);
    } else {
      await _prefs.remove('support_language_2');
    }
    await _syncToDatabase();
    notifyListeners();
  }

  @override
  void dispose() {
    _userService?.removeListener(_handleUserChange);
    super.dispose();
  }
}
