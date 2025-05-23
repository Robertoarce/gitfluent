import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';
import '../services/vocabulary_service.dart';
import '../services/nlp_service.dart';
import '../models/vocabulary_item.dart';
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
                      return Column(
                        crossAxisAlignment: message.isUser 
                            ? CrossAxisAlignment.end 
                            : CrossAxisAlignment.start,
                        children: [
                          _MessageBubble(message: message),
                          if (!message.isUser)
                            _VocabularyButtons(message: message),
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
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isUser
            ? SelectableText(
                message.content,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : SelectableMarkdown(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}

class _VocabularyButtons extends StatefulWidget {
  final Message message;

  const _VocabularyButtons({required this.message});

  @override
  State<_VocabularyButtons> createState() => _VocabularyButtonsState();
}

class _VocabularyButtonsState extends State<_VocabularyButtons> {
  bool _isLoading = false;
  final Map<String, String> _verbs = {};
  final Map<String, String> _nouns = {};
  final Map<String, String> _adverbs = {};
  final Map<String, Map<String, dynamic>> _conjugations = {};
  final Map<String, String> _definitions = {};
  late final String _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = DateTime.now().toIso8601String();
    _processMessage();
  }

  Future<void> _processMessage() async {
    if (widget.message.isUser) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final content = widget.message.content;
      
      // Process sections in order
      await _processVerbs(content);
      await _processNouns(content);
      await _processAdverbs(content);

      debugPrint('Found ${_verbs.length} verbs, ${_nouns.length} nouns, and ${_adverbs.length} adverbs');
    } catch (e) {
      debugPrint('Error processing message: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processVerbs(String content) async {
    final verbSection = _extractSection(content, 'Verb analysis:', 'Nouns analysis:');
    if (verbSection != null) {
      final verbLines = verbSection.split('\n');
      String? currentVerb;
      String? currentMeaning;
      List<String> conjugationLines = [];

      for (final line in verbLines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('-')) {
          // Save previous verb's conjugations if any
          if (currentVerb != null && conjugationLines.isNotEmpty) {
            _conjugations[currentVerb] = _processConjugations(conjugationLines);
          }
          
          // Start new verb
          final match = RegExp(r'-\s*([\w\s]+)\s*\((.*?)\)').firstMatch(trimmedLine);
          if (match != null) {
            currentVerb = match.group(1)?.trim();
            currentMeaning = match.group(2)?.trim();
            if (currentVerb != null && currentMeaning != null) {
              _verbs[currentVerb] = currentMeaning;
              conjugationLines = [];
            }
          }
        } else if (trimmedLine.isNotEmpty && currentVerb != null) {
          conjugationLines.add(trimmedLine);
        }
      }
      
      // Process the last verb's conjugations
      if (currentVerb != null && conjugationLines.isNotEmpty) {
        _conjugations[currentVerb] = _processConjugations(conjugationLines);
      }
    }
  }

  Future<void> _processNouns(String content) async {
    final nounSection = _extractSection(content, 'Nouns analysis:', 'Adverbs analysis:');
    if (nounSection != null) {
      final nounLines = nounSection.split('\n');
      for (final line in nounLines) {
        if (line.trim().startsWith('-')) {
          final match = RegExp(r'-\s*([\w\s]+)\s*\((.*?)\)(.*)').firstMatch(line.trim());
          if (match != null) {
            final noun = match.group(1)?.trim() ?? '';
            final meaning = match.group(2)?.trim() ?? '';
            final definition = match.group(3)?.trim() ?? '';
            
            if (noun.isNotEmpty) {
              _nouns[noun] = meaning;
              if (definition.isNotEmpty) {
                _definitions[noun] = definition.replaceAll(RegExp(r'^\s*[-:]\s*'), '');
              }
            }
          }
        }
      }
    }
  }

  Future<void> _processAdverbs(String content) async {
    final adverbSection = _extractSection(content, 'Adverbs analysis:', null);
    if (adverbSection != null) {
      final adverbLines = adverbSection.split('\n');
      for (final line in adverbLines) {
        if (line.trim().startsWith('-')) {
          final match = RegExp(r'-\s*([\w\s]+)\s*\((.*?)\)(.*)').firstMatch(line.trim());
          if (match != null) {
            final adverb = match.group(1)?.trim() ?? '';
            final meaning = match.group(2)?.trim() ?? '';
            final definition = match.group(3)?.trim() ?? '';
            
            if (adverb.isNotEmpty) {
              _adverbs[adverb] = meaning;
              if (definition.isNotEmpty) {
                _definitions[adverb] = definition.replaceAll(RegExp(r'^\s*[-:]\s*'), '');
              }
            }
          }
        }
      }
    }
  }

  Map<String, String> _processConjugations(List<String> lines) {
    final conjugations = <String, String>{};
    for (final line in lines) {
      final parts = line.split(':').map((p) => p.trim()).toList();
      if (parts.length == 2) {
        conjugations[parts[0]] = parts[1];
      } else if (parts.length == 1 && parts[0].isNotEmpty) {
        conjugations['form${conjugations.length + 1}'] = parts[0];
      }
    }
    return conjugations;
  }

  String? _extractSection(String content, String startMarker, String? endMarker) {
    final startIndex = content.indexOf(startMarker);
    if (startIndex == -1) return null;

    final start = startIndex + startMarker.length;
    final end = endMarker != null ? content.indexOf(endMarker, start) : content.length;
    
    if (end == -1) {
      return content.substring(start).trim();
    }
    
    return content.substring(start, end).trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_verbs.isEmpty && _nouns.isEmpty && _adverbs.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ..._verbs.entries.map((entry) => _VocabularyChip(
                word: entry.key,
                type: VocabularyItem.typeVerb,
                translation: entry.value,
                conjugations: _conjugations[entry.key],
                conversationId: _conversationId,
              )),
          ..._nouns.entries.map((entry) => _VocabularyChip(
                word: entry.key,
                type: VocabularyItem.typeNoun,
                translation: entry.value,
                definition: _definitions[entry.key],
                conversationId: _conversationId,
              )),
          ..._adverbs.entries.map((entry) => _VocabularyChip(
                word: entry.key,
                type: VocabularyItem.typeAdverb,
                translation: entry.value,
                definition: _definitions[entry.key],
                conversationId: _conversationId,
              )),
        ],
      ),
    );
  }
}

