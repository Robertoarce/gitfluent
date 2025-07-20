# Language Change Flow Diagram

This diagram shows how language changes are updated in the Flutter translation application.

```mermaid
graph TD
    A[User Opens Settings Screen] --> B[Language Settings Section]
    B --> C{User Selects Language Type}
    
    C -->|Target Language| D[setTargetLanguage called]
    C -->|Native Language| E[setNativeLanguage called]
    C -->|Support Language 1| F[setSupportLanguage1 called]
    C -->|Support Language 2| G[setSupportLanguage2 called]
    
    D --> H[Update _targetLanguage field]
    E --> I[Update _nativeLanguage field]
    F --> J[Update _supportLanguage1 field]
    G --> K[Update _supportLanguage2 field]
    
    H --> L[Save to SharedPreferences<br/>'target_language']
    I --> M[Save to SharedPreferences<br/>'native_language']
    J --> N[Save to SharedPreferences<br/>'support_language_1']
    K --> O[Save to SharedPreferences<br/>'support_language_2']
    
    L --> P[notifyListeners called]
    M --> P
    N --> P
    O --> P
    
    P --> Q[UI Updates via Consumer<LanguageSettings>]
    Q --> R[Chat Service Uses New Language Settings]
    Q --> S[Vocabulary Service Uses New Language Settings]
    Q --> T[Other Dependent Services Updated]
    
    U[App Startup] --> V[LanguageSettings.init called]
    V --> W[_loadLanguages from SharedPreferences]
    W --> X[_findLanguageByCode for each saved language]
    X --> Y[Set default languages if none exist]
    Y --> Z[notifyListeners - Initial UI Setup]
    
    style A fill:#e1f5fe
    style P fill:#4caf50,color:#fff
    style Q fill:#ff9800,color:#fff
    style V fill:#9c27b0,color:#fff
```

## Key Components

- **LanguageSettings** (`lib/services/language_settings_service.dart:11`) - Core service managing language state
- **SettingsScreen** (`lib/screens/settings_screen.dart:63`) - UI for language selection
- **SharedPreferences** - Persistent storage for language preferences

## Flow Process

1. User interaction triggers setter methods (lines 93-123 in language_settings_service.dart)
2. Language codes are persisted to SharedPreferences
3. `notifyListeners()` updates all UI consumers
4. Dependent services (ChatService, VocabularyService) receive the changes
5. On app startup, preferences are loaded via `init()` method (line 48)

The system uses Flutter's Provider pattern with `ChangeNotifier` to propagate language changes throughout the application.