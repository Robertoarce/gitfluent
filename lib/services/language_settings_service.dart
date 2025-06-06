import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Getters
  Language? get targetLanguage => _targetLanguage;
  Language? get nativeLanguage => _nativeLanguage;
  Language? get supportLanguage1 => _supportLanguage1;
  Language? get supportLanguage2 => _supportLanguage2;

  // Initialize preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLanguages();

    // Set default languages if none are set
    if (_targetLanguage == null) {
      await setTargetLanguage(
          availableLanguages.firstWhere((l) => l.code == 'it'));
    }
    if (_nativeLanguage == null) {
      await setNativeLanguage(
          availableLanguages.firstWhere((l) => l.code == 'en'));
    }
    if (_supportLanguage1 == null) {
      await setSupportLanguage1(
          availableLanguages.firstWhere((l) => l.code == 'es'));
    }
    if (_supportLanguage2 == null) {
      await setSupportLanguage2(
          availableLanguages.firstWhere((l) => l.code == 'fr'));
    }
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
    notifyListeners();
  }

  Future<void> setNativeLanguage(Language language) async {
    _nativeLanguage = language;
    await _prefs.setString('native_language', language.code);
    notifyListeners();
  }

  Future<void> setSupportLanguage1(Language? language) async {
    _supportLanguage1 = language;
    if (language != null) {
      await _prefs.setString('support_language_1', language.code);
    } else {
      await _prefs.remove('support_language_1');
    }
    notifyListeners();
  }

  Future<void> setSupportLanguage2(Language? language) async {
    _supportLanguage2 = language;
    if (language != null) {
      await _prefs.setString('support_language_2', language.code);
    } else {
      await _prefs.remove('support_language_2');
    }
    notifyListeners();
  }
}
