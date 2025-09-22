import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'settings_service.dart';
import 'language_settings_service.dart';
import 'vocabulary_service.dart';
import '../models/vocabulary_item.dart';
import '../utils/debug_helper.dart';

enum ConversationMessageType { user, assistant, system }

class ConversationMessage {
  final String id;
  final String content;
  final ConversationMessageType type;
  final DateTime timestamp;
  final String? correction;
  final List<SelectableWord> selectableWords;
  final String? rawLLMResponse;

  ConversationMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.correction,
    this.selectableWords = const [],
    this.rawLLMResponse,
  });

  factory ConversationMessage.user(String content, {String? correction}) {
    return ConversationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: ConversationMessageType.user,
      timestamp: DateTime.now(),
      correction: correction,
    );
  }

  factory ConversationMessage.assistant(
    String content, {
    List<SelectableWord> selectableWords = const [],
    String? rawLLMResponse,
  }) {
    return ConversationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: ConversationMessageType.assistant,
      timestamp: DateTime.now(),
      selectableWords: selectableWords,
      rawLLMResponse: rawLLMResponse,
    );
  }

  factory ConversationMessage.system(String content) {
    return ConversationMessage(
      id: 'system',
      content: content,
      type: ConversationMessageType.system,
      timestamp: DateTime.now(),
    );
  }
}

class SelectableWord {
  final String word;
  final String baseForm;
  final String wordType;
  final List<String> translations;
  final List<String> forms;
  final int startIndex;
  final int endIndex;
  final bool isInVocabulary;
  final bool isInLearningPool;
  final int? occurrenceLevel; // For learning pool frequency

  SelectableWord({
    required this.word,
    required this.baseForm,
    required this.wordType,
    required this.translations,
    required this.forms,
    required this.startIndex,
    required this.endIndex,
    this.isInVocabulary = false,
    this.isInLearningPool = false,
    this.occurrenceLevel,
  });

  SelectableWord copyWith({
    String? word,
    String? baseForm,
    String? wordType,
    List<String>? translations,
    List<String>? forms,
    int? startIndex,
    int? endIndex,
    bool? isInVocabulary,
    bool? isInLearningPool,
    int? occurrenceLevel,
  }) {
    return SelectableWord(
      word: word ?? this.word,
      baseForm: baseForm ?? this.baseForm,
      wordType: wordType ?? this.wordType,
      translations: translations ?? this.translations,
      forms: forms ?? this.forms,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      isInVocabulary: isInVocabulary ?? this.isInVocabulary,
      isInLearningPool: isInLearningPool ?? this.isInLearningPool,
      occurrenceLevel: occurrenceLevel ?? this.occurrenceLevel,
    );
  }
}

class ConversationService extends ChangeNotifier {
  final List<ConversationMessage> _messages = [];
  bool _isLoading = false;
  ChatOpenAI? _openAILlm;
  GenerativeModel? _geminiModel;
  final SettingsService _settings;
  final LanguageSettings _languageSettings;
  final VocabularyService _vocabularyService;

  String _systemPrompt = '';

  // Getters
  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get systemPrompt => _systemPrompt;

  ConversationService({
    required SettingsService settings,
    required LanguageSettings languageSettings,
    required VocabularyService vocabularyService,
  })  : _settings = settings,
        _languageSettings = languageSettings,
        _vocabularyService = vocabularyService {
    _initializeSystemPrompt();
    _initializeAI();
    _settings.addListener(_initializeAI);
    _languageSettings.addListener(_updateSystemPrompt);
  }

  void _initializeSystemPrompt() {
    final targetLang =
        _languageSettings.targetLanguage?.name ?? 'Target Language';
    final nativeLang =
        _languageSettings.nativeLanguage?.name ?? 'Native Language';

    _systemPrompt = '''
You are a language learning assistant. Your role is to have conversations with the user to help them learn $targetLang.

CRITICAL RULES:
1. You MUST respond ONLY in $targetLang. Never use any other language in your responses.
2. If the user writes in a language other than $targetLang, you should still respond in $targetLang.
3. Keep your responses natural and conversational, appropriate for a language learner.
4. If the user makes grammatical errors, provide gentle corrections in $targetLang.
5. Use vocabulary and grammar appropriate for the user's learning level.
6. Encourage the user and make the conversation engaging.

When the user sends a message, you should:
1. Respond naturally in $targetLang
2. If there are obvious grammar errors, provide a corrected version
3. Keep the conversation flowing naturally

Remember: ALWAYS respond in $targetLang only. Never use $nativeLang or any other language in your responses.
''';
  }

  void _updateSystemPrompt() {
    _initializeSystemPrompt();
    notifyListeners();
  }

