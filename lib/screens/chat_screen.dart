import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';
import '../services/vocabulary_service.dart';
import '../services/nlp_service.dart';
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
    
    String title = ' Professor is now ready';
    if (languageSettings.targetLanguage != null) {
      title += ' to teach ${languageSettings.targetLanguage?.name}';
    }
    title += ' using: ${settings.getProviderName(settings.currentProvider)}';
    
    return Scaffold(
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
            color: Colors.black.withOpacity(0.1),
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
    
    final targetLang = languageSettings.targetLanguage?.name ?? 'Italian';
    final nativeLang = languageSettings.nativeLanguage?.name ?? 'English';
    final settings = context.read<SettingsService>();
    final maxVerbs = settings.maxVerbs;
    final maxNouns = settings.maxNouns;
    
    chatService.updateSystemPrompt("""
You are a teacher helping me learn $targetLang. From now on:
1. If I write in $nativeLang, translate it to $targetLang
2. If I write in $targetLang, first correct it (if needed) and then translate it to $nativeLang
3. For each response, include:
   - The translation
   - Any corrections (if the input was in $targetLang)
   - The key verbs in their infinitive form
   - The correct conjugation used in the context
   - Other relevant conjugations
4. Keep the tone light and playful

Example format:
[INPUT]
[Original text, in any mix of languages]

[EXPECTED OUTPUT]
$targetLang:
Corrections (if any):
[List any corrections needed]

$nativeLang translation:
[Translation]

Verb analysis:
- Verb 1 (infinitive): [conjugations]
- Verb 2 (infinitive): [conjugations]
[Continue with the next verbs, up to $maxVerbs verbs]

Nouns analysis:
- Noun 1 (singular): [Definition]
- Noun 2 (singular): [Definition]
[Continue with the next nouns, up to $maxNouns nouns]

DO NOT include any other text than the example format.
DO NOT include ''' in the response.
""");
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

  @override
  void initState() {
    super.initState();
    _processMessage();
  }

  Future<void> _processMessage() async {
    if (widget.message.isUser) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final content = widget.message.content;
      
      // Extract verbs
      final verbSection = _extractSection(content, 'Verb analysis:', 'Nouns analysis:');
      if (verbSection != null) {
        final verbLines = verbSection.split('\n');
        for (final line in verbLines) {
          if (line.trim().startsWith('-')) {
            final match = RegExp(r'-\s*([\w\s]+)\s*\((.*?)\)').firstMatch(line);
            if (match != null) {
              final verb = match.group(1)?.trim();
              final meaning = match.group(2)?.trim();
              if (verb != null && meaning != null) {
                _verbs[verb] = meaning;
              }
            }
          }
        }
      }

      // Extract nouns
      final nounSection = _extractSection(content, 'Nouns analysis:', null);
      if (nounSection != null) {
        final nounLines = nounSection.split('\n');
        for (final line in nounLines) {
          if (line.trim().startsWith('-')) {
            final match = RegExp(r'-\s*([\w\s]+)\s*\((.*?)\)').firstMatch(line);
            if (match != null) {
              final noun = match.group(1)?.trim();
              final meaning = match.group(2)?.trim();
              if (noun != null && meaning != null) {
                _nouns[noun] = meaning;
              }
            }
          }
        }
      }

      debugPrint('Found ${_verbs.length} verbs and ${_nouns.length} nouns');
    } catch (e) {
      debugPrint('Error processing message: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

    if (_verbs.isEmpty && _nouns.isEmpty) {
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
                type: 'verb',
                translation: entry.value,
              )),
          ..._nouns.entries.map((entry) => _VocabularyChip(
                word: entry.key,
                type: 'noun',
                translation: entry.value,
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

  const _VocabularyChip({
    required this.word,
    required this.type,
    required this.translation,
  });

  @override
  State<_VocabularyChip> createState() => _VocabularyChipState();
}

class _VocabularyChipState extends State<_VocabularyChip> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isVerb = widget.type == 'verb';
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: Colors.transparent,
        child: _isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isVerb ? Colors.blue.shade700 : Colors.green.shade700,
                ),
              )
            : Icon(
                isVerb ? Icons.run_circle : Icons.label,
                color: isVerb ? Colors.blue.shade700 : Colors.green.shade700,
                size: 18,
              ),
      ),
      backgroundColor: isVerb ? Colors.blue.shade50 : Colors.green.shade50,
      label: Text(
        widget.word,
        style: TextStyle(
          color: isVerb ? Colors.blue.shade900 : Colors.green.shade900,
        ),
      ),
      onPressed: _isLoading
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
                );

                if (!mounted) return;
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