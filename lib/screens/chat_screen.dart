import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../services/language_settings_service.dart';
import '../services/vocabulary_service.dart';
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
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
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
              ),
            ),
            const SizedBox(width: 8),
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                final languageSettings = context.watch<LanguageSettings>();
                return IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: chatService.isLoading
                      ? null
                      : () {
                          if (_controller.text.isNotEmpty) {
                            final targetLang = languageSettings.targetLanguage?.name ?? 'Italian';
                            final nativeLang = languageSettings.nativeLanguage?.name ?? 'English';
                            
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
$targetLang:
[Original text in $targetLang]

Corrections (if any):
[List any corrections needed]

$nativeLang translation:
[Translation]

Verb analysis:
- Verb 1 (infinitive): [conjugations]
- Verb 2 (infinitive): [conjugations]

DO NOT include any other text than the example format.
DO NOT include ''' in the response.
""");
                            chatService.sendMessage(_controller.text);
                            _controller.clear();
                          }
                        },
                );
              },
            ),
          ],
        ),
      ),
    );
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
            ? Text(
                message.content,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : MarkdownBody(
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

class _VocabularyButtons extends StatelessWidget {
  final Message message;
  // Updated patterns to match the AI response format
  static final RegExp _verbPattern = RegExp(r'(?:^|\n)-\s*([A-Za-z]+(?:\s+[A-Za-z]+)*)\s*\(infinitive\):', multiLine: true);
  static final RegExp _nounPattern = RegExp(r'(?:^|\n)([A-Za-z]+(?:\s+[A-Za-z]+)*)\s+translation:', multiLine: true);

  const _VocabularyButtons({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) return const SizedBox();

    debugPrint('Processing message content: ${message.content}');

    // Extract verbs and nouns
    final verbs = _verbPattern
        .allMatches(message.content)
        .map((m) {
          final verb = m.group(1)?.trim();
          debugPrint('Found verb: $verb');
          return verb;
        })
        .where((v) => v != null && v.isNotEmpty)
        .map((v) => v!)
        .toSet()
        .toList();

    final nouns = _nounPattern
        .allMatches(message.content)
        .map((m) {
          final noun = m.group(1)?.trim();
          debugPrint('Found noun: $noun');
          return noun;
        })
        .where((n) => n != null && n.isNotEmpty && !n.toLowerCase().contains('verb'))
        .map((n) => n!)
        .toSet()
        .toList();

    debugPrint('Found ${verbs.length} verbs and ${nouns.length} nouns');

    if (verbs.isEmpty && nouns.isEmpty) {
      debugPrint('No vocabulary items found in message');
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...verbs.map((verb) => _VocabularyChip(
                word: verb,
                type: 'verb',
                translation: 'To $verb',
              )),
          ...nouns.map((noun) => _VocabularyChip(
                word: noun,
                type: 'noun',
                translation: noun,
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