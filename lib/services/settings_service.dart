import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_settings_service.dart';

enum AIProvider {
  gemini,
  openai,
}

class SettingsService extends ChangeNotifier {
  static const String _providerKey = 'ai_provider';
  static const String _maxVerbsKey = 'max_verbs';
  static const String _maxNounsKey = 'max_nouns';
  
  static const int defaultMaxVerbs = 5;
  static const int defaultMaxNouns = 10;
  static const int maxVerbsLimit = 15;  // 3x default
  static const int maxNounsLimit = 30;  // 3x default
  
  late SharedPreferences _prefs;
  AIProvider _currentProvider = AIProvider.gemini;
  int _maxVerbs = defaultMaxVerbs;
  int _maxNouns = defaultMaxNouns;
  final LanguageSettings _languageSettings;

  AIProvider get currentProvider => _currentProvider;
  int get maxVerbs => _maxVerbs;
  int get maxNouns => _maxNouns;
  LanguageSettings get languageSettings => _languageSettings;

  SettingsService() : _languageSettings = LanguageSettings() {
    _init();
  }

  Future<void> init() async {
    await _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    await _languageSettings.init();
  }

  Future<void> _loadSettings() async {
    final savedProvider = _prefs.getString(_providerKey);
    if (savedProvider != null) {
      _currentProvider = AIProvider.values.firstWhere(
        (e) => e.toString() == savedProvider,
        orElse: () => AIProvider.gemini,
      );
    }
    
    _maxVerbs = _prefs.getInt(_maxVerbsKey) ?? defaultMaxVerbs;
    _maxNouns = _prefs.getInt(_maxNounsKey) ?? defaultMaxNouns;
    
    notifyListeners();
  }

  Future<void> setProvider(AIProvider provider) async {
    _currentProvider = provider;
    await _prefs.setString(_providerKey, provider.toString());
    notifyListeners();
  }

  Future<void> setMaxVerbs(int value) async {
    if (value >= 1 && value <= maxVerbsLimit) {
      _maxVerbs = value;
      await _prefs.setInt(_maxVerbsKey, value);
      notifyListeners();
    }
  }

  Future<void> setMaxNouns(int value) async {
    if (value >= 1 && value <= maxNounsLimit) {
      _maxNouns = value;
      await _prefs.setInt(_maxNounsKey, value);
      notifyListeners();
    }
  }

  String getProviderName(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Google Gemini';
      case AIProvider.openai:
        return 'OpenAI GPT';
    }
  }

  String? getProviderApiKeyName(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'GEMINI_API_KEY';
      case AIProvider.openai:
        return 'OPENAI_API_KEY';
    }
  }
} 