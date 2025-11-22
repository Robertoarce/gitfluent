import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_message.dart';

class ChatService extends ChangeNotifier {
  final List<Message> _messages = [];
  final List<ChatMessage> _chatHistory = [];
  GenerativeModel? _geminiModel;
  bool _isLoading = false;

  ChatService() {
    _initializeAI();
  }

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;

  void _initializeAI() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Error: Gemini API key not found in .env file.');
      return;
    }

    _geminiModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
      ),
    );
  }

  Future<void> sendMessage(String message, {String targetLanguage = 'Italian'}) async {
    if (message.trim().isEmpty) return;

    // Add user message
    _messages.add(Message(content: message, isUser: true));
    _chatHistory.add(ChatMessage.user(message));
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      if (_geminiModel == null) {
        _initializeAI();
        if (_geminiModel == null) {
          throw Exception('AI Service not initialized. Check API key.');
        }
      }

      // Construct prompt with history
      final prompt = '''
You are a helpful language learning assistant for $targetLanguage.
Engage in a natural conversation with the user.
Correct any major mistakes gently, but prioritize keeping the conversation flowing.
Keep your responses concise (1-3 sentences) to encourage dialogue.

Previous conversation:
${_chatHistory.where((m) => m.type != MessageType.system).map((m) => "${m.type == MessageType.user ? 'User' : 'Assistant'}: ${m.content}").join('\n')}

User: $message
Assistant:
''';

      final response = await _geminiModel!.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        throw Exception('No response received from Gemini');
      }

      final reply = response.text!;

      _messages.add(Message(content: reply, isUser: false));
      _chatHistory.add(ChatMessage.assistant(reply));

    } catch (e) {
      debugPrint('Error sending message: $e');
      _messages.add(Message(
        content: 'Sorry, I encountered an error. Please try again.',
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
