import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class PromptConfig {
  final String modelName;
  final double temperature;
  final int maxTokens;
  final Map<String, String> promptVariables;
  final Map<String, String> defaultSettings;
  final String systemPromptType;

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
    final Map<String, dynamic> promptVars = Map<String, dynamic>.from(yaml['prompt_variables']);
    final Map<String, dynamic> defaultSettings = Map<String, dynamic>.from(yaml['default_settings']);

    return PromptConfig(
      modelName: model['name'].toString(),
      temperature: (model['temperature'] as num).toDouble(),
      maxTokens: (model['max_tokens'] as num).toInt(),
      promptVariables: promptVars.map((key, value) => MapEntry(key.toString(), value.toString())),
      defaultSettings: defaultSettings.map((key, value) => MapEntry(key.toString(), value.toString())),
      systemPromptType: yaml['system_prompt_type'].toString().trim(),
    );
  }
}

class PromptConfigService {
  static PromptConfig? _config;

  static void clearCache() {
    _config = null;
  }

  static Future<PromptConfig> loadConfig() async {
    try {
      final String yamlString = await rootBundle.loadString('lib/config/prompt_config.yaml');
      final dynamic yamlData = loadYaml(yamlString);
      _config = PromptConfig.fromYaml(yamlData);
      return _config!;
    } catch (e) {
      throw Exception('Failed to load prompt configuration: $e');
    }
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