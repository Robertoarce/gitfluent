import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'dart:convert';

import 'prompts.dart';
import 'prompt_config_service.dart';
import 'settings_service.dart';
import 'logging_service.dart';
import '../models/conversation_response.dart';

// Import conversation_screen.dart with a prefix
import '../screens/conversation_screen.dart' as convo_ui;

class ConversationService extends ChangeNotifier {
  final List<convo_ui.ChatMessage> _messages = [];
  bool _isLoading = false;
  google_ai.GenerativeModel? _geminiModel;
  final List<ChatMessage> _chatHistory = [];
  final LoggingService _logger = LoggingService();

  final SettingsService _settings;
  PromptConfig? _config;

  List<convo_ui.ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  ConversationService({required SettingsService settings})
      : _settings = settings {
    _initialize();

    // Listen for language settings changes
    _settings.languageSettings.addListener(_onLanguageSettingsChanged);
  }

  Future<void> _initialize() async {
    await _loadConfigAndInitializeModel();
    _addInitialBotMessage();
  }

  Future<void> _loadConfigAndInitializeModel() async {
    _isLoading = true;
    notifyListeners();

    try {
      await PromptConfigService.init();
      PromptConfigService.clearCache();
      _config = await PromptConfigService.loadConfig();

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        _addErrorMessage('Error: GEMINI_API_KEY not found in .env file.');
        return;
      }

      final systemPromptType =
          _config?.conversationSystemPromptType ?? 'structured_conversation';
      final languageSettings = _settings.languageSettings;
      final variables = {
        'target_language': languageSettings?.targetLanguage?.code ??
            _config?.defaultSettings['target_language'] ??
            'en',
        'native_language': languageSettings?.nativeLanguage?.code ??
            _config?.defaultSettings['native_language'] ??
            'en',
        'support_language_1': languageSettings?.nativeLanguage?.code ??
            _config?.defaultSettings['support_language_1'] ??
            'en',
        'support_language_2': languageSettings?.nativeLanguage?.code ??
            _config?.defaultSettings['support_language_2'] ??
            'en',
      };
      final systemPromptText =
          Prompts.getPrompt(systemPromptType, variables: variables);

      _geminiModel = google_ai.GenerativeModel(
        model: _config?.conversationModelName ?? 'gemini-pro',
        apiKey: apiKey,
        generationConfig: google_ai.GenerationConfig(
          temperature: _config?.conversationTemperature ?? 0.7,
          maxOutputTokens: _config?.conversationMaxTokens ?? 2048,
        ),
      );

      _chatHistory.clear();
      // Create a system message
      _chatHistory.add(SystemChatMessage(content: systemPromptText));

      _logger.log(LogCategory.conversationService,
          'ConversationService Gemini model initialized with model: ${_config?.conversationModelName}');
      _logger.log(LogCategory.conversationService,
          'Conversation System Prompt Type: $systemPromptType');
    } catch (e) {
      _logger.log(LogCategory.conversationService,
          'Error initializing ConversationService: $e',
          isError: true);
      _addErrorMessage('Error initializing conversation: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _addInitialBotMessage() {
    // Get the target language from settings, fallback to config, then to 'en'
    final languageSettings = _settings.languageSettings;
    final targetLanguage = languageSettings?.targetLanguage?.code ??
        _config?.defaultSettings['target_language'] ??
        'en';

    final initialBotMessage = convo_ui.ChatMessage(
        id: 'conv_initial_bot_${DateTime.now().millisecondsSinceEpoch}',
        text: Prompts.getInitialBotMessage(targetLanguage),
        isUser: false);
    _messages.add(initialBotMessage);
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _geminiModel == null) return;

    final userMessage = convo_ui.ChatMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isUser: true);
    _messages.add(userMessage);
    // Create a human message
    _chatHistory.add(HumanChatMessage(content: ChatMessageContent.text(text)));
    _isLoading = true;
    notifyListeners();

    ConversationResponse? parsedResponse;
    String rawResponseText = '';

