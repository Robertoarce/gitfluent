import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugHelper {
  static Map<String, bool> _debugSections = {};
  static bool _isInitialized = false;
  static SharedPreferences? _prefs;
  static const String _prefsKey = 'debug_sections_override';

  /// Initialize the debug configuration from config.yaml and SharedPreferences
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    try {
      final yamlString = await rootBundle.loadString('lib/config/config.yaml');
      final yamlDoc = loadYaml(yamlString);

      if (yamlDoc['debug_sections'] != null) {
        final sections = yamlDoc['debug_sections'] as YamlMap;
        _debugSections = Map<String, bool>.from(sections);
      }

      // Load runtime overrides from SharedPreferences
      await _loadRuntimeOverrides();

      _isInitialized = true;
    } catch (e) {
      // Fallback to safe defaults if config can't be loaded
      _debugSections = {
        'supabase': false,
        'chat_service': false,
        'user_service': false,
        'vocabulary_service': false,
        'auth_service': false,
        'flashcard_service': false,
        'language_settings': false,
        'llm_output_formatter': false,
        'nlp_service': false,
        'accessibility': false,
        'config': false,
        'general': false,
      };
      _isInitialized = true;
      if (kDebugMode) {
        print('DebugHelper: Failed to load config, using defaults: $e');
      }
    }
  }

  /// Load runtime overrides from SharedPreferences
  static Future<void> _loadRuntimeOverrides() async {
    if (_prefs == null) return;

    final overrides = _prefs!.getStringList(_prefsKey);
    if (overrides != null) {
      for (final override in overrides) {
        final parts = override.split('=');
        if (parts.length == 2) {
          final section = parts[0];
          final enabled = parts[1] == 'true';
          if (_debugSections.containsKey(section)) {
            _debugSections[section] = enabled;
          }
        }
      }
    }
  }

  /// Save runtime overrides to SharedPreferences
  static Future<void> _saveRuntimeOverrides() async {
    if (_prefs == null) return;

    final overrides = <String>[];
    for (final entry in _debugSections.entries) {
      overrides.add('${entry.key}=${entry.value}');
    }
    await _prefs!.setStringList(_prefsKey, overrides);
  }

  /// Print debug message if the section is enabled
  static void printDebug(String section, String message) {
    if (!_isInitialized) {
      // If not initialized yet, fall back to regular debugPrint
      if (kDebugMode) {
        print('[$section] $message');
      }
      return;
    }

    if (_debugSections[section] == true) {
      if (kDebugMode) {
        print('[$section] $message');
      }
    }
  }

  /// Check if a debug section is enabled
  static bool isEnabled(String section) {
    if (!_isInitialized) return false;
    return _debugSections[section] == true;
  }

  /// Get all debug sections and their status
  static Map<String, bool> getAllSections() {
    return Map<String, bool>.from(_debugSections);
  }

  /// Enable/disable a debug section at runtime and persist the change
  static Future<void> setSection(String section, bool enabled) async {
    if (!_isInitialized) await initialize();

    _debugSections[section] = enabled;
    await _saveRuntimeOverrides();

    if (kDebugMode) {
      print(
          '[debug_helper] Section "$section" ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  /// Enable all debug sections
  static Future<void> enableAll() async {
    if (!_isInitialized) await initialize();

    _debugSections.updateAll((key, value) => true);
    await _saveRuntimeOverrides();

    if (kDebugMode) {
      print('[debug_helper] All debug sections enabled');
    }
  }

  /// Disable all debug sections
  static Future<void> disableAll() async {
    if (!_isInitialized) await initialize();

    _debugSections.updateAll((key, value) => false);
    await _saveRuntimeOverrides();

    if (kDebugMode) {
      print('[debug_helper] All debug sections disabled');
    }
  }

  /// Reset to defaults from config.yaml (remove runtime overrides)
  static Future<void> resetToDefaults() async {
    if (_prefs != null) {
      await _prefs!.remove(_prefsKey);
    }

    // Reinitialize to reload defaults
    _isInitialized = false;
    await initialize();

    if (kDebugMode) {
      print('[debug_helper] Reset to default configuration');
    }
  }

  /// Get a formatted status summary for display
  static String getStatusSummary() {
    if (!_isInitialized) return 'Not initialized';

    final enabled = _debugSections.values.where((enabled) => enabled).length;
    final total = _debugSections.length;
    return '$enabled/$total sections enabled';
  }
}
