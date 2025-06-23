import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'global_settings_service.dart';
import 'logging_service.dart';
import 'user_preferences_service.dart';

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
  bool _isInitialized = false;
  final LoggingService _logger = LoggingService();

  // Getters
  Language? get targetLanguage => _targetLanguage;
  Language? get nativeLanguage => _nativeLanguage;
  Language? get supportLanguage1 => _supportLanguage1;
  Language? get supportLanguage2 => _supportLanguage2;
  bool get isInitialized => _isInitialized;

  // Initialize preferences and sync with GlobalSettingsService
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Register callback with UserPreferencesService
      _registerUserPreferencesCallback();

      await _loadLanguages();

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

      _isInitialized = true;
      _logger.log(LogCategory.settingsService,
          'LanguageSettings initialized successfully');
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error initializing LanguageSettings: $e',
          isError: true);
      rethrow;
    }
  }

  // Register callback with UserPreferencesService for synchronization
  void _registerUserPreferencesCallback() {
    try {
      // Register the callback to handle updates from UserPreferencesService
      UserPreferencesService.setLanguageSettingsCallback(
          _handleUserPreferencesUpdate);

      _logger.log(LogCategory.settingsService,
          'Successfully registered callback with UserPreferencesService');
    } catch (e) {
      _logger.log(LogCategory.settingsService, 'Error registering callback: $e',
          isError: true);
    }
  }

  // Handle updates from UserPreferencesService
  void _handleUserPreferencesUpdate(Map<String, String> languageMap) {
    _logger.log(LogCategory.settingsService,
        'Received language update from UserPreferencesService');
    _logger.log(LogCategory.settingsService,
        'Target language: ${languageMap['target_language']}');

    updateFromExternalSource(
      targetLanguageCode: languageMap['target_language'],
      nativeLanguageCode: languageMap['native_language'],
      supportLanguage1Code:
          languageMap['support_language_1']?.isNotEmpty == true
              ? languageMap['support_language_1']
              : null,
      supportLanguage2Code:
          languageMap['support_language_2']?.isNotEmpty == true
              ? languageMap['support_language_2']
              : null,
    );
  }

  Future<void> _loadLanguages() async {
    try {
      final targetCode = _prefs.getString('target_language');
      final nativeCode = _prefs.getString('native_language');
      final support1Code = _prefs.getString('support_language_1');
      final support2Code = _prefs.getString('support_language_2');

      _targetLanguage = _findLanguageByCode(targetCode);
      _nativeLanguage = _findLanguageByCode(nativeCode);
      _supportLanguage1 = _findLanguageByCode(support1Code);
      _supportLanguage2 = _findLanguageByCode(support2Code);

      // Sync with GlobalSettingsService if it's initialized
      await _syncWithGlobalSettings();

      notifyListeners();
    } catch (e) {
      _logger.log(
          LogCategory.settingsService, 'Error loading language settings: $e',
          isError: true);
    }
  }

  Future<void> _syncWithGlobalSettings() async {
    try {
      if (GlobalSettingsService.instance.isInitialized) {
        final globalSettings = GlobalSettingsService.instance;
        final currentLanguages = globalSettings.languages;

        // If global settings has different values, update local settings
        bool needsUpdate = false;

        if (_targetLanguage?.code != currentLanguages.targetLanguage) {
          _targetLanguage =
              _findLanguageByCode(currentLanguages.targetLanguage);
          needsUpdate = true;
        }

        if (_nativeLanguage?.code != currentLanguages.nativeLanguage) {
          _nativeLanguage =
              _findLanguageByCode(currentLanguages.nativeLanguage);
          needsUpdate = true;
        }

        if (_supportLanguage1?.code != currentLanguages.supportLanguage1) {
          _supportLanguage1 =
              _findLanguageByCode(currentLanguages.supportLanguage1);
          needsUpdate = true;
        }

        if (_supportLanguage2?.code != currentLanguages.supportLanguage2) {
          _supportLanguage2 =
              _findLanguageByCode(currentLanguages.supportLanguage2);
          needsUpdate = true;
        }

        if (needsUpdate) {
          await _saveLanguages();
          _logger.log(LogCategory.settingsService,
              'Synchronized language settings with GlobalSettings');
        }
      }
    } catch (e) {
      _logger.log(
          LogCategory.settingsService, 'Error syncing with GlobalSettings: $e',
          isError: true);
    }
  }

  Future<void> _saveLanguages() async {
    try {
      if (_targetLanguage != null) {
        await _prefs.setString('target_language', _targetLanguage!.code);
      }
      if (_nativeLanguage != null) {
        await _prefs.setString('native_language', _nativeLanguage!.code);
      }
      if (_supportLanguage1 != null) {
        await _prefs.setString('support_language_1', _supportLanguage1!.code);
      } else {
        await _prefs.remove('support_language_1');
      }
      if (_supportLanguage2 != null) {
        await _prefs.setString('support_language_2', _supportLanguage2!.code);
      } else {
        await _prefs.remove('support_language_2');
      }
    } catch (e) {
      _logger.log(
          LogCategory.settingsService, 'Error saving language settings: $e',
          isError: true);
    }
  }

  Language? _findLanguageByCode(String? code) {
    if (code == null) return null;
    try {
      return availableLanguages.firstWhere((lang) => lang.code == code);
    } catch (_) {
      return null;
    }
  }

  // Setters with GlobalSettings synchronization
  Future<void> setTargetLanguage(Language language) async {
    _targetLanguage = language;
    await _prefs.setString('target_language', language.code);
    await _syncToGlobalSettings();
    notifyListeners();
    _logger.log(LogCategory.settingsService,
        'Target language updated to: ${language.name}');
  }

  Future<void> setNativeLanguage(Language language) async {
    _nativeLanguage = language;
    await _prefs.setString('native_language', language.code);
    await _syncToGlobalSettings();
    notifyListeners();
    _logger.log(LogCategory.settingsService,
        'Native language updated to: ${language.name}');
  }

  Future<void> setSupportLanguage1(Language? language) async {
    _supportLanguage1 = language;
    if (language != null) {
      await _prefs.setString('support_language_1', language.code);
    } else {
      await _prefs.remove('support_language_1');
    }
    await _syncToGlobalSettings();
    notifyListeners();
    _logger.log(LogCategory.settingsService,
        'Support language 1 updated to: ${language?.name ?? 'None'}');
  }

  Future<void> setSupportLanguage2(Language? language) async {
    _supportLanguage2 = language;
    if (language != null) {
      await _prefs.setString('support_language_2', language.code);
    } else {
      await _prefs.remove('support_language_2');
    }
    await _syncToGlobalSettings();
    notifyListeners();
    _logger.log(LogCategory.settingsService,
        'Support language 2 updated to: ${language?.name ?? 'None'}');
  }

  // Sync changes to GlobalSettingsService
  Future<void> _syncToGlobalSettings() async {
    try {
      if (GlobalSettingsService.instance.isInitialized) {
        await GlobalSettingsService.instance.updateLanguages(
          targetLanguage: _targetLanguage?.code,
          nativeLanguage: _nativeLanguage?.code,
          supportLanguage1: _supportLanguage1?.code,
          supportLanguage2: _supportLanguage2?.code,
        );
        _logger.log(LogCategory.settingsService,
            'Language settings synced to GlobalSettings');
      }
    } catch (e) {
      _logger.log(
          LogCategory.settingsService, 'Error syncing to GlobalSettings: $e',
          isError: true);
    }
  }

  // Method to force reload from persistence
  Future<void> reload() async {
    if (_isInitialized) {
      await _loadLanguages();
      _logger.log(LogCategory.settingsService, 'Language settings reloaded');
    }
  }

  // Method to force reload and notify listeners (for external updates)
  Future<void> reloadAndNotify() async {
    if (_isInitialized) {
      await _loadLanguages();
      notifyListeners(); // Force notification to all listeners
      _logger.log(LogCategory.settingsService,
          'Language settings reloaded and listeners notified');
    }
  }

  // Method to update settings from external source (like UserPreferencesService)
  Future<void> updateFromExternalSource({
    String? targetLanguageCode,
    String? nativeLanguageCode,
    String? supportLanguage1Code,
    String? supportLanguage2Code,
  }) async {
    try {
      bool hasChanges = false;

      _logger.log(LogCategory.settingsService,
          'LanguageSettings.updateFromExternalSource called with target: $targetLanguageCode');

      if (targetLanguageCode != null &&
          _targetLanguage?.code != targetLanguageCode) {
        final targetLang = _findLanguageByCode(targetLanguageCode);
        if (targetLang != null) {
          _targetLanguage = targetLang;
          await _prefs.setString('target_language', targetLanguageCode);
          hasChanges = true;
          _logger.log(LogCategory.settingsService,
              'Updated target language from external source to: ${targetLang.name}');
        }
      }

      if (nativeLanguageCode != null &&
          _nativeLanguage?.code != nativeLanguageCode) {
        final nativeLang = _findLanguageByCode(nativeLanguageCode);
        if (nativeLang != null) {
          _nativeLanguage = nativeLang;
          await _prefs.setString('native_language', nativeLanguageCode);
          hasChanges = true;
          _logger.log(LogCategory.settingsService,
              'Updated native language from external source to: ${nativeLang.name}');
        }
      }

      if (supportLanguage1Code != null &&
          _supportLanguage1?.code != supportLanguage1Code) {
        final support1Lang = _findLanguageByCode(supportLanguage1Code);
        if (support1Lang != null) {
          _supportLanguage1 = support1Lang;
          await _prefs.setString('support_language_1', supportLanguage1Code);
          hasChanges = true;
          _logger.log(LogCategory.settingsService,
              'Updated support language 1 from external source to: ${support1Lang.name}');
        }
      }

      if (supportLanguage2Code != null &&
          _supportLanguage2?.code != supportLanguage2Code) {
        final support2Lang = _findLanguageByCode(supportLanguage2Code);
        if (support2Lang != null) {
          _supportLanguage2 = support2Lang;
          await _prefs.setString('support_language_2', supportLanguage2Code);
          hasChanges = true;
          _logger.log(LogCategory.settingsService,
              'Updated support language 2 from external source to: ${support2Lang.name}');
        }
      }

      if (hasChanges) {
        await _syncToGlobalSettings();
        notifyListeners();
        _logger.log(LogCategory.settingsService,
            'External language settings update completed with changes');
      } else {
        _logger.log(LogCategory.settingsService,
            'External language settings update completed with no changes');
      }
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error updating from external source: $e',
          isError: true);
    }
  }

  // Method to get all current settings as a map for debugging
  Map<String, String?> getCurrentSettings() {
    return {
      'target_language': _targetLanguage?.code,
      'native_language': _nativeLanguage?.code,
      'support_language_1': _supportLanguage1?.code,
      'support_language_2': _supportLanguage2?.code,
    };
  }
}
