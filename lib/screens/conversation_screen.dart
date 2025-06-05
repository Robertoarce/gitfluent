import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../services/conversation_service.dart'; // Import ConversationService
import '../services/conversation_starter_service.dart';

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
  late ConversationService
      _conversationService; // To store the service instance
  Future<List<ConversationStarterCategory>>? _starters;
  final ScrollController _categoryScrollController = ScrollController();
  bool _showLeftScrollIndicator = false;
  bool _showRightScrollIndicator = false;

  final List<Color> _categoryColors = [
    Colors.blue.shade700,
    Colors.green.shade700,
    Colors.orange.shade700,
    Colors.purple.shade700,
    Colors.red.shade700,
    Colors.teal.shade700,
    Colors.pink.shade700,
    Colors.amber.shade800,
  ];

  @override
  void initState() {
    super.initState();
    // Get the service instance, but don't listen here as Consumer will handle it
    _conversationService =
        Provider.of<ConversationService>(context, listen: false);
    _starters = ConversationStarterService.loadStarters();
    _starters!.then((_) {
      if (mounted) {
        _categoryScrollController.addListener(_onScroll);
        // Initial check after the first frame
        WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      }
    });
    // _addInitialLLMPrompt(); // Removed, initial prompt handled by service
    // Listen to message changes to scroll to bottom
    // Adding a listener directly to the service to scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if the widget is still in the tree
        _conversationService.addListener(_scrollToBottomIfNecessary);
      }
    });
  }

  // void _addInitialLLMPrompt() { ... } // Removed

  void _sendMessage(String text) {
    if (text.trim().isNotEmpty) {
      _conversationService.sendMessage(text.trim());
      _textController.clear();
      _scrollToBottomIfNecessary();
    }
  }

  void _scrollToBottomIfNecessary() {
    // Check if there are messages and if the scroll controller is attached
    if (_conversationService.messages.isNotEmpty &&
        _scrollController.hasClients) {
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

  void _onScroll() {
    if (!_categoryScrollController.hasClients) return;
    final position = _categoryScrollController.position;

    // Check if the view is scrollable at all
    if (position.maxScrollExtent == 0) {
      if (_showLeftScrollIndicator || _showRightScrollIndicator) {
        setState(() {
          _showLeftScrollIndicator = false;
          _showRightScrollIndicator = false;
        });
      }
      return;
    }

    final atStart = position.pixels <= position.minScrollExtent;
    final atEnd = position.pixels >= position.maxScrollExtent;

    final bool shouldShowLeft = !atStart;
    final bool shouldShowRight = !atEnd;

    if (shouldShowLeft != _showLeftScrollIndicator ||
        shouldShowRight != _showRightScrollIndicator) {
      setState(() {
        _showLeftScrollIndicator = shouldShowLeft;
        _showRightScrollIndicator = shouldShowRight;
      });
    }
  }

  void _scrollRight() {
    _categoryScrollController.animateTo(
      _categoryScrollController.offset + 200,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _scrollLeft() {
    _categoryScrollController.animateTo(
      _categoryScrollController.offset - 200,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _conversationService
        .removeListener(_scrollToBottomIfNecessary); // Clean up listener
    _categoryScrollController.removeListener(_onScroll);
    _categoryScrollController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation Practice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear Chat',
            onPressed: () {
              _conversationService.clearChat();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: FutureBuilder<List<ConversationStarterCategory>>(
            future: _starters,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final categories = snapshot.data!;
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: kToolbarHeight,
                    child: ListView.builder(
                      controller: _categoryScrollController,
                      scrollDirection: Axis.horizontal,
                      // Add padding to avoid buttons being obscured by scroll indicators
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final color =
                            _categoryColors[index % _categoryColors.length];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 4.0),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(24.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ConversationStarterTopic>(
                              hint: Text(
                                category.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Colors.white),
                              dropdownColor: Colors.grey.shade50,
                              style: Theme.of(context).textTheme.bodyLarge,
                              items: category.topics.map((topic) {
                                return DropdownMenuItem<
                                    ConversationStarterTopic>(
                                  value: topic,
                                  child: Tooltip(
                                    message: topic.description,
                                    child: Text(topic.title),
                                  ),
                                );
                              }).toList(),
                              onChanged: (topic) {
                                if (topic != null) {
                                  _sendMessage(topic.description);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_showLeftScrollIndicator)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: _scrollLeft,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8.0),
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  if (_showRightScrollIndicator)
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: _scrollRight,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8.0),
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      body: Consumer<ConversationService>(
        builder: (context, conversationService, child) {
          // Call _scrollToBottom after the build phase if messages have changed
          // This is now handled by the listener in initState
          // WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

          if (conversationService.isLoading &&
              conversationService.messages.length <= 1) {
            return const Center(child: CircularProgressIndicator());
          }
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
          style:
              TextStyle(color: message.isUser ? Colors.white : Colors.black87),
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
            onPressed:
                isLoading ? null : () => _sendMessage(_textController.text),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
