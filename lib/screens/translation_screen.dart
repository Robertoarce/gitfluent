import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import '../services/translation_service.dart';
import '../services/user_service.dart';
import '../models/language_response.dart';
import '../models/user_vocabulary.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _textController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isLoading = false;
  LanguageResponse? _translationResult;
  String? _error;
  
  // TTS State
  bool _isPlaying = false;
  int? _currentWordStart;
  int? _currentWordEnd;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("it-IT"); // Default to Italian
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isPlaying = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isPlaying = false;
        _currentWordStart = null;
        _currentWordEnd = null;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isPlaying = false;
        _currentWordStart = null;
        _currentWordEnd = null;
      });
    });
    
    _flutterTts.setProgressHandler((text, start, end, word) {
      setState(() {
        _currentWordStart = start;
        _currentWordEnd = end;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _handleTranslate() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _translationResult = null;
    });

    try {
      final translationService = context.read<TranslationService>();
      final userService = context.read<UserService>();
      
      final targetLang = userService.currentUser?.targetLanguage ?? 'it';
      final nativeLang = userService.currentUser?.nativeLanguage ?? 'en';

      // Update TTS language based on target language
      // Simple mapping, should be more robust in production
      String ttsLang = 'it-IT';
      if (targetLang == 'es') ttsLang = 'es-ES';
      if (targetLang == 'fr') ttsLang = 'fr-FR';
      if (targetLang == 'de') ttsLang = 'de-DE';
      await _flutterTts.setLanguage(ttsLang);

      final result = await translationService.translateAndAnalyze(
        text: _textController.text,
        targetLanguage: _getLanguageName(targetLang),
        nativeLanguage: _getLanguageName(nativeLang),
      );

      setState(() {
        _translationResult = result;
      });
    } catch (e) {
      setState(() {
        _error = 'Translation failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'it': return 'Italian';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'en': return 'English';
      default: return 'Italian';
    }
  }

  Future<void> _speak(String text) async {
    if (_isPlaying) {
      await _flutterTts.stop();
    } else {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _addToVocabulary(VocabularyItem item) async {
    final userService = context.read<UserService>();
    if (!userService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save vocabulary')),
      );
      return;
    }

    try {
      final newItem = UserVocabularyItem(
        id: const Uuid().v4(),
        userId: userService.currentUser!.id,
        word: item.word,
        baseForm: item.baseForm,
        wordType: item.wordType,
        language: userService.currentUser?.targetLanguage ?? 'it',
        translations: item.translations,
        forms: item.forms,
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
        nextReview: DateTime.now().add(const Duration(days: 1)),
      );

      await userService.saveVocabularyItem(newItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "${item.word}" to vocabulary')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Translate & Learn'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Input Area
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter text to translate...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onSubmitted: (_) => _handleTranslate(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton(
                      onPressed: _isLoading ? null : _handleTranslate,
                      icon: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.translate),
                      child: Text(_isLoading ? 'Translating...' : 'Translate'),
                    ),
                  ),
                ],
              ),
            ),

            // Results Area
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _translationResult == null
                      ? _buildEmptyState()
                      : _buildResultList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Enter text to get started',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Translation Card
        _buildTranslationCard(),
        
        const SizedBox(height: 16),
        
        // Corrections (if any)
        if (_translationResult!.corrections.isNotEmpty && 
            !(_translationResult!.corrections.length == 1 && _translationResult!.corrections.first == 'None.'))
          _buildCorrectionsCard(),
          
        const SizedBox(height: 16),
        
        // Vocabulary Breakdown
        if (_translationResult!.vocabularyBreakdown.isNotEmpty)
          _buildVocabularySection(),
          
        const SizedBox(height: 16),
        
        // Additional Context
        if (_translationResult!.additionalContext != null)
          _buildContextCard(),
      ],
    );
  }

  Widget _buildTranslationCard() {
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Translation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.stop_circle : Icons.volume_up),
                color: const Color(0xFF6B47ED),
                onPressed: () => _speak(_translationResult!.targetLanguageSentence),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _translationResult!.targetLanguageSentence,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _translationResult!.nativeLanguageTranslation,
            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionsCard() {
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Corrections',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._translationResult!.corrections.map((correction) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(correction)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildVocabularySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Vocabulary Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        ..._translationResult!.vocabularyBreakdown.map((item) => _buildVocabularyItem(item)),
      ],
    );
  }

  Widget _buildVocabularyItem(VocabularyItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Text(
              item.word,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Text(
                item.wordType,
                style: TextStyle(fontSize: 12, color: Colors.blue[800]),
              ),
            ),
          ],
        ),
        subtitle: Text(
          item.translations.join(', '),
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark_add_outlined),
          color: const Color(0xFF6B47ED),
          onPressed: () => _addToVocabulary(item),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Base Form', item.baseForm),
                const SizedBox(height: 8),
                const Text('Forms:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.forms.map((form) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(form, style: const TextStyle(fontSize: 13)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(value),
      ],
    );
  }

  Widget _buildContextCard() {
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Additional Context',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_translationResult!.additionalContext!),
        ],
      ),
    );
  }
}
