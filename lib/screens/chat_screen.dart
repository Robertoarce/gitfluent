import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';
import '../services/vocabulary_service.dart';
import '../services/nlp_service.dart';
import '../services/vocabulary_processor.dart';
import '../services/llm_output_formatter.dart';
import '../models/vocabulary_item.dart';
import '../models/language_response.dart';
import 'settings_screen.dart';
import 'vocabulary_review_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final languageSettings = context.watch<LanguageSettings>();
    
    String title = ' ';
    if (languageSettings.targetLanguage != null) {
      title += '${languageSettings.targetLanguage?.name}';
    }
    title += ' -> Using: ${settings.getProviderName(settings.currentProvider)}';
    
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            HardwareKeyboard.instance.isMetaPressed) {
          final chatService = context.read<ChatService>();
          final languageSettings = context.read<LanguageSettings>();
          _controller.text = 'I lov working with u at the skool';
          _sendMessage(chatService, languageSettings);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black38, 
        
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 71, 175, 227),
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VocabularyReviewScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
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
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatService.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatService.messages[index];
                      // Parse the message JSON if possible
                      LanguageResponse? parsedResponse;
                      if (!message.isUser) {
                        parsedResponse = _tryParseJsonResponse(message.LLMjsonResponse ?? '');
                      }
                      
                      return Column(
                        crossAxisAlignment: message.isUser 
                            ? CrossAxisAlignment.end 
                            : CrossAxisAlignment.start,
                        children: [
                          _MessageBubble(
                            message: message,
                            parsedResponse: parsedResponse,
                          ),
                          if (!message.isUser)
                            VocabularyButtons(
                              message: message,
                              parsedResponse: parsedResponse,
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                return chatService.isLoading
                    ? const LinearProgressIndicator()
                    : const SizedBox();
              },
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Consumer2<ChatService, LanguageSettings>(
                builder: (context, chatService, languageSettings, child) {
                  return KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          HardwareKeyboard.instance.isShiftPressed &&
                          !HardwareKeyboard.instance.isControlPressed) {
                        _sendMessage(chatService, languageSettings);
                      }
                    },
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type your message... (Shift+Enter to send)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Consumer2<ChatService, LanguageSettings>(
              builder: (context, chatService, languageSettings, child) {
                return IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: chatService.isLoading
                      ? null
                      : () => _sendMessage(chatService, languageSettings),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatService chatService, LanguageSettings languageSettings) {
    if (_controller.text.isEmpty) return;
    
    chatService.sendMessage(_controller.text);
    _controller.clear();
  }
  
  // Helper method to parse JSON response - shared by message bubble and vocabulary buttons
  LanguageResponse? _tryParseJsonResponse(String content) {
    try {
      // First try direct parsing of the entire content
      return LanguageResponse.fromJson(json.decode(content));
    } catch (e) {
      // Try to extract JSON if it's embedded in text
      try {
        // Look for JSON inside code blocks
        final jsonCodeBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
        final codeMatch = jsonCodeBlockRegex.firstMatch(content);

        if (codeMatch != null && codeMatch.group(1) != null) {
          final jsonString = codeMatch.group(1)!.trim();
          return LanguageResponse.fromJson(json.decode(jsonString));
        }
        
        // Try simple regex extraction
        final jsonRegex = RegExp(r'(\{[\s\S]*\})');
        final match = jsonRegex.firstMatch(content);
        
        if (match != null) {
          final jsonString = match.group(1);
          if (jsonString != null) {
            return LanguageResponse.fromJson(json.decode(jsonString));
          }
        }
      } catch (e) {
        debugPrint('Failed to parse JSON response: $e');
      }
    }
    return null;
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final LanguageResponse? parsedResponse;

  const _MessageBubble({
    required this.message,
    this.parsedResponse,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final ScrollController scrollController = ScrollController();
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
          maxHeight: MediaQuery.of(context).size.height * 1.5,
        ),
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: false,
          trackVisibility: false,
          thickness: 8,
          radius: const Radius.circular(10),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: isUser
                ? SelectableText(
                    message.content,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : _buildFormattedContent(context, message),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFormattedContent(BuildContext context, Message message) {
    Widget contentWidget;
    if (parsedResponse != null) {
      contentWidget = LlmOutputFormatter.formatResponse(parsedResponse!);
    } else {
      contentWidget = SelectableMarkdown(
        data: message.content,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    
    return contentWidget;
  }
}

class SelectableMarkdown extends StatelessWidget {
  final String data;
  final MarkdownStyleSheet? styleSheet;

  const SelectableMarkdown({
    super.key,
    required this.data,
    this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      data,
      style: styleSheet?.p ?? DefaultTextStyle.of(context).style,
    );
  }
} 