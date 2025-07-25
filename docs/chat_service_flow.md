# Chat Service Flow Diagram

This diagram illustrates the key functionalities and interactions within the `ChatService`.

```mermaid
graph TD
    A[App Startup] --> B{MultiProvider in main.dart}
    B --> C[Create SettingsService]
    B --> D[Create ChatService]

    C --> C1[SettingsService.init]
    C1 --> C2[Load AI Provider & other settings from SharedPreferences]
    C1 --> C3[Notify Listeners]

    D --> D1[ChatService.init]
    D1 --> D2[Call _initializeConfig]
    D1 --> D3[Call _initializeAI]
    D1 --> D4[Listen to SettingsService changes]

    D2 --> D2_1[PromptConfigService.init]
    D2_1 --> D2_2[Load PromptConfig from YAML/SharedPreferences]
    D2_2 --> D2_3[Set _systemPrompt based on config and language settings]

    D3 --> D3_1[Get current AIProvider from SettingsService]
    D3_1 --> D3_2[Call _updateSystemPromptWithLanguages]
    D3_2 --> D3_3{Switch on AI Provider}
    D3_3 -->|OpenAI| D3_4[Initialize ChatOpenAI with API key & config]
    D3_3 -->|Gemini| D3_5[Initialize GenerativeModel with API key & config]
    D3_4 --> D3_6[Add System Message to _chatHistory]
    D3_5 --> D3_6
    D3_6 --> D3_7[Notify Listeners]

    E[User Types Message] --> F[Presses Send / Shift+Enter]
    F --> G[ChatScreen._sendMessage called]
    G --> H[ChatService.sendMessage called]

    H --> I[Add User Message to _messages & _chatHistory]
    H --> J[Set _isLoading   true Notify Listeners - UI shows loading ]

    J --> K{Determine current AI Provider}
    K -->|OpenAI| L[Call _openAILlm.invoke with constructed prompt]
    K -->|Gemini| M[Call _geminiModel.generateContent with constructed prompt]

    L --> N[Receive LLM Response -reply]
    M --> N

    N --> O[Call _getVocabFromLLMResponse - extracts JSON & formats]
    O --> P[Add Assistant Message to _messages & _chatHistory]
    P --> Q[Set _isLoading = false Notify Listeners - UI updates]

    R[Clear Chat] --> S[ChatService.clearChat]
    S --> T[Clear _messages & _chatHistory]
    T --> U[Re-add System Message]
    U --> V[Notify Listeners]

    style A fill:#e1f5fe
    style D fill:#c8e6c9
    style H fill:#bbdefb
    style N fill:#ffe0b2
    style O fill:#ffccbc
    style Q fill:#a5d6a7
    style S fill:#cfd8dc
```

## Key Components and Flow Description

- **Initialization**: The `ChatService` is initialized during app startup via `MultiProvider`. It depends on `SettingsService` to load AI provider details and prompt configurations from `PromptConfigService`.
- **AI Initialization**: Based on user settings, either OpenAI or Gemini models are initialized. A system prompt, customized by language settings, is set for the chat history.
- **Sending Messages**: When a user sends a message, it's added to the chat history, and a loading indicator appears. The message, along with previous conversation context, is sent to the selected LLM.
- **Response Processing**: The LLM's response is received and then processed by `_getVocabFromLLMResponse` to extract vocabulary (if present) and format the text for display. The assistant's reply is then added to the chat history, and the UI updates.
- **Chat Clearing**: The `clearChat` method allows the user to clear the current conversation history, resetting it to the initial system prompt.
