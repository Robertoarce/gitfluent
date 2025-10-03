import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import '../services/chat_service.dart';
import '../services/language_settings_service.dart';
import '../services/user_service.dart';
import '../services/vocabulary_service.dart';
import '../models/language_response.dart';
import '../config/custom_theme.dart';
import 'settings_screen.dart';
import '../utils/flashcard_route_transitions.dart';
import '../utils/keyboard_shortcuts.dart';
import '../utils/app_navigation.dart';
import 'user_vocabulary_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _detailedMode = false;

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
    String title = 'AI Language Tutor';

    return KeyboardShortcutWrapper(
      messageController: _controller,
      child: Scaffold(
        backgroundColor: CustomColorScheme.lightBlue2,
        appBar: AppBar(
          backgroundColor: CustomColorScheme.lightBlue2,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: CustomColorScheme.darkPink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: CustomColorScheme.darkGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Text(
                  'Detailed mode',
                  style: TextStyle(
                    color: CustomColorScheme.darkGreen,
                    fontSize: 13,
                  ),
                ),
                Switch(
                  value: _detailedMode,
                  onChanged: (value) {
                    setState(() {
                      _detailedMode = value;
                    });
                  },
                  activeColor: CustomColorScheme.darkPink,
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: CustomColorScheme.darkGreen,
              ),
              onPressed: () {
                AppNavigation.toConversation(context);
              },
              tooltip: 'Conversation Mode',
            ),
            IconButton(
              icon: Icon(
                Icons.quiz,
                color: CustomColorScheme.darkGreen,
              ),
              onPressed: () {
                FlashcardNavigation.toFlashcardStart(context);
              },
              tooltip: 'Study Flashcards',
            ),
            IconButton(
              icon: Icon(
                Icons.menu_book,
                color: CustomColorScheme.darkGreen,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserVocabularyScreen()),
                );
              },
              tooltip: 'My Vocabulary',
            ),
            IconButton(
              icon: Icon(
                Icons.settings,
                color: CustomColorScheme.darkGreen,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: CustomColorScheme.darkGreen,
              ),
              onPressed: () {
                context.read<ChatService>().clearChat();
              },
            ),
            IconButton(
              icon: Icon(
                Icons.logout,
                color: CustomColorScheme.darkGreen,
              ),
              onPressed: () async {
                await context.read<UserService>().signOut();
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                CustomColorScheme.lightBlue2,
                CustomColorScheme.lightBlue2.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Consumer<ChatService>(
                  builder: (context, chatService, child) {
                    _scrollToBottom();
                    return Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: chatService.messages.length,
                          itemBuilder: (context, index) {
                            final message = chatService.messages[index];
                            // Parse the message JSON if possible
                            LanguageResponse? parsedResponse;
                            if (!message.isUser &&
                                message.LLMjsonResponse != null &&
                                message.LLMjsonResponse!.isNotEmpty) {
                              // Try to parse directly from stored JSON first
                              try {
                                parsedResponse = LanguageResponse.fromJson(
                                    json.decode(message.LLMjsonResponse!));
                                debugPrint(
                                    'Successfully parsed stored JSON response');
                              } catch (e) {
                                // If direct parsing fails, use the helper method
                                debugPrint(
                                    'Stored JSON parsing failed, trying helper: $e');
                                parsedResponse = _tryParseJsonResponse(
                                    message.LLMjsonResponse!);
                              }
                            }

                            return Column(
                              crossAxisAlignment: message.isUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                _MessageBubble(
                                  message: message,
                                  parsedResponse: parsedResponse,
                                  detailedMode: _detailedMode,
                                ),
                                if (!message.isUser)
                                  VocabularyButtons(
                                    message: message,
                                    parsedResponse: parsedResponse,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Consumer<ChatService>(
                builder: (context, chatService, child) {
                  return chatService.isLoading
                      ? Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: LinearProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              CustomColorScheme.darkPink,
                            ),
                          ),
                        )
                      : const SizedBox();
                },
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                        hintStyle: TextStyle(
                          color: CustomColorScheme.darkGreen.withOpacity(0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            CustomColorScheme.lightBlue3.withOpacity(0.3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        color: CustomColorScheme.darkGreen,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CustomColorScheme.darkPink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Consumer2<ChatService, LanguageSettings>(
                builder: (context, chatService, languageSettings, child) {
                  return IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: chatService.isLoading
                        ? null
                        : () => _sendMessage(chatService, languageSettings),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(
      ChatService chatService, LanguageSettings languageSettings) {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    chatService.sendMessage(message);
  }

  LanguageResponse? _tryParseJsonResponse(String jsonString) {
    try {
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return LanguageResponse.fromJson(jsonMap);
    } catch (e) {
      debugPrint('Failed to parse JSON response: $e');
      return null;
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final LanguageResponse? parsedResponse;
  final bool detailedMode;

  const _MessageBubble({
    required this.message,
    this.parsedResponse,
    required this.detailedMode,
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
          minHeight: 50,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isUser
              ? CustomColorScheme.lightBlue1
              : CustomColorScheme.lightBlue3,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          radius: const Radius.circular(10),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: isUser
                ? SelectableText(
                    message.content,
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  )
                : _buildFormattedContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedContent(BuildContext context) {
    if (parsedResponse != null) {
      return CollapsibleResponseFormatter(
        response: parsedResponse!,
        detailedMode: detailedMode,
      );
    } else {
      return Markdown(
        data: message.content,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: CustomColorScheme.darkGreen,
          ),
        ),
      );
    }
  }
}

/// A formatter that wraps LLM output with collapsible sections
class CollapsibleResponseFormatter extends StatefulWidget {
  final LanguageResponse response;
  final bool detailedMode;

  const CollapsibleResponseFormatter({
    super.key,
    required this.response,
    required this.detailedMode,
  });

  @override
  State<CollapsibleResponseFormatter> createState() =>
      _CollapsibleResponseFormatterState();
}

class _CollapsibleResponseFormatterState
    extends State<CollapsibleResponseFormatter> {
  bool _showTranslation = true;
  bool _showExplanation = true;
  bool _showVocabulary = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main response
        SelectableText(
          widget.response.targetLanguageSentence,
          style: TextStyle(
            color: CustomColorScheme.darkGreen,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),

        // Collapsible sections
        if (widget.response.nativeLanguageTranslation.isNotEmpty)
          _buildCollapsibleSection(
            'Translation',
            widget.response.nativeLanguageTranslation,
            _showTranslation,
            (value) => setState(() => _showTranslation = value),
            Icons.translate,
          ),

        if (widget.response.additionalContext != null &&
            widget.response.additionalContext!.isNotEmpty)
          _buildCollapsibleSection(
            'Additional Context',
            widget.response.additionalContext!,
            _showExplanation,
            (value) => setState(() => _showExplanation = value),
            Icons.lightbulb_outline,
          ),

        if (widget.response.vocabularyBreakdown.isNotEmpty)
          _buildCollapsibleSection(
            'Vocabulary Breakdown',
            widget.response.vocabularyBreakdown
                .map((v) => '${v.word}: ${v.translations.join(', ')}')
                .join('\n'),
            _showVocabulary,
            (value) => setState(() => _showVocabulary = value),
            Icons.book,
          ),
      ],
    );
  }

  Widget _buildCollapsibleSection(
    String title,
    String content,
    bool isExpanded,
    ValueChanged<bool> onToggle,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CustomColorScheme.lightBlue3.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CustomColorScheme.lightBlue1.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              icon,
              color: CustomColorScheme.darkPink,
              size: 20,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: CustomColorScheme.darkGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: CustomColorScheme.darkGreen,
            ),
            onTap: () => onToggle(!isExpanded),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                content,
                style: TextStyle(
                  color: CustomColorScheme.darkGreen,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VocabularyButtons extends StatelessWidget {
  final Message message;
  final LanguageResponse? parsedResponse;

  const VocabularyButtons({
    super.key,
    required this.message,
    this.parsedResponse,
  });

  @override
  Widget build(BuildContext context) {
    if (parsedResponse?.vocabularyBreakdown == null ||
        parsedResponse!.vocabularyBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with "Add All" and "View Details" buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _addAllToVocabulary(context),
                icon: const Icon(Icons.bookmark_add, size: 16),
                label: const Text('Add All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColorScheme.darkPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showVocabularyDetails(context),
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColorScheme.lightBlue1,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Individual vocabulary word buttons
          Text(
            'Vocabulary Words:',
            style: TextStyle(
              color: CustomColorScheme.darkGreen,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: parsedResponse!.vocabularyBreakdown.map((vocabItem) {
              return _buildVocabularyWordButton(context, vocabItem);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyWordButton(BuildContext context, dynamic vocabItem) {
    return Container(
      decoration: BoxDecoration(
        color: CustomColorScheme.lightBlue3.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CustomColorScheme.lightBlue1.withOpacity(0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addSingleWordToVocabulary(context, vocabItem),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: CustomColorScheme.darkPink,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vocabItem.word,
                      style: TextStyle(
                        color: CustomColorScheme.darkGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      vocabItem.wordType,
                      style: TextStyle(
                        color: CustomColorScheme.darkGreen.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addAllToVocabulary(BuildContext context) async {
    if (parsedResponse?.vocabularyBreakdown == null ||
        parsedResponse!.vocabularyBreakdown.isEmpty) {
      return;
    }

    try {
      final vocabularyService = context.read<VocabularyService>();

      // Add all vocabulary items from the breakdown
      for (final vocabItem in parsedResponse!.vocabularyBreakdown) {
        await vocabularyService.addOrUpdateItem(
          vocabItem.word,
          vocabItem.wordType,
          vocabItem.translations.join(', '),
          definition: vocabItem.forms.join(', '),
          conversationId: message.timestamp.millisecondsSinceEpoch.toString(),
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Added ${parsedResponse!.vocabularyBreakdown.length} words to vocabulary'),
            backgroundColor: CustomColorScheme.darkPink,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserVocabularyScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to vocabulary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addSingleWordToVocabulary(
      BuildContext context, dynamic vocabItem) async {
    try {
      final vocabularyService = context.read<VocabularyService>();

      await vocabularyService.addOrUpdateItem(
        vocabItem.word,
        vocabItem.wordType,
        vocabItem.translations.join(', '),
        definition: vocabItem.forms.join(', '),
        conversationId: message.timestamp.millisecondsSinceEpoch.toString(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${vocabItem.word}" to vocabulary'),
            backgroundColor: CustomColorScheme.darkPink,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserVocabularyScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding "${vocabItem.word}": $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showVocabularyDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vocabulary Details'),
        content: Text(parsedResponse?.vocabularyBreakdown
                .map((v) => '${v.word}: ${v.translations.join(', ')}')
                .join('\n') ??
            ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
