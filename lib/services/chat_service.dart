import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
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
  late ChatOpenAI _openAILlm;
  final List<ChatMessage> _chatHistory = [];
  final SettingsService _settings;

  ChatService({required SettingsService settings}) : _settings = settings {
    _initializeAI();
  }

  void _initializeAI() {
    final provider = _settings.currentProvider;
    final apiKey = dotenv.env[_settings.getProviderApiKeyName(provider)];

    switch (provider) {
      case AIProvider.openai:
        _openAILlm = ChatOpenAI(
          apiKey: apiKey,
          defaultOptions: const ChatOpenAIOptions(
            model: 'gpt-3.5-turbo',
            temperature: 0.7,
          ),
        );
        break;
      case AIProvider.gemini:
        // Initialize Gemini when adding the package
        break;
      case AIProvider.claude:
        // Initialize Claude when adding the package
        break;
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
          final prompt = PromptValue.chat(_chatHistory);
          final response = await _openAILlm.invoke(prompt);
          reply = response.firstOutput?.content ?? 'No response from AI';
          break;
        
        case AIProvider.gemini:
          // Add Gemini implementation
          reply = 'Gemini support coming soon!';
          break;
        
        case AIProvider.claude:
          // Add Claude implementation
          reply = 'Claude support coming soon!';
          break;
      }
      
      _messages.add(Message(content: reply, isUser: false));
      _chatHistory.add(ChatMessage.system(reply));
    } catch (e) {
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