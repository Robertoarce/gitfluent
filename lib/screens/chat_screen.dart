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
  static final RegExp _sectionPattern = RegExp(r'(?:^|\n)([A-Za-z]+):\n(.*?)(?=\n[A-Za-z]+:|\Z)', dotAll: true);
  static final RegExp _wordPattern = RegExp(r'\b([A-Za-z]+)\b');

  const _VocabularyButtons({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) return const SizedBox();

    // Get language settings
    final languageSettings = context.read<LanguageSettings>();
    final targetLang = languageSettings.targetLanguage?.name ?? 'Italian';
    final nativeLang = languageSettings.nativeLanguage?.name ?? 'English';

    // Extract the target language section
    String? targetSection;
    for (final match in _sectionPattern.allMatches(message.content)) {
      final sectionName = match.group(1);
      if (sectionName == targetLang) {
        targetSection = match.group(2)?.trim();
        break;
      }
    }

    if (targetSection == null) return const SizedBox();

    // Extract words from the target section
    final words = _wordPattern
        .allMatches(targetSection)
        .map((m) => m.group(1)?.trim())
        .where((word) => 
          word != null && 
          word.length > 2 && // Skip short words
          !word.contains(RegExp(r'\d')) && // Skip words with numbers
          !_isCommonWord(word)) // Skip common words
        .map((word) => word!)
        .toSet()
        .toList();

    if (words.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: words.map((word) => _VocabularyChip(
          word: word,
          type: _determineWordType(word),
          translation: word,
        )).toList(),
      ),
    );
  }

  String _determineWordType(String word) {
    // Simple heuristic: if word ends in 'are', 'ere', 'ire' for Italian verbs
    // You might want to adjust this based on the target language
    if (word.endsWith('are') || word.endsWith('ere') || word.endsWith('ire')) {
      return 'verb';
    }
    return 'noun';
  }

  bool _isCommonWord(String word) {
    // Add common words to skip (articles, prepositions, etc.)
    const commonWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'il', 'la', 'le', 'i', 'gli', 'lo', 'un', 'una',
      'dei', 'delle', 'el', 'los', 'las', 'unos', 'unas',
      'de', 'en', 'con', 'por', 'para'
    };
    return commonWords.contains(word.toLowerCase());
  }
}

class _VocabularyChip extends StatelessWidget {
  final String word;
  final String type;
  final String translation;

  const _VocabularyChip({
    required this.word,
    required this.type,
    required this.translation,
  });

  @override
  Widget build(BuildContext context) {
    final isVerb = type == 'verb';
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: Colors.transparent,
        child: Icon(
          isVerb ? Icons.run_circle : Icons.label,
          color: isVerb ? Colors.blue.shade700 : Colors.green.shade700,
          size: 18,
        ),
      ),
      backgroundColor: isVerb ? Colors.blue.shade50 : Colors.green.shade50,
      label: Text(
        word,
        style: TextStyle(
          color: isVerb ? Colors.blue.shade900 : Colors.green.shade900,
        ),
      ),
      onPressed: () {
        context.read<VocabularyService>().addOrUpdateItem(
          word,
          type,
          translation,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$word" to your vocabulary'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
} 