class _VocabularyChip extends StatefulWidget {
  final String word;
  final String type;
  final String translation;
  final Map<String, dynamic>? conjugations;
  final String? definition;
  final String conversationId;

  const _VocabularyChip({
    required this.word,
    required this.type,
    required this.translation,
    this.conjugations,
    this.definition,
    required this.conversationId,
  });

  @override
  State<_VocabularyChip> createState() => _VocabularyChipState();
}

class _VocabularyChipState extends State<_VocabularyChip> {
  bool _isLoading = false;
  bool _isAdded = false;

  @override
  Widget build(BuildContext context) {
    final isVerb = widget.type == VocabularyItem.typeVerb;
    final isNoun = widget.type == VocabularyItem.typeNoun;
    final isAdverb = widget.type == VocabularyItem.typeAdverb;
    
    Color getChipColor() {
      if (_isAdded) return Colors.green.shade700;
      if (isVerb) return Colors.blue.shade700;
      if (isNoun) return Colors.green.shade700;
      if (isAdverb) return Colors.red.shade700;
      return Colors.grey.shade700;
    }
    
    Color getBackgroundColor() {
      if (_isAdded) return Colors.green.shade50;
      if (isVerb) return Colors.blue.shade50;
      if (isNoun) return Colors.green.shade50;
      if (isAdverb) return Colors.red.shade50;
      return Colors.grey.shade50;
    }
    
    IconData getIcon() {
      if (_isAdded) return Icons.check;
      if (isVerb) return Icons.run_circle;
      if (isNoun) return Icons.label;
      if (isAdverb) return Icons.speed;
      return Icons.help_outline;
    }
    
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: Colors.transparent,
        child: _isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: getChipColor(),
                ),
              )
            : Icon(
                getIcon(),
                color: getChipColor(),
                size: 18,
              ),
      ),
      backgroundColor: getBackgroundColor(),
      label: Text(
        widget.word,
        style: TextStyle(
          color: getChipColor().withValues(alpha: 0.9),
        ),
      ),
      onPressed: _isLoading || _isAdded
          ? null
          : () async {
              setState(() => _isLoading = true);
              try {
                final vocabularyService = context.read<VocabularyService>();
                if (!vocabularyService.isInitialized) {
                  throw Exception('Vocabulary service not initialized');
                }
                
                await vocabularyService.addOrUpdateItem(
                  widget.word,
                  widget.type,
                  widget.translation,
                  definition: widget.definition,
                  conjugations: widget.conjugations,
                  conversationId: widget.conversationId,
                );

                if (!mounted) return;
                setState(() => _isAdded = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "${widget.word}" to your vocabulary'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding word: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
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