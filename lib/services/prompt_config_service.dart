import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PromptConfig {
  final String modelName;
  final double temperature;
  final int maxTokens;
  final Map<String, String> promptVariables;
  final Map<String, String> defaultSettings;
  final String systemPromptType;

  // This comes from the system prompt type
  PromptConfig({
    required this.modelName,
    required this.temperature,
    required this.maxTokens,
    required this.promptVariables,
    required this.defaultSettings,
    required this.systemPromptType,
  });

  factory PromptConfig.fromYaml(dynamic yaml) {
    // Convert YamlMap to regular Map
    final Map<String, dynamic> model = Map<String, dynamic>.from(yaml['model']);
    final Map<String, dynamic> promptVars =
        Map<String, dynamic>.from(yaml['prompt_variables']);
    final Map<String, dynamic> defaultSettings =
        Map<String, dynamic>.from(yaml['default_settings']);

    return PromptConfig(
      modelName: model['name'].toString(),
      temperature: (model['temperature'] as num).toDouble(),
      maxTokens: (model['max_tokens'] as num).toInt(),
      promptVariables: promptVars
          .map((key, value) => MapEntry(key.toString(), value.toString())),
      defaultSettings: defaultSettings
          .map((key, value) => MapEntry(key.toString(), value.toString())),
      systemPromptType: yaml['system_prompt_type'].toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': {
        'name': modelName,
        'temperature': temperature,
        'max_tokens': maxTokens,
      },
      'prompt_variables': promptVariables,
      'default_settings': defaultSettings,
      'system_prompt_type': systemPromptType,
    };
  }
}

class PromptConfigService {
  static PromptConfig? _config;
  static late SharedPreferences _prefs;
  static const String _configKey = 'prompt_config';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static void clearCache() {
    _config = null;
  }

  static Future<PromptConfig> loadConfig() async {
    if (_config != null) return _config!;

    try {
      // First try to load from saved preferences
      final savedConfig = _prefs.getString(_configKey);
      if (savedConfig != null) {
        final Map<String, dynamic> jsonConfig = json.decode(savedConfig);
        _config = PromptConfig.fromYaml(jsonConfig);
        return _config!;
      }

      // If no saved config, load from YAML file
      final String yamlString =
          await rootBundle.loadString('lib/config/config.yaml');
      final dynamic yamlData = loadYaml(yamlString);
      _config = PromptConfig.fromYaml(yamlData);

      // Save the default config
      await _saveConfig();

      return _config!;
    } catch (e) {
      throw Exception('Failed to load prompt configuration: $e');
    }
  }

  static Future<void> _saveConfig() async {
    if (_config != null) {
      final jsonString = json.encode(_config!.toJson());
      await _prefs.setString(_configKey, jsonString);
    }
  }

  static Future<void> updateConfig({
    String? modelName,
    double? temperature,
    int? maxTokens,
    Map<String, String>? promptVariables,
    Map<String, String>? defaultSettings,
    String? systemPromptType,
  }) async {
    final currentConfig = await loadConfig();

    _config = PromptConfig(
      modelName: modelName ?? currentConfig.modelName,
      temperature: temperature ?? currentConfig.temperature,
      maxTokens: maxTokens ?? currentConfig.maxTokens,
      promptVariables: promptVariables ?? currentConfig.promptVariables,
      defaultSettings: defaultSettings ?? currentConfig.defaultSettings,
      systemPromptType: systemPromptType ?? currentConfig.systemPromptType,
    );

    await _saveConfig();
  }

  static Future<Map<String, String>> getPromptVariables() async {
    final config = await loadConfig();
    return config.promptVariables;
  }

  static Future<Map<String, String>> getDefaultSettings() async {
    final config = await loadConfig();
    return config.defaultSettings;
  }

  static Future<String> getModelName() async {
    final config = await loadConfig();
    return config.modelName;
  }

  static Future<double> getTemperature() async {
    final config = await loadConfig();
    return config.temperature;
  }

  static Future<int> getMaxTokens() async {
    final config = await loadConfig();
    return config.maxTokens;
  }

  static Future<String> getSystemPromptType() async {
    final config = await loadConfig();
    return config.systemPromptType;
  }
}