  void _initializeAI() {
    try {
      final provider = _settings.currentProvider;
      DebugHelper.printDebug(
          'conversation_service', 'Initializing AI provider: ${provider.name}');

      switch (provider) {
        case AIProvider.openai:
          final apiKey = dotenv.env['OPENAI_API_KEY'];
          if (apiKey == null || apiKey.isEmpty) {
            _addErrorMessage(
                'Error: OpenAI API key not found in .env file. Please add OPENAI_API_KEY to your .env file.');
            return;
          }
          _openAILlm = ChatOpenAI(
            apiKey: apiKey,
            defaultOptions: ChatOpenAIOptions(
              model: 'gpt-4',
              temperature: 0.7,
            ),
          );
          DebugHelper.printDebug(
              'conversation_service', 'OpenAI initialized successfully');
          break;

        case AIProvider.gemini:
          final apiKey = dotenv.env['GEMINI_API_KEY'];
          if (apiKey == null || apiKey.isEmpty) {
            _addErrorMessage(
                'Error: Gemini API key not found in .env file. Please add GEMINI_API_KEY to your .env file.');
            return;
          }
          _geminiModel = GenerativeModel(
            model: 'gemini-2.0-flash',
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.7,
              maxOutputTokens: 2048,
            ),
          );
          DebugHelper.printDebug(
              'conversation_service', 'Gemini initialized successfully');
          break;
      }
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error initializing AI: $e');
      _addErrorMessage('Error initializing AI provider: $e');
    }
  }

  void _addErrorMessage(String message) {
    _messages.add(ConversationMessage.assistant(message));
    notifyListeners();
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Check for grammar errors in user input
    final correction = await _checkGrammar(message);

    // Add user message with potential correction
    _messages.add(ConversationMessage.user(message, correction: correction));
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      String response;
      String rawLLMResponse;

      switch (_settings.currentProvider) {
        case AIProvider.openai:
          if (_openAILlm == null) {
            throw Exception(
                'OpenAI not initialized. Please check your API key.');
          }

          final prompt = PromptValue.string('''
$_systemPrompt

Previous conversation context:
${_messages.where((msg) => msg.type != ConversationMessageType.system).map((msg) => "${msg.type == ConversationMessageType.user ? 'User' : 'Assistant'}: ${msg.content}").join('\n')}

User: $message
Assistant:''');

          final llmResponse = await _openAILlm!.invoke(prompt);
          response = llmResponse.firstOutput.content;
          rawLLMResponse = response;
          break;

        case AIProvider.gemini:
          if (_geminiModel == null) {
            throw Exception(
                'Gemini not initialized. Please check your API key.');
          }

          final prompt = '''
$_systemPrompt

Previous conversation context:
${_messages.where((msg) => msg.type != ConversationMessageType.system).map((msg) => "${msg.type == ConversationMessageType.user ? 'User' : 'Assistant'}: ${msg.content}").join('\n')}

User: $message
Assistant:''';

          DebugHelper.printDebug(
              'conversation_service', 'Sending prompt to Gemini: $prompt');

          final llmResponse =
              await _geminiModel!.generateContent([Content.text(prompt)]);

          if (llmResponse.text == null) {
            throw Exception('No response received from Gemini');
          }

          response = llmResponse.text!;
          rawLLMResponse = response;
          break;
      }

      // Process the response to extract selectable words
      final selectableWords = await _extractSelectableWords(response);

      // Add assistant message with selectable words
      _messages.add(ConversationMessage.assistant(
        response,
        selectableWords: selectableWords,
        rawLLMResponse: rawLLMResponse,
      ));
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error sending message: $e');
      _messages.add(ConversationMessage.assistant(
        'Sorry, I encountered an error. Please try again.\nError: $e',
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _checkGrammar(String message) async {
    // Simple grammar checking - in a real implementation, you might use
    // a dedicated grammar checking service or more sophisticated NLP
    try {
      // For now, we'll do basic checks
      // In a real implementation, you'd call a grammar checking API
      if (message.trim().isEmpty) return null;

      // This is a placeholder - replace with actual grammar checking
      return null;
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error checking grammar: $e');
      return null;
    }
  }

  Future<List<SelectableWord>> _extractSelectableWords(String text) async {
    final List<SelectableWord> selectableWords = [];

    try {
      // Simple word extraction - split by whitespace and punctuation
      final words = text.split(RegExp(r'\s+'));
      int currentIndex = 0;

      for (final word in words) {
        if (word.trim().isEmpty) continue;

        // Find the word's position in the original text
        final startIndex = text.indexOf(word, currentIndex);
        if (startIndex == -1) continue;

        final endIndex = startIndex + word.length;
        currentIndex = endIndex;

        // Clean the word (remove punctuation)
        final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
        if (cleanWord.isEmpty) continue;

        // Check if word is already in vocabulary
        final isInVocabulary = await _isWordInVocabulary(cleanWord);
        final isInLearningPool = await _isWordInLearningPool(cleanWord);

        // Get word information (type, forms, translations)
        final wordInfo = await _getWordInfo(cleanWord);

        selectableWords.add(SelectableWord(
          word: cleanWord,
          baseForm: wordInfo['baseForm'] ?? cleanWord,
          wordType: wordInfo['wordType'] ?? 'unknown',
          translations: wordInfo['translations'] ?? [],
          forms: wordInfo['forms'] ?? [],
          startIndex: startIndex,
          endIndex: endIndex,
          isInVocabulary: isInVocabulary,
          isInLearningPool: isInLearningPool,
          occurrenceLevel: wordInfo['occurrenceLevel'],
        ));
      }
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error extracting selectable words: $e');
    }

    return selectableWords;
  }

  Future<bool> _isWordInVocabulary(String word) async {
    try {
      final vocabItems = _vocabularyService.items;
      return vocabItems
          .any((item) => item.word.toLowerCase() == word.toLowerCase());
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error checking vocabulary: $e');
      return false;
    }
  }

  Future<bool> _isWordInLearningPool(String word) async {
    try {
      // Check if word is in learning pool (words with higher occurrence levels)
      final vocabItems = _vocabularyService.items;
      final item = vocabItems.firstWhere(
        (item) => item.word.toLowerCase() == word.toLowerCase(),
        orElse: () => VocabularyItem(
          word: '',
          type: '',
          translation: '',
        ),
      );

      // For now, consider words with higher addedCount as being in learning pool
      return item.addedCount > 3;
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error checking learning pool: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _getWordInfo(String word) async {
    try {
      // Try to get word info from existing vocabulary
      final vocabItems = _vocabularyService.items;
      final existingItem = vocabItems.firstWhere(
        (item) => item.word.toLowerCase() == word.toLowerCase(),
        orElse: () => VocabularyItem(
          word: '',
          type: '',
          translation: '',
        ),
      );

      if (existingItem.word.isNotEmpty) {
        return {
          'baseForm': existingItem.word,
          'wordType': existingItem.type,
          'translations': [existingItem.translation],
          'forms': existingItem.conjugations?['forms']?.cast<String>() ?? [],
          'occurrenceLevel': existingItem.addedCount,
        };
      }

      // If not in vocabulary, return basic info
      return {
        'baseForm': word,
        'wordType': 'unknown',
        'translations': [],
        'forms': [],
        'occurrenceLevel': 0,
      };
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error getting word info: $e');
      return {
        'baseForm': word,
        'wordType': 'unknown',
        'translations': [],
        'forms': [],
        'occurrenceLevel': 0,
      };
    }
  }

  Future<void> addWordToVocabulary(SelectableWord word) async {
    try {
      if (word.translations.isEmpty) {
        DebugHelper.printDebug('conversation_service',
            'No translations available for word: ${word.word}');
        return;
      }

      await _vocabularyService.addOrUpdateItem(
        word.word,
        word.wordType,
        word.translations.first,
        definition:
            word.translations.isNotEmpty ? word.translations.first : null,
        conjugations: word.forms.isNotEmpty ? {'forms': word.forms} : null,
        conversationId: _messages.isNotEmpty ? _messages.last.id : null,
      );

      DebugHelper.printDebug(
          'conversation_service', 'Added word to vocabulary: ${word.word}');
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error adding word to vocabulary: $e');
    }
  }

  Future<void> addWordToLearningPool(SelectableWord word,
      {int occurrenceLevel = 5}) async {
    try {
      // First add to vocabulary if not already there
      if (!word.isInVocabulary) {
        await addWordToVocabulary(word);
      }

      // Then mark as high priority for learning pool
      // This could involve updating the word's occurrence level or adding special tags
      DebugHelper.printDebug('conversation_service',
          'Added word to learning pool: ${word.word} with level $occurrenceLevel');
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error adding word to learning pool: $e');
    }
  }

  Future<String> getWordTranslation(SelectableWord word) async {
    try {
      if (word.translations.isNotEmpty) {
        return word.translations.first;
      }

      // If no translation available, try to get from vocabulary
      final vocabItems = _vocabularyService.items;
      final existingItem = vocabItems.firstWhere(
        (item) => item.word.toLowerCase() == word.word.toLowerCase(),
        orElse: () => VocabularyItem(
          word: '',
          type: '',
          translation: '',
        ),
      );

      if (existingItem.word.isNotEmpty) {
        return existingItem.translation;
      }

      return 'Translation not available';
    } catch (e) {
      DebugHelper.printDebug(
          'conversation_service', 'Error getting word translation: $e');
      return 'Translation not available';
    }
  }

  void clearConversation() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(_initializeAI);
    _languageSettings.removeListener(_updateSystemPrompt);
    super.dispose();
  }
}
