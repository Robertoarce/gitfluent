import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
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

  // Load preferences from user's database profile
  Future<void> loadFromUserPreferences(User user) async {
    debugPrint(
        '🌍 LanguageSettings.loadFromUserPreferences: Starting to load preferences from Supabase...');
    debugPrint(
        '🌍 LanguageSettings.loadFromUserPreferences: Raw preferences from Supabase:');
    debugPrint('   - targetLanguage: "${user.targetLanguage}"');
    debugPrint('   - nativeLanguage: "${user.nativeLanguage}"');
    debugPrint('   - supportLanguage1: "${user.supportLanguage1}"');
    debugPrint('   - supportLanguage2: "${user.supportLanguage2}"');

    _targetLanguage = _findLanguageByCode(user.targetLanguage);
    _nativeLanguage = _findLanguageByCode(user.nativeLanguage);
    _supportLanguage1 = _findLanguageByCode(user.supportLanguage1);
    _supportLanguage2 = _findLanguageByCode(user.supportLanguage2);

    debugPrint(
        '🌍 LanguageSettings.loadFromUserPreferences: Language objects found:');
    debugPrint(
        '   - _targetLanguage: ${_targetLanguage?.code} (${_targetLanguage?.name})');
    debugPrint(
        '   - _nativeLanguage: ${_nativeLanguage?.code} (${_nativeLanguage?.name})');
    debugPrint(
        '   - _supportLanguage1: ${_supportLanguage1?.code} (${_supportLanguage1?.name})');
    debugPrint(
        '   - _supportLanguage2: ${_supportLanguage2?.code} (${_supportLanguage2?.name})');

    // Also update SharedPreferences to keep them in sync
    await _prefs.setString('target_language', user.targetLanguage);
    await _prefs.setString('native_language', user.nativeLanguage);
    if (user.supportLanguage1 != null) {
      await _prefs.setString('support_language_1', user.supportLanguage1!);
    }
    if (user.supportLanguage2 != null) {
      await _prefs.setString('support_language_2', user.supportLanguage2!);
    }

    debugPrint(
        '🌍 LanguageSettings.loadFromUserPreferences: Updated SharedPreferences with Supabase data');
    debugPrint(
        '🌍 LanguageSettings.loadFromUserPreferences: Calling notifyListeners() to update UI...');

    notifyListeners();

    debugPrint(
        '✅ LanguageSettings.loadFromUserPreferences: Successfully completed loading preferences from Supabase');
  }

  // Sync current settings to database
  Future<void> _syncToDatabase() async {
    if (_userService == null || !_userService!.isLoggedIn) return;

    final currentUser = _userService!.currentUser;
    if (currentUser == null) return;

    try {
      final updatedUser = currentUser.copyWith(
        targetLanguage: _targetLanguage?.code ?? currentUser.targetLanguage,
        nativeLanguage: _nativeLanguage?.code ?? currentUser.nativeLanguage,
        supportLanguage1: _supportLanguage1?.code,
        supportLanguage2: _supportLanguage2?.code,
      );

      await _userService!.updateUserLanguagePreferences(updatedUser);
      debugPrint(
          'LanguageSettings: Successfully synced preferences to database');
    } catch (e) {
      debugPrint(
          'LanguageSettings: Failed to sync preferences to database: $e');
    }
  }

  // Initialize preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLanguages();

    // The logic to set default languages if null is now handled by the initial user profile creation
    // or by the loading of user preferences from Supabase in loadFromUserPreferences.
    // This prevents overwriting Supabase values with hardcoded defaults.
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
    if (code == null) return null;
    try {
      return availableLanguages.firstWhere((lang) => lang.code == code);
    } catch (_) {
      return null;
    }
  }

  // Setters
  Future<void> setTargetLanguage(Language language) async {
    _targetLanguage = language;
    await _prefs.setString('target_language', language.code);
    await _syncToDatabase();
    notifyListeners();
  }

  Future<void> setNativeLanguage(Language language) async {
    _nativeLanguage = language;
    await _prefs.setString('native_language', language.code);
    await _syncToDatabase();
    notifyListeners();
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
}
