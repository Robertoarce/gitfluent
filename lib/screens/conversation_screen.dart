import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/conversation_service.dart';
import '../services/vocabulary_service.dart';
import '../services/language_settings_service.dart';
import '../widgets/selectable_text_widget.dart';
import '../config/custom_theme.dart';

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
          backgroundColor: CustomColorScheme.darkPink,
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
          backgroundColor: CustomColorScheme.lightBlue1,
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
      backgroundColor: CustomColorScheme.lightBlue2,
      appBar: AppBar(
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
              'AI Language Tutor',
              style: TextStyle(
                color: CustomColorScheme.darkGreen,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: CustomColorScheme.lightBlue2,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.clear,
              color: CustomColorScheme.darkGreen,
            ),
            onPressed: () {
              widget.conversationService.clearConversation();
            },
            tooltip: 'Clear conversation',
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
            // Messages area
            Expanded(
              child: widget.conversationService.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: CustomColorScheme.lightBlue3,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: CustomColorScheme.darkGreen,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Start a conversation in $targetLang',
                            style: TextStyle(
                              color: CustomColorScheme.darkGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The AI will only respond in $targetLang',
                            style: TextStyle(
                              color:
                                  CustomColorScheme.darkGreen.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
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
                          itemCount: widget.conversationService.messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                widget.conversationService.messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
                      ),
                    ),
            ),

            // Loading indicator
            if (widget.conversationService.isLoading)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CustomColorScheme.darkPink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'AI is thinking...',
                      style: TextStyle(
                        color: CustomColorScheme.darkGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Word selection actions
            if (_selectedWord != null && _selectedWordData != null)
              Container(
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selected: "$_selectedWord"',
                        style: TextStyle(
                          color: CustomColorScheme.darkGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.translate,
                        color: CustomColorScheme.darkPink,
                      ),
                      onPressed: _showTranslation,
                      tooltip: 'Show translation',
                    ),
                    IconButton(
                      icon: Icon(
                        _selectedWordData!.isInVocabulary
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: CustomColorScheme.darkPink,
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
                        color: CustomColorScheme.lightBlue1,
                      ),
                      onPressed: _selectedWordData!.isInLearningPool
                          ? null
                          : _addToLearningPool,
                      tooltip: _selectedWordData!.isInLearningPool
                          ? 'Already in learning pool'
                          : 'Add to learning pool',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: CustomColorScheme.darkGreen,
                      ),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
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
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(
                        color: CustomColorScheme.darkGreen,
                      ),
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
                    child: IconButton(
                      onPressed: widget.conversationService.isLoading
                          ? null
                          : _sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CustomColorScheme.darkPink,
                borderRadius: BorderRadius.circular(16),
              ),
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
                    ? CustomColorScheme.lightBlue1
                    : CustomColorScheme.lightBlue3,
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
                        color: CustomColorScheme.lightYellow.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: CustomColorScheme.lightYellow.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: CustomColorScheme.darkGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Correction: ${message.correction}',
                              style: TextStyle(
                                color: CustomColorScheme.darkGreen,
                                fontSize: 12,
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
                        color:
                            isUser ? Colors.white : CustomColorScheme.darkGreen,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CustomColorScheme.lightBlue1,
                borderRadius: BorderRadius.circular(16),
              ),
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
}
