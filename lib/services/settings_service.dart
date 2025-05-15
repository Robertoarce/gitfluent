import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AIProvider {
  gemini,
  openai,
}

class SettingsService extends ChangeNotifier {
  static const String _providerKey = 'ai_provider';
  late SharedPreferences _prefs;
  AIProvider _currentProvider = AIProvider.gemini;

  AIProvider get currentProvider => _currentProvider;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedProvider = _prefs.getString(_providerKey);
    if (savedProvider != null) {
      _currentProvider = AIProvider.values.firstWhere(
        (e) => e.toString() == savedProvider,
        orElse: () => AIProvider.gemini,
      );
    }
    notifyListeners();
  }

  Future<void> setProvider(AIProvider provider) async {
    _currentProvider = provider;
    await _prefs.setString(_providerKey, provider.toString());
    notifyListeners();
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