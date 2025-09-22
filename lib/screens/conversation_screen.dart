import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/conversation_service.dart';
import '../services/vocabulary_service.dart';
import '../services/language_settings_service.dart';
import '../widgets/selectable_text_widget.dart';

class ConversationScreen extends StatefulWidget {
  final ConversationService conversationService;
  final VocabularyService vocabularyService;
  final LanguageSettings languageSettings;

  const ConversationScreen({
    Key? key,
    required this.conversationService,
    required this.vocabularyService,
    required this.languageSettings,
  }) : super(key: key);

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedWord;
  SelectableWord? _selectedWordData;

  @override
  void initState() {
    super.initState();
    widget.conversationService.addListener(_onConversationChanged);
  }

  @override
  void dispose() {
    widget.conversationService.removeListener(_onConversationChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onConversationChanged() {
    setState(() {});
    _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    await widget.conversationService.sendMessage(message);
  }

  void _onWordSelected(String word, SelectableWord wordData) {
    setState(() {
      _selectedWord = word;
      _selectedWordData = wordData;
    });
  }

  Future<void> _addToVocabulary() async {
    if (_selectedWordData == null) return;

    await widget.conversationService.addWordToVocabulary(_selectedWordData!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_selectedWordData!.word}" to vocabulary'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() {
      _selectedWord = null;
      _selectedWordData = null;
    });
  }

  Future<void> _addToLearningPool() async {
    if (_selectedWordData == null) return;

    await widget.conversationService.addWordToLearningPool(_selectedWordData!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_selectedWordData!.word}" to learning pool'),
          backgroundColor: Colors.blue,
        ),
      );
    }

    setState(() {
      _selectedWord = null;
      _selectedWordData = null;
    });
  }

  Future<void> _showTranslation() async {
    if (_selectedWordData == null) return;

    final translation =
        await widget.conversationService.getWordTranslation(_selectedWordData!);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_selectedWordData!.word),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Translation: $translation'),
              if (_selectedWordData!.wordType != 'unknown')
                Text('Type: ${_selectedWordData!.wordType}'),
              if (_selectedWordData!.forms.isNotEmpty)
                Text('Forms: ${_selectedWordData!.forms.join(', ')}'),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final targetLang =
        widget.languageSettings.targetLanguage?.name ?? 'Target Language';

    return Scaffold(
      appBar: AppBar(
        title: Text('Conversation in $targetLang'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              widget.conversationService.clearConversation();
            },
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: widget.conversationService.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation in $targetLang',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The AI will only respond in $targetLang',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.conversationService.messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          widget.conversationService.messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Loading indicator
          if (widget.conversationService.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Text('AI is thinking...'),
                ],
              ),
            ),

          // Word selection actions
          if (_selectedWord != null && _selectedWordData != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected: "$_selectedWord"',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.translate),
                    onPressed: _showTranslation,
                    tooltip: 'Show translation',
                  ),
                  IconButton(
                    icon: Icon(
                      _selectedWordData!.isInVocabulary
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    onPressed: _selectedWordData!.isInVocabulary
                        ? null
                        : _addToVocabulary,
                    tooltip: _selectedWordData!.isInVocabulary
                        ? 'Already in vocabulary'
                        : 'Add to vocabulary',
                  ),
                  IconButton(
                    icon: Icon(
                      _selectedWordData!.isInLearningPool
                          ? Icons.star
                          : Icons.star_border,
                    ),
                    onPressed: _selectedWordData!.isInLearningPool
                        ? null
                        : _addToLearningPool,
                    tooltip: _selectedWordData!.isInLearningPool
                        ? 'Already in learning pool'
                        : 'Add to learning pool',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedWord = null;
                        _selectedWordData = null;
                      });
                    },
                    tooltip: 'Clear selection',
                  ),
                ],
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message in $targetLang...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: widget.conversationService.isLoading
                      ? null
                      : _sendMessage,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.type == ConversationMessageType.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.smart_toy,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == ConversationMessageType.user &&
                      message.correction != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Correction: ${message.correction}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.orange[800],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.type == ConversationMessageType.assistant &&
                      message.selectableWords.isNotEmpty)
                    SelectableTextWidget(
                      text: message.content,
                      selectableWords: message.selectableWords,
                      onWordSelected: _onWordSelected,
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isUser
                              ? Colors.white70
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
