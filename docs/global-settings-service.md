# GlobalSettingsService Documentation

The `GlobalSettingsService` is a centralized configuration management system that loads settings from `prompt_config.yaml` and provides a single source of truth for all application configuration.

## 🎯 Purpose

- **Centralized Configuration**: Single point of access for all app settings
- **YAML-Driven Defaults**: Uses `prompt_config.yaml` as the source of truth
- **Global Accessibility**: Available anywhere in the app via singleton pattern
- **Runtime Updates**: Settings can be modified and persisted during runtime
- **Type Safety**: Strongly typed configuration models

## 🏗️ Architecture

### Configuration Models

```dart
// Main configuration container
GlobalConfig
├── ModelConfig              // AI model settings (name, temperature, tokens)
├── ConversationConfig       // Conversation-specific settings
├── LanguageConfig          // Language preferences
├── Map<String, String>     // Prompt variables
└── String                  // System prompt type
```

### Service Features

- **Singleton Pattern**: Single global instance
- **Change Notifications**: Extends `ChangeNotifier` for reactive updates
- **Persistence**: Saves changes to `SharedPreferences`
- **Fallback Handling**: Graceful degradation when config fails to load
- **Error Recovery**: Comprehensive error handling and logging

## 🚀 Quick Start

### 1. Initialization

The service is automatically initialized in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging first
  await LoggingService().init();

  // Initialize global settings
  await GlobalSettingsService.initialize();

  runApp(MyApp());
}
```

### 2. Basic Usage

```dart
import '../services/global_settings_service.dart';

// Access global instance
final config = globalSettings.config;

// Use convenience getters
final modelName = globalSettings.model.name;
final targetLanguage = globalSettings.languages.targetLanguage;
final variables = globalSettings.languageVariables;
```

### 3. Updating Settings

```dart
// Update model configuration
await globalSettings.updateModel(
  name: 'gemini-1.5-pro',
  temperature: 0.7,
  maxTokens: 4096,
);

// Update language settings
await globalSettings.updateLanguages(
  targetLanguage: 'fr',
  nativeLanguage: 'en',
);

// Update conversation settings
await globalSettings.updateConversation(
  systemPromptType: 'structured_conversation_advanced',
);
```

## 📋 Configuration Reference

### Model Configuration (`ModelConfig`)

```yaml
model:
  name: gemini-2.0-flash # AI model name
  temperature: 0.0 # Response randomness (0.0-1.0)
  max_tokens: 2048 # Maximum response length
```

**Usage:**

```dart
final model = globalSettings.model;
print('Using model: ${model.name}');
print('Temperature: ${model.temperature}');
print('Max tokens: ${model.maxTokens}');
```

### Conversation Configuration (`ConversationConfig`)

```yaml
conversation:
  model:
    name: gemini-2.0-flash
    temperature: 0.0
    max_tokens: 2048
  system_prompt_type: structured_conversation
```

**Usage:**

```dart
final conversation = globalSettings.conversation;
print('Conversation model: ${conversation.model.name}');
print('Prompt type: ${conversation.systemPromptType}');
```

### Language Configuration (`LanguageConfig`)

```yaml
default_settings:
  target_language: it # Language being learned
  native_language: en # User's native language
  support_language_1: es # Additional support language
  support_language_2: fr # Additional support language
```

**Usage:**

```dart
final languages = globalSettings.languages;
print('Learning: ${languages.targetLanguage}');
print('Native: ${languages.nativeLanguage}');

// Get as variables for prompt formatting
final variables = globalSettings.languageVariables;
// Returns: {'target_language': 'it', 'native_language': 'en', ...}
```

### Prompt Variables

```yaml
prompt_variables:
  target_language: target_language
  native_language: native_language
  support_language_1: support_language_1
  support_language_2: support_language_2
```

**Usage:**

```dart
final promptType = globalSettings.systemPromptType;
final variables = globalSettings.languageVariables;
final formattedPrompt = Prompts.getPrompt(promptType, variables: variables);
```

## 🔄 Reactive Updates

### Listening to Changes

```dart
class MyService {
  void init() {
    // Listen to all configuration changes
    globalSettings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    print('Settings updated!');
    final newModel = globalSettings.model.name;
    // React to changes...
  }

