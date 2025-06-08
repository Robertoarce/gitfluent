import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

enum LogCategory {
  appLifecycle,
  database,
  network,
  supabase,
  llm,
  uiEvents,
  chatService,
  conversationService,
  settingsService,
}

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  Map<String, dynamic> _config = {};

  Future<void> init() async {
    try {
      final configString =
          await rootBundle.loadString('assets/config/log_config.yaml');
      final yamlMap = loadYaml(configString);
      if (yamlMap != null && yamlMap['logging'] is YamlMap) {
        _config = _convertYamlMapToMap(yamlMap['logging']);
      }
    } catch (e) {
      developer.log('Error loading log_config.yaml: $e',
          name: 'LoggingService');
      // Default to all logs being disabled if config fails to load
      _config = {'enabled': false};
    }
  }

  bool _isLogEnabled(LogCategory category) {
    if (!(_config['enabled'] ?? false)) {
      return false;
    }

    switch (category) {
      case LogCategory.appLifecycle:
        return _config['app_lifecycle'] ?? false;
      case LogCategory.database:
        return _config['database'] ?? false;
      case LogCategory.network:
        return _config['network'] ?? false;
      case LogCategory.supabase:
        return _config['supabase'] ?? false;
      case LogCategory.uiEvents:
        return _config['ui_events'] ?? false;
      case LogCategory.chatService:
        return _config['chat_service'] ?? false;
      case LogCategory.conversationService:
        return _config['conversation_service'] ?? false;
      case LogCategory.settingsService:
        return _config['settings_service'] ?? false;
      case LogCategory.llm:
        final llmConfig = _config['llm'];
        if (llmConfig is Map<String, dynamic>) {
          return llmConfig['enabled'] ?? false;
        }
        return false;
    }
  }

  void log(LogCategory category, String message, {bool isError = false}) {
    if (_isLogEnabled(category)) {
      final logName = isError ? '${category.name}.error' : category.name;
      developer.log(message, name: logName);
    }
  }

  void logLlm({String? sent, String? received}) {
    if (_isLogEnabled(LogCategory.llm)) {
      final llmConfig = _config['llm'];
      if (llmConfig is Map) {
        if ((llmConfig['log_sent'] ?? false) && sent != null) {
          developer.log(sent, name: 'llm.sent');
        }
        if ((llmConfig['log_received'] ?? false) && received != null) {
          developer.log(received, name: 'llm.received');
        }
      }
    }
  }

  Map<String, dynamic> _convertYamlMapToMap(YamlMap yamlMap) {
    final map = <String, dynamic>{};
    for (var entry in yamlMap.entries) {
      if (entry.value is YamlMap) {
        map[entry.key.toString()] = _convertYamlMapToMap(entry.value);
      } else {
        map[entry.key.toString()] = entry.value;
      }
    }
    return map;
  }
}

// Global instance of the logging service
final logger = LoggingService();
