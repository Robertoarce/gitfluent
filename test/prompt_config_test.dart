import 'package:flutter_test/flutter_test.dart';
import 'package:llm_chat_app/services/prompt_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llm_chat_app/services/prompts.dart';

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

  group('Prompts Multi-language Tests', () {
    test('getInitialBotMessage returns correct translations', () {
      // Test some key languages
      expect(Prompts.getInitialBotMessage('en').contains('Hello'), true);
      expect(Prompts.getInitialBotMessage('es').contains('Hola'), true);
      expect(Prompts.getInitialBotMessage('fr').contains('Bonjour'), true);
      expect(Prompts.getInitialBotMessage('de').contains('Hallo'), true);
      expect(Prompts.getInitialBotMessage('it').contains('Ciao'), true);
      expect(Prompts.getInitialBotMessage('pt').contains('Olá'), true);
      expect(Prompts.getInitialBotMessage('ru').contains('Привет'), true);
      expect(Prompts.getInitialBotMessage('zh').contains('你好'), true);
      expect(Prompts.getInitialBotMessage('ja').contains('こんにちは'), true);
      expect(Prompts.getInitialBotMessage('ko').contains('안녕하세요'), true);
    });

    test('getInitialBotMessage fallback to English for unknown language codes',
        () {
      expect(Prompts.getInitialBotMessage('unknown'),
          "Hello! I'm your conversation partner. How can I help you practice today?");
      expect(Prompts.getInitialBotMessage(''),
          "Hello! I'm your conversation partner. How can I help you practice today?");
    });

    test(
        'getInitialBotMessage returns non-empty strings for all supported languages',
        () {
      final supportedLanguages = [
        'en',
        'es',
        'fr',
        'de',
        'it',
        'pt',
        'ru',
        'zh',
        'ja',
        'ko',
        'nl',
        'el',
        'he',
        'hi',
        'ga',
        'pl',
        'sv',
        'vi'
      ];

      for (final lang in supportedLanguages) {
        final message = Prompts.getInitialBotMessage(lang);
        expect(message.isNotEmpty, true,
            reason: 'Message should not be empty for language: $lang');
        expect(message.length > 10, true,
            reason: 'Message should be meaningful length for language: $lang');
      }
    });
  });
}