  void dispose() {
    globalSettings.removeListener(_onSettingsChanged);
  }
}
```

### Widget Integration

```dart
class SettingsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalSettingsService>(
      builder: (context, settings, child) {
        final config = settings.config;

        return Column(
          children: [
            Text('Model: ${config.model.name}'),
            Text('Temperature: ${config.model.temperature}'),
            ElevatedButton(
              onPressed: () async {
                await settings.updateModel(temperature: 0.5);
              },
              child: Text('Update Temperature'),
            ),
          ],
        );
      },
    );
  }
}
```

## ⚙️ Advanced Usage

### Error Handling

```dart
Future<void> safeConfigAccess() async {
  try {
    // Check initialization status
    if (!globalSettings.isInitialized) {
      await GlobalSettingsService.initialize();
    }

    final config = globalSettings.config;
    // Use configuration safely...

  } catch (e) {
    if (e is StateError) {
      print('Service not initialized');
    } else {
      print('Configuration error: $e');
    }
  }
}
```

### Reset and Cache Management

```dart
// Clear cached settings
await globalSettings.clearCache();

// Reset to YAML defaults
await globalSettings.resetToDefaults();

// This will reload from prompt_config.yaml
```

### Service Integration

```dart
class ChatService {
  late ModelConfig _modelConfig;

  Future<void> init() async {
    // Load initial configuration
    _modelConfig = globalSettings.model;

    // Listen for changes
    globalSettings.addListener(_onConfigChanged);

    _initializeAIModel();
  }

  void _onConfigChanged() {
    _modelConfig = globalSettings.model;
    _reinitializeAIModel();
  }

  void _initializeAIModel() {
    // Use _modelConfig.name, _modelConfig.temperature, etc.
  }
}
```

## 🔧 Migration Guide

### From PromptConfigService

**Old:**

```dart
final config = await PromptConfigService.loadConfig();
final modelName = config.modelName;
final temperature = config.temperature;
final variables = config.defaultSettings;
```

**New:**

```dart
final modelName = globalSettings.model.name;
final temperature = globalSettings.model.temperature;
final variables = globalSettings.languageVariables;
```

### From Multiple Config Sources

**Old:**

```dart
final promptConfig = await PromptConfigService.loadConfig();
final userSettings = await SettingsService.loadLanguageSettings();
final variables = _combineSettings(promptConfig, userSettings);
```

**New:**

```dart
final variables = globalSettings.languageVariables;
```

## 🏠 Configuration Structure

The service loads from `assets/config/prompt_config.yaml`:

```yaml
# Main chat model configuration
model:
  name: gemini-2.0-flash
  temperature: 0.0
  max_tokens: 2048

# Conversation-specific configuration
conversation:
  model:
    name: gemini-2.0-flash
    temperature: 0.0
    max_tokens: 2048
  system_prompt_type: structured_conversation

# Prompt variable mappings
prompt_variables:
  target_language: target_language
  native_language: native_language
  support_language_1: support_language_1
  support_language_2: support_language_2

# Default language settings
default_settings:
  target_language: it
  native_language: en
  support_language_1: es
  support_language_2: fr

# Default system prompt type
system_prompt_type: base
```

## 🎯 Benefits

### For Developers

- **Single Source of Truth**: No more hunting through multiple config files
- **Type Safety**: Compile-time checking of configuration access
- **Hot Reloading**: Changes propagate automatically through the app
- **Easy Testing**: Mock or override settings for tests

### For Users

- **Persistent Settings**: Changes are saved and restored between sessions
- **Immediate Updates**: UI reflects changes instantly
- **Reliable Defaults**: Always falls back to working configuration

### For Maintenance

- **Centralized**: All configuration logic in one place
- **Traceable**: Comprehensive logging of all configuration changes
- **Recoverable**: Reset to defaults when things go wrong

## 🧪 Testing

```dart
// In tests, you can mock or override settings
setUp(() async {
  await GlobalSettingsService.initialize();
});

tearDown(() async {
  await globalSettings.resetToDefaults();
});

test('should use updated model configuration', () async {
  await globalSettings.updateModel(name: 'test-model');
  expect(globalSettings.model.name, equals('test-model'));
});
```

## 🚦 Best Practices

1. **Initialize Early**: Call `GlobalSettingsService.initialize()` in `main()`
2. **Check Initialization**: Use `globalSettings.isInitialized` when in doubt
3. **Handle Errors**: Wrap configuration access in try-catch blocks
4. **Clean Up Listeners**: Remove listeners in `dispose()` methods
5. **Use Convenience Getters**: Prefer `globalSettings.model` over `globalSettings.config.model`
6. **Update Atomically**: Use the provided update methods rather than manual config building

## 📚 Related Services

- **PromptService**: Uses `globalSettings.languageVariables` for prompt formatting
- **ChatService**: Accesses `globalSettings.model` for AI configuration
- **ConversationService**: Uses `globalSettings.conversation` for specialized settings
- **LoggingService**: Logs all configuration changes and errors
