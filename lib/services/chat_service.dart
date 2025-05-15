import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'settings_service.dart';

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

  Message({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
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
  
  // System prompt for context
  static const String _defaultSystemPrompt = """
You are a helpful AI assistant. Your responses should be:
- Clear and concise
- Professional but friendly
- Accurate and well-researched
- Formatted in markdown when appropriate

Current conversation context: General assistance and chat.
""";

  String _systemPrompt = _defaultSystemPrompt;
  
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
    updateSystemPrompt(_defaultSystemPrompt);
  }

  ChatService({required SettingsService settings}) : _settings = settings {
    _initializeAI();
    // Listen to settings changes
    _settings.addListener(_initializeAI);
  }

  @override
  void dispose() {
    _settings.removeListener(_initializeAI);
    super.dispose();
  }

  void _initializeAI() {
    try {
      final provider = _settings.currentProvider;
      debugPrint('Initializing AI provider: ${provider.name}');
      
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
            defaultOptions: const ChatOpenAIOptions(
              model: 'gpt-3.5-turbo',
              temperature: 0.7,
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
            model: 'gemini-2.0-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.7,
              maxOutputTokens: 2048,
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
    _messages.add(Message(content: message, isUser: true));
    _chatHistory.add(ChatMessage.user(message));
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      String reply;
      
      switch (_settings.currentProvider) {
        case AIProvider.openai:
          if (_openAILlm == null) {
            throw Exception('OpenAI not initialized. Please check your API key.');
          }
          
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

          final response = await _geminiModel!.generateContent([
            Content.text(prompt)
          ]);
          
          if (response.text == null) {
            throw Exception('No response received from Gemini');
          }
          
          reply = response.text!;
          break;
      }
      
      _messages.add(Message(content: reply, isUser: false));
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
} 