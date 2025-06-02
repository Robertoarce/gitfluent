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
import '../services/user_service.dart';
import '../models/vocabulary_item.dart';
import '../models/language_response.dart';
import 'settings_screen.dart';
import 'user_vocabulary_screen.dart';
import 'vocabulary_screen.dart';
// import '../widgets/chat_message.dart'; // Commented out to fix missing file error
// import '../widgets/message_composer.dart'; // Commented out to fix missing file error

class ChatScreen extends StatefulWidget {
  // final GlobalKey<ScaffoldState>? scaffoldKey; // Removed

  const ChatScreen({super.key}); // Removed scaffoldKey from constructor

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
    final settings = context.watch<SettingsService>();
    final languageSettings = context.watch<LanguageSettings>();

    String title = ' GitFluent -> made by Roberto Arce';
    // if (languageSettings.targetLanguage != null) {
    //   title += '${languageSettings.targetLanguage?.name}';
    // }
    // title += ' -> Using: ${settings.getProviderName(settings.currentProvider)}';

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
          // leading: widget.scaffoldKey != null // Removed leading IconButton
          //     ? IconButton(
          //         icon: const Icon(Icons.menu),
          //         onPressed: () {
          //           widget.scaffoldKey!.currentState?.openDrawer();
          //         },
          //       )
          //     : null,
          backgroundColor: const Color.fromARGB(255, 71, 175, 227),
          title: Text(title),
          actions: [
            Row(
              children: [
                const Text('Detailed mode', style: TextStyle(fontSize: 13)),
                Switch(
                  value: _detailedMode,
                  onChanged: (value) {
                    setState(() {
                      _detailedMode = value;
                    });
                  },
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.menu_book),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VocabularyScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                context.read<ChatService>().clearChat();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<UserService>().signOut();
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
                          parsedResponse =
                              _tryParseJsonResponse(message.LLMjsonResponse!);
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

  void _sendMessage(
      ChatService chatService, LanguageSettings languageSettings) {
    if (_controller.text.isEmpty) return;

    chatService.sendMessage(_controller.text);
    _controller.clear();
  }

  // Helper method to parse JSON response - shared by message bubble and vocabulary buttons
  LanguageResponse? _tryParseJsonResponse(String content) {
    if (content.isEmpty) {
      debugPrint('Empty content provided to JSON parser');
      return null;
    }

    try {
      // First try direct parsing of the entire content
      debugPrint('Attempting to parse JSON content directly');
      return LanguageResponse.fromJson(json.decode(content));
    } catch (e) {
      debugPrint('Direct JSON parsing failed: $e');

      // Try to extract JSON if it's embedded in text
      try {
        // Look for JSON inside code blocks
        final jsonCodeBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
        final codeMatch = jsonCodeBlockRegex.firstMatch(content);

        if (codeMatch != null && codeMatch.group(1) != null) {
          debugPrint('Found JSON in code block');
          final jsonString = codeMatch.group(1)!.trim();
          return LanguageResponse.fromJson(json.decode(jsonString));
        }

        // Try simple regex extraction
        final jsonRegex = RegExp(r'(\{[\s\S]*\})');
        final match = jsonRegex.firstMatch(content);

        if (match != null) {
          debugPrint('Found JSON using simple regex');
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

class _MessageBubble extends StatefulWidget {
  final Message message;
  final LanguageResponse? parsedResponse;
  final bool detailedMode;

  const _MessageBubble({
    required this.message,
    this.parsedResponse,
    required this.detailedMode,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showCorrections = false;
  bool _showVocabulary = false;

  @override
  void didUpdateWidget(_MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset expanded sections when detailed mode changes
    if (oldWidget.detailedMode != widget.detailedMode && !widget.detailedMode) {
      setState(() {
        _showCorrections = false;
        _showVocabulary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
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
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
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
                    widget.message.content,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : _buildFormattedContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedContent(BuildContext context) {
    if (widget.parsedResponse != null) {
      return CollapsibleResponseFormatter(
        response: widget.parsedResponse!,
        detailedMode: widget.detailedMode,
      );
    } else {
      return SelectableMarkdown(
        data: widget.message.content,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  bool _showCorrections = false;
  bool _showVocabulary = false;

  @override
  void didUpdateWidget(CollapsibleResponseFormatter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset expanded sections when detailed mode changes
    if (oldWidget.detailedMode != widget.detailedMode && !widget.detailedMode) {
      setState(() {
        _showCorrections = false;
        _showVocabulary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Translation section is always visible
        _buildTranslationSection(),

        // Collapsible corrections section
        if (widget.response.corrections.isNotEmpty)
          _buildCollapsibleCorrectionsSection(),

        // Collapsible vocabulary section
        if (widget.response.vocabularyBreakdown.isNotEmpty)
          _buildCollapsibleVocabularySection(),

        // Additional context if available
        if (widget.response.additionalContext != null &&
            widget.response.additionalContext!.isNotEmpty)
          _buildAdditionalContextSection(),
      ],
    );
  }

  Widget _buildTranslationSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.translate, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Translation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (widget.response.targetLanguageSentence.isNotEmpty)
              SelectableText(
                widget.response.targetLanguageSentence,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (widget.response.targetLanguageSentence.isNotEmpty &&
                widget.response.nativeLanguageTranslation.isNotEmpty)
              const SizedBox(height: 8),
            if (widget.response.nativeLanguageTranslation.isNotEmpty)
              SelectableText(
                widget.response.nativeLanguageTranslation,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleCorrectionsSection() {
    // Check if we have real corrections or just "None" values
    final hasCorrections = !(widget.response.corrections.isEmpty ||
        (widget.response.corrections.length == 1 &&
            (widget.response.corrections[0] == "None." ||
                widget.response.corrections[0]
                    .toLowerCase()
                    .contains("none"))));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => setState(() => _showCorrections = !_showCorrections),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasCorrections ? Icons.edit : Icons.check_circle,
                    color: hasCorrections ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Cleaned input',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showCorrections || widget.detailedMode
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),

              // Only show content if section is expanded or in detailed mode
              if (_showCorrections || widget.detailedMode) ...[
                const Divider(),

                // If no corrections, show a message
                if (!hasCorrections)
                  const Text(
                    'No corrections needed.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.green,
                    ),
                  )
                else
                  // Display each correction
                  ...widget.response.corrections
                      .where((correction) =>
                          correction.trim().isNotEmpty &&
                          correction != "None." &&
                          !correction.toLowerCase().contains("none"))
                      .map((correction) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_right,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(correction),
                                ),
                              ],
                            ),
                          )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleVocabularySection() {
    final vocabulary = widget.response.vocabularyBreakdown;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => setState(() => _showVocabulary = !_showVocabulary),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.purple),
                  const SizedBox(width: 8),
                  const Text(
                    'Vocabulary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showVocabulary || widget.detailedMode
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),

              // Only show content if section is expanded or in detailed mode
              if (_showVocabulary || widget.detailedMode) ...[
                const Divider(),

                // Group vocabulary by type
                ..._buildVocabularyContent(vocabulary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildVocabularyContent(List<VocabularyBreakdown> vocabulary) {
    if (vocabulary.isEmpty) {
      return [const Text('No vocabulary items')];
    }

    try {
      // Group vocabulary by type
      final verbs = vocabulary
          .where((item) => item.wordType.toLowerCase().contains('verb'))
          .toList();
      final nouns = vocabulary
          .where((item) => item.wordType.toLowerCase().contains('noun'))
          .toList();
      final others = vocabulary
          .where((item) =>
              !item.wordType.toLowerCase().contains('verb') &&
              !item.wordType.toLowerCase().contains('noun'))
          .toList();

      final widgets = <Widget>[];

      // Verbs section
      if (verbs.isNotEmpty) {
        widgets.add(
            _buildVocabularyTypeHeader('Verbs', Icons.run_circle, Colors.blue));
        widgets.addAll(verbs.map((verb) => _buildVocabularyItem(verb)));
        widgets.add(const SizedBox(height: 8));
      }

      // Nouns section
      if (nouns.isNotEmpty) {
        widgets.add(
            _buildVocabularyTypeHeader('Nouns', Icons.label, Colors.green));
        widgets.addAll(nouns.map((noun) => _buildVocabularyItem(noun)));
        widgets.add(const SizedBox(height: 8));
      }

      // Other words section
      if (others.isNotEmpty) {
        widgets.add(_buildVocabularyTypeHeader(
            'Other Words', Icons.text_fields, Colors.orange));
        widgets.addAll(others.map((other) => _buildVocabularyItem(other)));
      }

      return widgets;
    } catch (e) {
      debugPrint('Error building vocabulary section: $e');
      return [Text('Error displaying vocabulary: $e')];
    }
  }

  Widget _buildVocabularyTypeHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyItem(VocabularyBreakdown item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.word} ',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (item.baseForm.isNotEmpty && item.baseForm != item.word)
                Text(
                  '(${item.baseForm})',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
          ),
          if (item.translations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                item.translations.join(', '),
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                ),
              ),
            ),
          if (item.forms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                'Forms: ${item.forms.join(', ')}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalContextSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Additional Context',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              widget.response.additionalContext!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
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