    try {
      final contentHistory =
          _chatHistory.map((msg) => msg.toGoogleContent()).toList();

      _logger.logLlm(sent: text);
      final llmResponse = await _geminiModel!.generateContent(contentHistory);
      rawResponseText = llmResponse.text ?? '';
      _logger.logLlm(received: rawResponseText);

      String displayResponseText = 'Sorry, I could not understand that.';

      if (rawResponseText.isNotEmpty) {
        try {
          final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
          final match = jsonRegex.firstMatch(rawResponseText);
          String jsonToParse = rawResponseText;

          if (match != null && match.group(1) != null) {
            jsonToParse = match.group(1)!.trim();
          }

          final Map<String, dynamic> jsonDecoded = json.decode(jsonToParse);
          parsedResponse = ConversationResponse.fromJson(jsonDecoded);

          StringBuffer sb = StringBuffer();
          sb.writeln("Bot: ${parsedResponse.response}");
          if (parsedResponse.translation.isNotEmpty) {
            sb.writeln("Translation: ${parsedResponse.translation}");
          }
          if (parsedResponse.newVocabulary.isNotEmpty) {
            sb.writeln("\nNew Vocabulary:");
            for (var item in parsedResponse.newVocabulary) {
              sb.writeln(
                  "- ${item.word}: ${item.meaning} (e.g., ${item.example})");
            }
          }
          if (parsedResponse.corrections.isNotEmpty) {
            sb.writeln("\nCorrections:");
            for (var item in parsedResponse.corrections) {
              sb.writeln(
                  "- '${item.incorrect}' -> '${item.correct}' (${item.explanation})");
            }
          }
          if (parsedResponse.followUpQuestion.isNotEmpty) {
            sb.writeln("\nNext: ${parsedResponse.followUpQuestion}");
          }
          displayResponseText = sb.toString();
        } catch (e) {
          parsedResponse = null;
          _logger.log(LogCategory.conversationService,
              'Error parsing LLM JSON response: $e',
              isError: true);
          _logger.log(LogCategory.conversationService,
              'Raw LLM response was: $rawResponseText',
              isError: true);
          displayResponseText = rawResponseText.isEmpty
              ? 'Sorry, I received an empty response.'
              : rawResponseText;
        }
      }

      final botMessage = convo_ui.ChatMessage(
          id: 'llm_${DateTime.now().millisecondsSinceEpoch}',
          text: displayResponseText,
          isUser: false);
      _messages.add(botMessage);

      // Create an AI message
      _chatHistory.add(
          AIChatMessage(content: parsedResponse?.response ?? rawResponseText));
    } catch (e) {
      _logger.log(LogCategory.conversationService,
          'Error sending message to Gemini: $e',
          isError: true);
      _addErrorMessage('Error communicating with the AI: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _addErrorMessage(String text) {
    final errorMessage = convo_ui.ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isUser: false);
    _messages.add(errorMessage);
    _isLoading = false;
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _chatHistory.clear();
    _addInitialBotMessage();
    if (_config != null && _settings.languageSettings != null) {
      final languageSettings = _settings.languageSettings;
      final variables = {
        'target_language': languageSettings?.targetLanguage?.code ??
            _config?.defaultSettings['target_language'] ??
            'en',
        'native_language': languageSettings?.nativeLanguage?.code ??
            _config?.defaultSettings['native_language'] ??
            'en',
      };
      final systemPromptType =
          _config?.conversationSystemPromptType ?? 'structured_conversation';
      final systemPromptText =
          Prompts.getPrompt(systemPromptType, variables: variables);
      // Create a system message
      _chatHistory.add(SystemChatMessage(content: systemPromptText));
    }
    notifyListeners();
  }

  // Handle language settings changes
  void _onLanguageSettingsChanged() {
    _logger.log(LogCategory.conversationService,
        'Language settings changed, updating conversation');

    // Update the initial bot message with new language
    if (_messages.isNotEmpty && !_messages.first.isUser) {
      // Get the new target language
      final languageSettings = _settings.languageSettings;
      final targetLanguage = languageSettings?.targetLanguage?.code ??
          _config?.defaultSettings['target_language'] ??
          'en';

      // Update the first (initial) message with new language
      final updatedInitialMessage = convo_ui.ChatMessage(
          id: _messages.first.id,
          text: Prompts.getInitialBotMessage(targetLanguage),
          isUser: false);

      _messages[0] = updatedInitialMessage;

      _logger.log(LogCategory.conversationService,
          'Updated initial bot message to language: $targetLanguage');
    }

    // Update the system prompt in chat history with new language variables
    if (_config != null && _chatHistory.isNotEmpty) {
      final languageSettings = _settings.languageSettings;
      final variables = {
        'target_language': languageSettings?.targetLanguage?.code ??
            _config?.defaultSettings['target_language'] ??
            'en',
        'native_language': languageSettings?.nativeLanguage?.code ??
            _config?.defaultSettings['native_language'] ??
            'en',
        'support_language_1': languageSettings?.supportLanguage1?.code ??
            _config?.defaultSettings['support_language_1'] ??
            'en',
        'support_language_2': languageSettings?.supportLanguage2?.code ??
            _config?.defaultSettings['support_language_2'] ??
            'en',
      };

      final systemPromptType =
          _config?.conversationSystemPromptType ?? 'structured_conversation';
      final systemPromptText =
          Prompts.getPrompt(systemPromptType, variables: variables);

      // Update the first system message if it exists
      if (_chatHistory.isNotEmpty && _chatHistory.first is SystemChatMessage) {
        _chatHistory[0] = SystemChatMessage(content: systemPromptText);
        _logger.log(LogCategory.conversationService,
            'Updated system prompt with new language variables');
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    // Remove language settings listener to avoid memory leaks
    _settings.languageSettings.removeListener(_onLanguageSettingsChanged);
    super.dispose();
  }
}

extension ToGoogleContentExtension on ChatMessage {
  google_ai.Content toGoogleContent() {
    String textContent = '';

    // Get the text content from the message
    if (this is HumanChatMessage) {
      textContent = (this as HumanChatMessage).content.toString();
    } else if (this is AIChatMessage) {
      textContent = (this as AIChatMessage).content.toString();
    } else if (this is SystemChatMessage) {
      textContent = (this as SystemChatMessage).content.toString();
    } else {
      throw ArgumentError(
          'Unknown or unsupported ChatMessage type: $runtimeType for toGoogleContent conversion');
    }

    final parts = [google_ai.TextPart(textContent)];
    String role;
    if (this is HumanChatMessage) {
      role = 'user';
    } else if (this is AIChatMessage) {
      role = 'model';
    } else if (this is SystemChatMessage) {
      role = 'user';
    } else {
      throw ArgumentError(
          'Unknown or unsupported ChatMessage type: $runtimeType for toGoogleContent conversion');
    }
    return google_ai.Content(role, parts);
  }
}
