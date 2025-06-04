import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../services/conversation_service.dart'; // Import ConversationService

// ChatMessage model is now used by ConversationService, so it's defined there or in a common place.
// For this example, we assume ConversationService exposes List<ChatMessage> where ChatMessage is this class.
// If ChatMessage in ConversationService is different, adapt accordingly.
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
  // final List<ChatMessage> _messages = []; // Removed local messages list
  final ScrollController _scrollController = ScrollController();
  late ConversationService _conversationService; // To store the service instance

  @override
  void initState() {
    super.initState();
    // Get the service instance, but don't listen here as Consumer will handle it
    _conversationService = Provider.of<ConversationService>(context, listen: false);
    // _addInitialLLMPrompt(); // Removed, initial prompt handled by service
    // Listen to message changes to scroll to bottom
    // Adding a listener directly to the service to scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if the widget is still in the tree
            _conversationService.addListener(_scrollToBottomIfNecessary);
        }
    });
  }

  // void _addInitialLLMPrompt() { ... } // Removed

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _conversationService.sendMessage(text);
    _textController.clear();
    // Scrolling will be handled by the listener on the service
  }

  void _scrollToBottomIfNecessary() {
    // Check if there are messages and if the scroll controller is attached
    if (_conversationService.messages.isNotEmpty && _scrollController.hasClients) {
      _scrollToBottom();
    }
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
    _conversationService.removeListener(_scrollToBottomIfNecessary); // Clean up listener
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ConversationService>().clearChat();
            },
            tooltip: 'Clear Chat',
          )
        ],
      ),
      body: Consumer<ConversationService>(
        builder: (context, conversationService, child) {
          // Call _scrollToBottom after the build phase if messages have changed
          // This is now handled by the listener in initState
          // WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

          return Column(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: conversationService.messages.length,
                  itemBuilder: (context, index) {
                    final message = conversationService.messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
              ),
              if (conversationService.isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                ),
              _buildMessageComposer(conversationService.isLoading),
            ],
          );
        },
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
          style: TextStyle(color: message.isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildMessageComposer(bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Theme.of(context).cardColor,
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
              onSubmitted: isLoading ? null : _sendMessage,
              enabled: !isLoading,
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: isLoading ? null : () => _sendMessage(_textController.text),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
