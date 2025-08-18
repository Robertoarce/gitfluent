<!-- # Prompt Flow Diagram

This diagram shows how the application loads and processes prompts before sending them to the LLM.

```mermaid
graph TD
    Start[main.dart] --> LoadEnv[Load .env file]

    LoadEnv --> InitServices[Initialize Services]
    InitServices --> SettingsService[SettingsService.init]
    InitServices --> LanguageSettings[LanguageSettings.init]
    InitServices --> VocabularyService[VocabularyService.init]

    SettingsService --> CreateChatService[Create ChatService]
    CreateChatService --> InitConfig[ChatService._initializeConfig]

    InitConfig --> LoadYaml[Load config.yaml]
    LoadYaml --> ConfigService[PromptConfigService.loadConfig]
    ConfigService --> CheckCache{Check Cache}
    CheckCache -->|Cache Hit| ReturnCache[Return Cached Config]
    CheckCache -->|Cache Miss| LoadPrefs[Load from SharedPreferences]
    LoadPrefs -->|Found| ParseJSON[Parse JSON Config]
    LoadPrefs -->|Not Found| LoadYamlFile[Load YAML File]
    LoadYamlFile --> ParseYaml[Parse YAML Config]
    ParseYaml --> SavePrefs[Save to SharedPreferences]
    SavePrefs --> ReturnConfig[Return Config]
    ParseJSON --> ReturnConfig
    ReturnCache --> GetPromptType[Get prompt_type from config]
    ReturnConfig --> GetPromptType
    GetPromptType --> GetVars[Get language variables]
    GetVars --> PromptsGet[Prompts.getPrompt]
    PromptsGet --> CheckType{Check prompt type}
    CheckType -->|Found| ReturnPrompt[Return prompt]
    CheckType -->|Not Found| ThrowError[Throw Exception]
    ReturnPrompt --> FormatVars[Format prompt with variables]
    FormatVars --> SendLLM[Send to LLM]
    ThrowError --> UseDefault[Use default prompt]
    UseDefault --> SendLLM

    subgraph "Application Initialization"
        Start
        LoadEnv
        InitServices
        SettingsService
        LanguageSettings
        VocabularyService
        CreateChatService
    end

    subgraph "Configuration Loading"
        InitConfig
        LoadYaml
        ConfigService
        CheckCache
        ReturnCache
        LoadPrefs
        ParseJSON
        LoadYamlFile
        ParseYaml
        SavePrefs
        ReturnConfig
    end

    subgraph "Prompt Processing"
        GetPromptType
        GetVars
        PromptsGet
        CheckType
        ReturnPrompt
        ThrowError
        FormatVars
        SendLLM
        UseDefault
    end

```

## Initialization Flow

1. **Application Start** (`lib/main.dart`)
   - Load `.env` file for API keys
   - Initialize core services:
     - `SettingsService`
     - `LanguageSettings`
     - `VocabularyService`
   - Create `ChatService` with `SettingsService`

2. **Configuration Loading** (`lib/services/prompt_config_service.dart`)
   - `config.yaml` → `lib/config/config.yaml`
   - Cache check → `_config != null`
   - SharedPreferences → `_prefs.getString(_configKey)`
   - YAML loading → `rootBundle.loadString`
   - Config saving → `_saveConfig()`

3. **Prompt Processing**
   - ChatService → `lib/services/chat_service.dart`
     - Config initialization → `_initializeConfig()`
     - Prompt type → `_config?.systemPromptType`
     - Language variables → `defaultSettings` map
   - Prompts → `lib/services/prompts.dart`
     - Prompt lookup → `_promptMap[type.toLowerCase()]`
     - Variable formatting → `formatPromptWithVariables`
     - LLM sending → `_geminiModel.generateContent`

## Variables and Types

1. **Configuration Variables** (from `config.yaml`)
   - `target_language` (default: 'it')
   - `native_language` (default: 'en')
   - `support_language_1` (default: 'es')
   - `support_language_2` (default: 'fr')

2. **Available Prompt Types** (in `lib/services/prompts.dart`)
   - `fixed_prompt` (default language learning format)
   - `defaultSystemPrompt` (basic language learning format)
   - `qwen_1` (detailed translation format)
   - `example` (variable-based format)  -->
```
