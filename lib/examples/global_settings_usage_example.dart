import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/global_settings_service.dart';
import '../services/prompts.dart';

/// Example showing various ways to use the GlobalSettingsService
class GlobalSettingsUsageExample {
  /// Example 1: Direct access to global settings
  void directAccessExample() {
    // Access the global instance directly
    final config = globalSettings.config;

    print('Model name: ${config.model.name}');
    print('Temperature: ${config.model.temperature}');
    print('Target language: ${config.defaultSettings.targetLanguage}');
    print('Native language: ${config.defaultSettings.nativeLanguage}');
  }

  /// Example 2: Using convenience getters
  void convenienceGettersExample() {
    // Use the convenience getters for common configurations
    final modelConfig = globalSettings.model;
    final conversationConfig = globalSettings.conversation;
    final languages = globalSettings.languages;

    print('Chat model: ${modelConfig.name}');
    print('Conversation model: ${conversationConfig.model.name}');
    print('Conversation prompt type: ${conversationConfig.systemPromptType}');
    print(
        'Languages: ${languages.targetLanguage} -> ${languages.nativeLanguage}');
  }

  /// Example 3: Getting formatted variables for prompts
  void promptVariablesExample() {
    // Get variables ready for prompt formatting
    final variables = globalSettings.languageVariables;

    // Use with existing prompt service
    final promptType = globalSettings.systemPromptType;
    final formattedPrompt = Prompts.getPrompt(promptType, variables: variables);

    print('Variables: $variables');
    print('Prompt type: $promptType');
    print('Formatted prompt length: ${formattedPrompt.length}');
  }

  /// Example 4: Updating settings programmatically
  Future<void> updateSettingsExample() async {
    // Update model settings
    await globalSettings.updateModel(
      name: 'gemini-1.5-pro',
      temperature: 0.7,
      maxTokens: 4096,
    );

    // Update language settings
    await globalSettings.updateLanguages(
      targetLanguage: 'fr',
      nativeLanguage: 'en',
      supportLanguage1: 'es',
      supportLanguage2: 'de',
    );

    // Update conversation settings
    await globalSettings.updateConversation(
      modelName: 'gemini-1.5-flash',
      temperature: 0.5,
      systemPromptType: 'structured_conversation_advanced',
    );

    print('Settings updated successfully');
  }

  /// Example 5: Listening to settings changes
  void listeningExample() {
    // Listen to changes in global settings
    globalSettings.addListener(() {
      print('Global settings changed!');
      print('New target language: ${globalSettings.languages.targetLanguage}');
      print('New model: ${globalSettings.model.name}');
    });
  }

  /// Example 6: Using in a service class
  Future<void> serviceIntegrationExample() async {
    // Example of how a service might use global settings
    final ExampleService service = ExampleService();
    await service.initializeWithGlobalSettings();
    service.performOperation();
  }

  /// Example 7: Using in a widget
  Widget widgetExample() {
    return Consumer<GlobalSettingsService>(
      builder: (context, settings, child) {
        final config = settings.config;

        return Column(
          children: [
            Text('Model: ${config.model.name}'),
            Text('Temperature: ${config.model.temperature}'),
            Text('Target Language: ${config.defaultSettings.targetLanguage}'),
            ElevatedButton(
              onPressed: () async {
                await settings.updateLanguages(
                  targetLanguage: 'de',
                );
              },
              child: const Text('Change to German'),
            ),
          ],
        );
      },
    );
  }

  /// Example 8: Error handling and validation
  Future<void> errorHandlingExample() async {
    try {
      // Check if initialized before use
      if (!globalSettings.isInitialized) {
        await GlobalSettingsService.initialize();
      }

      // Safe access to config
      final config = globalSettings.config;
      print('Config loaded: ${config.model.name}');
    } catch (e) {
      print('Error accessing global settings: $e');

      // Handle specific error cases
      if (e is StateError) {
        print('Service not initialized properly');
      }
    }
  }

  /// Example 9: Reset and cache management
  Future<void> resetExample() async {
    // Clear cache
    await globalSettings.clearCache();

    // Reset to defaults from YAML
    await globalSettings.resetToDefaults();

    print('Settings reset to defaults');
  }
}

/// Example service showing how to integrate with GlobalSettingsService
class ExampleService {
  late ModelConfig _modelConfig;
  late LanguageConfig _languageConfig;

  Future<void> initializeWithGlobalSettings() async {
    // Load configuration from global settings
    _modelConfig = globalSettings.model;
    _languageConfig = globalSettings.languages;

    // Listen for changes
    globalSettings.addListener(_onSettingsChanged);

    print('ExampleService initialized with:');
    print('  Model: ${_modelConfig.name}');
    print(
        '  Languages: ${_languageConfig.targetLanguage} -> ${_languageConfig.nativeLanguage}');
  }

  void _onSettingsChanged() {
    // React to settings changes
    _modelConfig = globalSettings.model;
    _languageConfig = globalSettings.languages;

    print('ExampleService updated with new settings');
    _reinitializeWithNewSettings();
  }

  void _reinitializeWithNewSettings() {
    // Reinitialize any components that depend on settings
    print('Reinitializing with:');
    print('  New model: ${_modelConfig.name}');
    print(
        '  New languages: ${_languageConfig.targetLanguage} -> ${_languageConfig.nativeLanguage}');
  }

  void performOperation() {
    // Use the configuration in your operations
    final variables = globalSettings.languageVariables;
    final promptType = globalSettings.systemPromptType;

    print('Performing operation with:');
    print('  Prompt type: $promptType');
    print('  Variables: $variables');
    print('  Model: ${_modelConfig.name} (temp: ${_modelConfig.temperature})');
  }

  void dispose() {
    globalSettings.removeListener(_onSettingsChanged);
  }
}

/// Example showing integration with existing services
class ChatServiceExample {
  Future<void> migrateFromOldService() async {
    // Old way (multiple config services)
    // final config = await PromptConfigService.loadConfig();
    // final settings = await SettingsService.loadLanguageSettings();

    // New way (single global service)
    final modelConfig = globalSettings.model;
    final conversationConfig = globalSettings.conversation;
    final languageVariables = globalSettings.languageVariables;
    final promptType = globalSettings.systemPromptType;

    // Use in existing code patterns
    final prompt = Prompts.getPrompt(promptType, variables: languageVariables);

    print('Migrated to global settings:');
    print('  Model: ${modelConfig.name}');
    print('  Conversation model: ${conversationConfig.model.name}');
    print('  Prompt length: ${prompt.length}');
  }
}
