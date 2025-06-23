import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'logging_service.dart';

/// Model for AI model configuration
class ModelConfig {
  final String name;
  final double temperature;
  final int maxTokens;

  const ModelConfig({
    required this.name,
    required this.temperature,
    required this.maxTokens,
  });

  factory ModelConfig.fromYaml(dynamic yaml) {
    return ModelConfig(
      name: yaml['name']?.toString() ?? 'gemini-2.0-flash',
      temperature: (yaml['temperature'] as num?)?.toDouble() ?? 0.0,
      maxTokens: (yaml['max_tokens'] as num?)?.toInt() ?? 2048,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'temperature': temperature,
        'max_tokens': maxTokens,
      };

  ModelConfig copyWith({
    String? name,
    double? temperature,
    int? maxTokens,
  }) =>
      ModelConfig(
        name: name ?? this.name,
        temperature: temperature ?? this.temperature,
        maxTokens: maxTokens ?? this.maxTokens,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          temperature == other.temperature &&
          maxTokens == other.maxTokens;

  @override
  int get hashCode => name.hashCode ^ temperature.hashCode ^ maxTokens.hashCode;
}

/// Model for conversation-specific configuration
class ConversationConfig {
  final ModelConfig model;
  final String systemPromptType;

  const ConversationConfig({
    required this.model,
    required this.systemPromptType,
  });

  factory ConversationConfig.fromYaml(dynamic yaml) {
    return ConversationConfig(
      model: ModelConfig.fromYaml(yaml['model']),
      systemPromptType:
          yaml['system_prompt_type']?.toString() ?? 'structured_conversation',
    );
  }

  Map<String, dynamic> toJson() => {
        'model': model.toJson(),
        'system_prompt_type': systemPromptType,
      };

  ConversationConfig copyWith({
    ModelConfig? model,
    String? systemPromptType,
  }) =>
      ConversationConfig(
        model: model ?? this.model,
        systemPromptType: systemPromptType ?? this.systemPromptType,
      );
}

/// Model for language settings
class LanguageConfig {
  final String targetLanguage;
  final String nativeLanguage;
  final String supportLanguage1;
  final String supportLanguage2;

  const LanguageConfig({
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.supportLanguage1,
    required this.supportLanguage2,
  });

  factory LanguageConfig.fromYaml(dynamic yaml) {
    return LanguageConfig(
      targetLanguage: yaml['target_language']?.toString() ?? 'it',
      nativeLanguage: yaml['native_language']?.toString() ?? 'en',
      supportLanguage1: yaml['support_language_1']?.toString() ?? 'es',
      supportLanguage2: yaml['support_language_2']?.toString() ?? 'fr',
    );
  }

  Map<String, dynamic> toJson() => {
        'target_language': targetLanguage,
        'native_language': nativeLanguage,
        'support_language_1': supportLanguage1,
        'support_language_2': supportLanguage2,
      };

  Map<String, String> toVariables() => {
        'target_language': targetLanguage,
        'native_language': nativeLanguage,
        'support_language_1': supportLanguage1,
        'support_language_2': supportLanguage2,
      };

  LanguageConfig copyWith({
    String? targetLanguage,
    String? nativeLanguage,
    String? supportLanguage1,
    String? supportLanguage2,
  }) =>
      LanguageConfig(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        nativeLanguage: nativeLanguage ?? this.nativeLanguage,
        supportLanguage1: supportLanguage1 ?? this.supportLanguage1,
        supportLanguage2: supportLanguage2 ?? this.supportLanguage2,
      );
}

/// Main configuration model
class GlobalConfig {
  final ModelConfig model;
  final ConversationConfig conversation;
  final Map<String, String> promptVariables;
  final LanguageConfig defaultSettings;
  final String systemPromptType;

  const GlobalConfig({
    required this.model,
    required this.conversation,
    required this.promptVariables,
    required this.defaultSettings,
    required this.systemPromptType,
  });

  factory GlobalConfig.fromYaml(dynamic yaml) {
    final promptVars = yaml['prompt_variables'] as Map<dynamic, dynamic>? ?? {};

    return GlobalConfig(
      model: ModelConfig.fromYaml(yaml['model']),
      conversation: ConversationConfig.fromYaml(yaml['conversation']),
      promptVariables: promptVars.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      defaultSettings: LanguageConfig.fromYaml(yaml['default_settings']),
      systemPromptType: yaml['system_prompt_type']?.toString() ?? 'base',
    );
  }

  Map<String, dynamic> toJson() => {
        'model': model.toJson(),
        'conversation': conversation.toJson(),
        'prompt_variables': promptVariables,
        'default_settings': defaultSettings.toJson(),
        'system_prompt_type': systemPromptType,
      };

  GlobalConfig copyWith({
    ModelConfig? model,
    ConversationConfig? conversation,
    Map<String, String>? promptVariables,
    LanguageConfig? defaultSettings,
    String? systemPromptType,
  }) =>
      GlobalConfig(
        model: model ?? this.model,
        conversation: conversation ?? this.conversation,
        promptVariables: promptVariables ?? this.promptVariables,
        defaultSettings: defaultSettings ?? this.defaultSettings,
        systemPromptType: systemPromptType ?? this.systemPromptType,
      );
}

/// Centralized global settings service
class GlobalSettingsService extends ChangeNotifier {
  static GlobalSettingsService? _instance;
  static const String _configKey = 'global_config';
  static const String _yamlPath = 'assets/config/prompt_config.yaml';

  GlobalConfig? _config;
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  final LoggingService _logger = LoggingService();

  GlobalSettingsService._internal();

  /// Get the global singleton instance
  static GlobalSettingsService get instance {
    _instance ??= GlobalSettingsService._internal();
    return _instance!;
  }

  /// Initialize the service (must be called before first use)
  static Future<void> initialize() async {
    await instance._initialize();
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the current configuration
  GlobalConfig get config {
    if (!_isInitialized || _config == null) {
      throw StateError(
          'GlobalSettingsService not initialized. Call GlobalSettingsService.initialize() first.');
    }
    return _config!;
  }

  /// Get model configuration
  ModelConfig get model => config.model;

  /// Get conversation configuration
  ConversationConfig get conversation => config.conversation;

  /// Get language settings
  LanguageConfig get languages => config.defaultSettings;

  /// Get prompt variables
  Map<String, String> get promptVariables => config.promptVariables;

  /// Get system prompt type
  String get systemPromptType => config.systemPromptType;

  /// Get language variables for prompt formatting
  Map<String, String> get languageVariables =>
      config.defaultSettings.toVariables();

  Future<void> _initialize() async {
    try {
      _logger.log(
          LogCategory.settingsService, 'Initializing GlobalSettingsService');

      _prefs = await SharedPreferences.getInstance();
      await _loadConfiguration();

      _isInitialized = true;
      _logger.log(LogCategory.settingsService,
          'GlobalSettingsService initialized successfully');
    } catch (e) {
      _logger.log(LogCategory.settingsService,
          'Error initializing GlobalSettingsService: $e',
          isError: true);
      rethrow;
    }
  }

  Future<void> _loadConfiguration() async {
    try {
      // Try to load from saved preferences first
      final savedConfig = _prefs?.getString(_configKey);
      if (savedConfig != null) {
        _logger.log(LogCategory.settingsService,
            'Loading config from SharedPreferences');
        final jsonConfig = json.decode(savedConfig) as Map<String, dynamic>;
        _config = GlobalConfig.fromYaml(jsonConfig);
        return;
      }

      // If no saved config, load from YAML file
      _logger.log(
          LogCategory.settingsService, 'Loading config from YAML: $_yamlPath');
      final yamlString = await rootBundle.loadString(_yamlPath);
      final yamlData = loadYaml(yamlString);
      _config = GlobalConfig.fromYaml(yamlData);

      // Save the default config for future use
      await _saveConfiguration();
    } catch (e) {
      _logger.log(
          LogCategory.settingsService, 'Error loading configuration: $e',
          isError: true);

      // Fallback to minimal default configuration
      _config = const GlobalConfig(
        model: ModelConfig(
          name: 'gemini-2.0-flash',
          temperature: 0.0,
          maxTokens: 2048,
        ),
        conversation: ConversationConfig(
          model: ModelConfig(
            name: 'gemini-2.0-flash',
            temperature: 0.0,
            maxTokens: 2048,
          ),
          systemPromptType: 'structured_conversation',
        ),
        promptVariables: {
          'target_language': 'target_language',
          'native_language': 'native_language',
          'support_language_1': 'support_language_1',
          'support_language_2': 'support_language_2',
        },
        defaultSettings: LanguageConfig(
          targetLanguage: 'it',
          nativeLanguage: 'en',
          supportLanguage1: 'es',
          supportLanguage2: 'fr',
        ),
        systemPromptType: 'base',
      );
    }
  }

  Future<void> _saveConfiguration() async {
    if (_config != null && _prefs != null) {
      try {
        final jsonString = json.encode(_config!.toJson());
        await _prefs!.setString(_configKey, jsonString);
        _logger.log(LogCategory.settingsService,
            'Configuration saved to SharedPreferences');
      } catch (e) {
        _logger.log(
            LogCategory.settingsService, 'Error saving configuration: $e',
            isError: true);
      }
    }
  }

  /// Update model configuration
  Future<void> updateModel({
    String? name,
    double? temperature,
    int? maxTokens,
  }) async {
    final updatedModel = config.model.copyWith(
      name: name,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    _config = config.copyWith(model: updatedModel);
    await _saveConfiguration();
    notifyListeners();

    _logger.log(LogCategory.settingsService, 'Model configuration updated');
  }

  /// Update conversation configuration
  Future<void> updateConversation({
    String? modelName,
    double? temperature,
    int? maxTokens,
    String? systemPromptType,
  }) async {
    final updatedConversationModel = config.conversation.model.copyWith(
      name: modelName,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    final updatedConversation = config.conversation.copyWith(
      model: updatedConversationModel,
      systemPromptType: systemPromptType,
    );

    _config = config.copyWith(conversation: updatedConversation);
    await _saveConfiguration();
    notifyListeners();

    _logger.log(
        LogCategory.settingsService, 'Conversation configuration updated');
  }

  /// Update language settings
  Future<void> updateLanguages({
    String? targetLanguage,
    String? nativeLanguage,
    String? supportLanguage1,
    String? supportLanguage2,
  }) async {
    final updatedLanguages = config.defaultSettings.copyWith(
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
      supportLanguage1: supportLanguage1,
      supportLanguage2: supportLanguage2,
    );

    _config = config.copyWith(defaultSettings: updatedLanguages);
    await _saveConfiguration();
    notifyListeners();

    _logger.log(LogCategory.settingsService, 'Language settings updated');
  }

  /// Update system prompt type
  Future<void> updateSystemPromptType(String promptType) async {
    _config = config.copyWith(systemPromptType: promptType);
    await _saveConfiguration();
    notifyListeners();

    _logger.log(LogCategory.settingsService,
        'System prompt type updated to: $promptType');
  }

  /// Reset to default configuration from YAML
  Future<void> resetToDefaults() async {
    try {
      _logger.log(
          LogCategory.settingsService, 'Resetting to default configuration');

      // Clear saved preferences
      await _prefs?.remove(_configKey);

      // Reload from YAML
      await _loadConfiguration();
      notifyListeners();

      _logger.log(
          LogCategory.settingsService, 'Configuration reset to defaults');
    } catch (e) {
      _logger.log(
          LogCategory.settingsService, 'Error resetting to defaults: $e',
          isError: true);
      rethrow;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _prefs?.remove(_configKey);
    _logger.log(LogCategory.settingsService, 'Configuration cache cleared');
  }

  @override
  void dispose() {
    _instance = null;
    super.dispose();
  }
}

/// Global instance for easy access throughout the app
final GlobalSettingsService globalSettings = GlobalSettingsService.instance;
