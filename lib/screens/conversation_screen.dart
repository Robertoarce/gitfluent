import 'package:flutter/material.dart';

// Placeholder for chat message model - will need to define this properly
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  // final DateTime timestamp; // Optional

  ChatMessage({required this.id, required this.text, required this.isUser});
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add an initial prompt from the LLM to start the conversation
    _addInitialLLMPrompt();
  }

  void _addInitialLLMPrompt() {
    // You can make this prompt more dynamic or configurable later
    final initialPrompt = ChatMessage(
        id: 'llm_initial_prompt_${DateTime.now().millisecondsSinceEpoch}',
        text:
            "Hello! I'm your helpful assistant. What can I help you with today?",
        isUser: false);
    setState(() {
      _messages.add(initialPrompt);
    });
    // No need to scroll here as it's the first message
  }

  // Placeholder for sending a message (will be implemented later with LLM logic)
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isUser: true);
    setState(() {
      _messages.add(userMessage);
    });
    _textController.clear();
    _scrollToBottom();

    // Simulate LLM response (replace with actual LLM call later)
    Future.delayed(const Duration(seconds: 1), () {
      final llmResponse = ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          text: "I am a placeholder LLM response to: \"${userMessage.text}\"",
          isUser: false);
      setState(() {
        _messages.add(llmResponse);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).primaryColor.withOpacity(0.8)
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Text(
          message.text,
          style:
              TextStyle(color: message.isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color:
          Theme.of(context).cardColor, // Or another suitable background color
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
              ),
              onSubmitted: _sendMessage, // Send on enter/submit
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(_textController.text),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
