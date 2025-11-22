import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/chat_message.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("it-IT");
    await _flutterTts.setSpeechRate(0.5);
    
    _flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _flutterTts.setErrorHandler((msg) => setState(() => _isSpeaking = false));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend() async {
    if (_textController.text.trim().isEmpty) return;

    final text = _textController.text;
    _textController.clear();

    final chatService = context.read<ChatService>();
    final userService = context.read<UserService>();
    
    final targetLang = userService.currentUser?.targetLanguage ?? 'it';
    
    await chatService.sendMessage(
      text,
      targetLanguage: _getLanguageName(targetLang),
    );
    
    _scrollToBottom();
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'it': return 'Italian';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'en': return 'English';
      default: return 'Italian';
    }
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    } else {
      final userService = context.read<UserService>();
      final targetLang = userService.currentUser?.targetLanguage ?? 'it';
      
      String ttsLang = 'it-IT';
      if (targetLang == 'es') ttsLang = 'es-ES';
      if (targetLang == 'fr') ttsLang = 'fr-FR';
      if (targetLang == 'de') ttsLang = 'de-DE';
      
      await _flutterTts.setLanguage(ttsLang);
      await _flutterTts.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Conversation Practice'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ChatService>().clearChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatService>(
              builder: (context, chatService, child) {
                if (chatService.messages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatService.messages.length + (chatService.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chatService.messages.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final message = chatService.messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Start a conversation!',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Practice speaking in your target language',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFF6B47ED) : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: message.isUser ? const Radius.circular(0) : null,
                  bottomLeft: !message.isUser ? const Radius.circular(0) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
            if (!message.isUser)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton(
                  icon: Icon(
                    Icons.volume_up,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                  onPressed: () => _speak(message.content),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                return FloatingActionButton(
                  onPressed: chatService.isLoading ? null : _handleSend,
                  backgroundColor: const Color(0xFF6B47ED),
                  mini: true,
                  elevation: 0,
                  child: chatService.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, size: 20),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
