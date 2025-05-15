import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'settings_service.dart';

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
            model: 'gemini-pro',
            apiKey: apiKey,
          );
          debugPrint('Gemini initialized successfully');
          break;
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
    _chatHistory.add(ChatMessage.humanText(message));
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
          final prompt = PromptValue.chat(_chatHistory);
          final response = await _openAILlm!.invoke(prompt);
          reply = response.firstOutput?.content ?? 'No response from AI';
          break;
        
        case AIProvider.gemini:
          if (_geminiModel == null) {
            throw Exception('Gemini not initialized. Please check your API key.');
          }
          final response = await _geminiModel!.generateContent(
            [Content.text(message)]
          );
          reply = response.text ?? 'No response from Gemini';
          break;
      }
      
      _messages.add(Message(content: reply, isUser: false));
      _chatHistory.add(ChatMessage.system(reply));
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
    notifyListeners();
  }
} 