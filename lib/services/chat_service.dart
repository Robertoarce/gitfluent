import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:math'; // Import for min function
import 'settings_service.dart';
import 'prompts.dart';
import 'prompt_config_service.dart';
import '../models/language_response.dart'; // Import the new model

enum MessageType {
  system,
  user,
  assistant
}

class ChatMessage {
  final String content;
  final MessageType type;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  static ChatMessage system(String content) => ChatMessage(
    content: content,
    type: MessageType.system,
  );

  static ChatMessage user(String content) => ChatMessage(
    content: content,
    type: MessageType.user,
  );

  static ChatMessage assistant(String content) => ChatMessage(
    content: content,
    type: MessageType.assistant,
  );
}

class Message {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? LLMjsonResponse;

  Message({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.LLMjsonResponse,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatService extends ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;
  ChatOpenAI? _openAILlm;
  GenerativeModel? _geminiModel;
  final List<ChatMessage> _chatHistory = [];
  final SettingsService _settings;
  GenerativeModel? get _activeGeminiModel => _geminiModel;
  
  String _systemPrompt = Prompts.structuredBasePrompt;
  PromptConfig? _config;
  
  String get systemPrompt => _systemPrompt;
  
  // Update system prompt and context
  void updateSystemPrompt(String newPrompt) {
    _systemPrompt = newPrompt;
    // Add system message to chat history if it's empty or different
    if (_chatHistory.isEmpty || 
        (_chatHistory.first.type == MessageType.system && 
         _chatHistory.first.content != newPrompt)) {
      if (_chatHistory.isNotEmpty && _chatHistory.first.type == MessageType.system) {
        _chatHistory.removeAt(0);
      }
      _chatHistory.insert(0, ChatMessage.system(newPrompt));
    }
    notifyListeners();
  }

  // Reset to default prompt
  void resetSystemPrompt() {
    updateSystemPrompt(Prompts.structuredBasePrompt);
  }

  ChatService({required SettingsService settings}) : _settings = settings {
    _initializeConfig();
    _initializeAI();
    // Listen to settings changes
    _settings.addListener(_initializeAI);
  }

  Future<void> _initializeConfig() async {
    try {
      await PromptConfigService.init();
      PromptConfigService.clearCache();
      _config = await PromptConfigService.loadConfig();
      
      // Set default provider to Gemini if not already set
      if (_settings.currentProvider != AIProvider.gemini) {
        _settings.setProvider(AIProvider.gemini);
      }

      // Get the prompt type and variables directly from config
      final promptType = _config?.systemPromptType ?? 'default';
      final variables = _config?.defaultSettings ?? {
        'target_language': 'it',
        'native_language': 'en',
        'support_language_1': 'es',
        'support_language_2': 'fr',
      };
      
      debugPrint('Prompt type from config: $promptType');
      debugPrint('Language variables: $variables');
      
      _systemPrompt = Prompts.getPrompt(promptType, variables: variables);
      debugPrint('Selected prompt type: $promptType');
      debugPrint('System prompt length: ${_systemPrompt.length}');
      
      if (_chatHistory.isEmpty) {
        _chatHistory.add(ChatMessage.system(_systemPrompt));
      }
    } catch (e) {
      debugPrint('Error loading config: $e');
    }
  }

  // Add method to update configuration
  Future<void> updatePromptConfig({
    String? modelName,
    double? temperature,
    int? maxTokens,
    Map<String, String>? promptVariables,
    Map<String, String>? defaultSettings,
    String? systemPromptType,
  }) async {
    await PromptConfigService.updateConfig(
      modelName: modelName,
      temperature: temperature,
      maxTokens: maxTokens,
      promptVariables: promptVariables,
      defaultSettings: defaultSettings,
      systemPromptType: systemPromptType,
    );
    
    // Reload configuration
    await _initializeConfig();
    // Reinitialize AI with new settings
    _initializeAI();
  }

  @override
  void dispose() {
    _settings.removeListener(_initializeAI);
    super.dispose();
  }

  // Add method to update system prompt with current language settings
  Future<void> _updateSystemPromptWithLanguages() async {
    try {
      final languageSettings = _settings.languageSettings;
      if (languageSettings == null) return;

      final variables = {
        'target_language': languageSettings.targetLanguage?.code ?? 'it',
        'native_language': languageSettings.nativeLanguage?.code ?? 'en',
        'support_language_1': languageSettings.supportLanguage1?.code ?? 'es',
        'support_language_2': languageSettings.supportLanguage2?.code ?? 'fr',
      };

      debugPrint('Updating system prompt with language variables: $variables');
      
      final promptType = _config?.systemPromptType ?? 'default';
      _systemPrompt = Prompts.getPrompt(promptType, variables: variables);
      
      // Update system message in chat history
      if (_chatHistory.isNotEmpty && _chatHistory.first.type == MessageType.system) {
        _chatHistory[0] = ChatMessage.system(_systemPrompt);
      } else {
        _chatHistory.insert(0, ChatMessage.system(_systemPrompt));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating system prompt with languages: $e');
    }
  }

  // Update _initializeAI to use the new method
  void _initializeAI() {
    try {
      final provider = _settings.currentProvider;
      debugPrint('Initializing AI provider: ${provider.name}');
      
      // Update system prompt with current language settings
      _updateSystemPromptWithLanguages();
      
      switch (provider) {
        case AIProvider.openai:
          final apiKey = dotenv.env['OPENAI_API_KEY'];
          if (apiKey == null || apiKey.isEmpty) {
            _messages.add(Message(
              content: 'Error: OpenAI API key not found in .env file. Please add OPENAI_API_KEY to your .env file.',
              isUser: false,
            ));
            notifyListeners();
            return;
          }
          _openAILlm = ChatOpenAI(
            apiKey: apiKey,
            defaultOptions: ChatOpenAIOptions(
              model: _config?.modelName ?? 'gpt-3.5-turbo',
              temperature: _config?.temperature ?? 0.7,
            ),
          );
          debugPrint('OpenAI initialized successfully');
          break;

        case AIProvider.gemini:
          final apiKey = dotenv.env['GEMINI_API_KEY'];
          if (apiKey == null || apiKey.isEmpty) {
            _messages.add(Message(
              content: 'Error: Gemini API key not found in .env file. Please add GEMINI_API_KEY to your .env file.',
              isUser: false,
            ));
            notifyListeners();
            return;
          }
          _geminiModel = GenerativeModel(
            model: _config?.modelName ?? 'gemini-2.0-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: _config?.temperature ?? 0.0,
              maxOutputTokens: _config?.maxTokens ?? 2048,
            ),
          );
          debugPrint('Gemini initialized successfully');
          break;
      }
      
      // Initialize chat history with system prompt
      if (_chatHistory.isEmpty) {
        _chatHistory.add(ChatMessage.system(_systemPrompt));
      }
      
    } catch (e) {
      debugPrint('Error initializing AI: $e');
      _messages.add(Message(
        content: 'Error initializing AI provider: $e',
        isUser: false,
      ));
      notifyListeners();
    }
  }

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    
    _messages.add(Message(content: message, isUser: true, LLMjsonResponse: ''));
    _chatHistory.add(ChatMessage.user(message));
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      String reply;
      String LLMjsonOutput;
      
      switch (_settings.currentProvider) {
        case AIProvider.openai:
          if (_openAILlm == null) {
            throw Exception('OpenAI not initialized. Please check your API key.');
              }
          
          // generates prompt for the LLM (with history )
          final prompt = PromptValue.string('''
          ${_systemPrompt.trim()}

          Previous conversation context:
          ${_chatHistory.where((msg) => msg.type != MessageType.system).map((msg) => 
            "${msg.type == MessageType.user ? 'User' : 'Assistant'}: ${msg.content}"
          ).join('\n')}

          User: $message
          Assistant:''');
          
          final response = await _openAILlm!.invoke(prompt);
          reply = response.firstOutput?.content ?? 'No response from AI';
          break;
        
        case AIProvider.gemini:
          if (_geminiModel == null) {
            throw Exception('Gemini not initialized. Please check your API key.');
          }
          
          // For Gemini, we'll send both the system prompt and user message together
          final prompt = '''
            ${_systemPrompt.trim()}

            Previous conversation context:
            ${_chatHistory.where((msg) => msg.type != MessageType.system).map((msg) => 
              "${msg.type == MessageType.user ? 'User' : 'Assistant'}: ${msg.content}"
            ).join('\n')}

            User: $message
            Assistant:''';

          debugPrint('----------------');
          debugPrint('Full prompt sent to LLM:');
          debugPrint('===============================');
          debugPrint(prompt);
          debugPrint('----------------');

          final response = await _geminiModel!.generateContent([
            Content.text(prompt)
          ]);
          
          if (response.text == null) {
            throw Exception('No response received from Gemini');
          }          
          
          reply = response.text!;
          break;
      }
      
      // Here is where we threat the response from the LLM
      // so we can extract the vocabulary items and add them to the vocabulary service
      (reply, LLMjsonOutput) = _getVocabFromLLMResponse(reply);

      _messages.add(Message(content: reply, isUser: false, LLMjsonResponse: LLMjsonOutput));
      _chatHistory.add(ChatMessage.assistant(reply));
    } catch (e) {
      debugPrint('Error sending message: $e');
      _messages.add(Message(
        content: 'Sorry, I encountered an error. Please try again.\nError: $e',
        isUser: false,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _chatHistory.clear();
    // Reinitialize chat history with system prompt
    _chatHistory.add(ChatMessage.system(_systemPrompt));
    notifyListeners();
  }

  (String, String) _getVocabFromLLMResponse(String response) {
    // EXTRACT JSON FROM RESPONSE
    // PARSE JSON INTO OUR MODEL
    // FORMAT THE RESPONSE FOR DISPLAY
    // RETURN THE FORMATTED RESPONSE

    debugPrint('===============================');
    debugPrint('Processing JSON response:');
    debugPrint(response);
    
    String jsonString = '';
    
    try {
      
      /////////////////////////////////
      /////// JSON EXTRACTION  ////////
      ////////////////////////////////
      
      // Try to parse the response as JSON
      
      
      // Extract JSON if it's wrapped in text
      final jsonRegex = RegExp(r'(\{[\s\S]*\})');
      final match = jsonRegex.firstMatch(response);
      
      if (match != null) {
        // Found JSON within text
        jsonString = match.group(1) ?? '';
        debugPrint('Extracted JSON: ${jsonString.substring(0, min(100, jsonString.length))}...');
      } 
      else if (response.replaceAll('```json', '').replaceAll('```', '').trim().isNotEmpty) {
        jsonString = response.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      else {
        // Try to parse the entire response as JSON
        jsonString = response;
      }
      
      // Parse the JSON into our model
      final languageResponse = LanguageResponse.fromJson(json.decode(jsonString));
      debugPrint('Successfully parsed JSON into LanguageResponse model');
      debugPrint('Vocabulary items: ${languageResponse.vocabularyBreakdown.length}');
      
       ///////////////////////////////////////
      /////// USING JSON FOR BUTTONS  ////////
      ////////////////////////////////////////

      // Format the response for display
      final formattedResponse = _formatLanguageResponseToDisplayText(languageResponse);
      debugPrint('Formatted response for display');
      return (formattedResponse, jsonString);
      
    } catch (e) {
      debugPrint('Error parsing JSON response: $e');
      debugPrint('Returning original response');
      return (response, jsonString);
    }
  }

  String _formatLanguageResponseToDisplayText(LanguageResponse languageResponse) {
    final StringBuffer output = StringBuffer();
    
    // Extract parts from the language response
    final config = _config;
    final String targetLang = config?.defaultSettings['target_language'] ?? 'Target language';
    final String nativeLang = config?.defaultSettings['native_language'] ?? 'Native language';
    
    // Target language sentence
    output.writeln('$targetLang:');
    output.writeln(languageResponse.targetLanguageSentence);
    output.writeln();
    
    // Translation
    output.writeln('$nativeLang Translation:');
    output.writeln(languageResponse.nativeLanguageTranslation);
    output.writeln();
    
    // Corrections
    output.writeln('Corrections:');
    if (languageResponse.corrections.isEmpty || 
        (languageResponse.corrections.length == 1 && languageResponse.corrections[0] == 'None.')) {
      output.writeln('None.');
    } else {
      for (final correction in languageResponse.corrections) {
        output.writeln('- $correction');
      }
    }
    output.writeln();
    
    // Vocabulary breakdown
    output.writeln('Vocabulary Breakdown:');
    for (final word in languageResponse.vocabularyBreakdown) {
      output.writeln('- Word Type: ${word.wordType}');
      output.writeln('  Base Form: ${word.baseForm}');
      output.writeln('  Forms:');
      for (final form in word.forms) {
        output.writeln('    -> $form');
      }
      output.writeln('  Translation:');
      for (final trans in word.translations) {
        output.writeln('    -> $trans');
      }
      output.writeln();
    }
    
    // Additional context (if provided)
    if (languageResponse.additionalContext != null && 
        languageResponse.additionalContext!.isNotEmpty) {
      output.writeln('Additional Context:');
      output.writeln(languageResponse.additionalContext);
    }
    
    return output.toString();
  }
} 