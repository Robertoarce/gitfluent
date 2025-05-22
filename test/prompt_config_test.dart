import 'package:flutter_test/flutter_test.dart';
import 'package:llm_chat_app/services/prompt_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromptConfigService Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      await PromptConfigService.init();
      PromptConfigService.clearCache();
    });

    test('Loads default configuration from YAML', () async {
      final config = await PromptConfigService.loadConfig();
      
      expect(config.modelName, 'gemini-2.0-flash');
      expect(config.temperature, 0.0);
      expect(config.maxTokens, 2048);
      expect(config.systemPromptType, 'defaultSystemPrompt');
      
      // Verify default settings
      expect(config.defaultSettings['target_language'], 'it');
      expect(config.defaultSettings['native_language'], 'en');
      expect(config.defaultSettings['support_language_1'], 'es');
      expect(config.defaultSettings['support_language_2'], 'fr');
    });

    test('Updates configuration and persists changes', () async {
      // First load default config
      final initialConfig = await PromptConfigService.loadConfig();
      
      // Update configuration
      await PromptConfigService.updateConfig(
        temperature: 0.5,
        maxTokens: 1024,
        systemPromptType: 'vocabulary',
        defaultSettings: {
          'target_language': 'fr',
          'native_language': 'en',
          'support_language_1': 'es',
          'support_language_2': 'de',
        },
      );
      
      // Load config again to verify changes
      final updatedConfig = await PromptConfigService.loadConfig();
      
      expect(updatedConfig.temperature, 0.5);
      expect(updatedConfig.maxTokens, 1024);
      expect(updatedConfig.systemPromptType, 'vocabulary');
      expect(updatedConfig.defaultSettings['target_language'], 'fr');
      expect(updatedConfig.defaultSettings['support_language_2'], 'de');
      
      // Clear cache and reload to verify persistence
      PromptConfigService.clearCache();
      final reloadedConfig = await PromptConfigService.loadConfig();
      
      expect(reloadedConfig.temperature, 0.5);
      expect(reloadedConfig.maxTokens, 1024);
      expect(reloadedConfig.systemPromptType, 'vocabulary');
      expect(reloadedConfig.defaultSettings['target_language'], 'fr');
    });

    test('Partial updates preserve existing values', () async {
      // First load default config
      final initialConfig = await PromptConfigService.loadConfig();
      final initialTemperature = initialConfig.temperature;
      final initialMaxTokens = initialConfig.maxTokens;
      
      // Update only temperature
      await PromptConfigService.updateConfig(
        temperature: 0.7,
      );
      
      // Load config again to verify changes
      final updatedConfig = await PromptConfigService.loadConfig();
      
      expect(updatedConfig.temperature, 0.7);
      expect(updatedConfig.maxTokens, initialMaxTokens);
      expect(updatedConfig.modelName, initialConfig.modelName);
      expect(updatedConfig.systemPromptType, initialConfig.systemPromptType);
    });
  });
} 