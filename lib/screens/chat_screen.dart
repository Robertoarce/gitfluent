import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import '../services/language_settings_service.dart';

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
                    return _MessageBubble(message: message);
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
'''$targetLang:
[Original text in $targetLang]

Corrections (if any):
[List any corrections needed]

$nativeLang translation:
[Translation]

Verb analysis:
- Verb 1 (infinitive): [conjugations]
- Verb 2 (infinitive): [conjugations]
'''

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