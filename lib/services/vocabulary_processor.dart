import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../models/language_response.dart';
import '../models/vocabulary_item.dart';
import '../services/chat_service.dart';
import '../services/vocabulary_service.dart';

// Widget that displays vocabulary buttons
class VocabularyButtons extends StatelessWidget {
  final Message message;
  final LanguageResponse? parsedResponse;

  const VocabularyButtons({
    Key? key, 
    required this.message,
    this.parsedResponse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show vocabulary for user messages
    if (message.isUser) {
      return const SizedBox();
    }
    
    // Use StatefulBuilder to handle state updates
    return StatefulBuilder(
      builder: (context, setState) {
        return VocabularyButtonsContent(
          message: message,
          parsedResponse: parsedResponse,
        );
      },
    );
  }
}

class VocabularyButtonsContent extends StatefulWidget {
  final Message message;
  final LanguageResponse? parsedResponse;

  const VocabularyButtonsContent({
    Key? key, 
    required this.message,
    this.parsedResponse,
  }) : super(key: key);

  @override
  State<VocabularyButtonsContent> createState() => VocabularyButtonsContentState();
}

class VocabularyButtonsContentState extends State<VocabularyButtonsContent> {
  bool _isLoading = true;
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
    
    // Process the message after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processMessage();
    });
  }

  Future<void> _processMessage() async {
    try {
      final content = widget.message.content;
      debugPrint('Vocabulary processor: processing message content of length: ${content.length}');
      
      // If we already have a parsed response, use it
      if (widget.parsedResponse != null) {
        debugPrint('Vocabulary processor: Using pre-parsed JSON response');
        _processLanguageResponse(widget.parsedResponse!);
        return;
      }
      
      // Try to parse as JSON
      LanguageResponse? languageResponse = _tryParseJson(content);
      
      if (languageResponse != null) {
        debugPrint('Vocabulary processor: Successfully parsed JSON response');
        // Process structured JSON response
        _processLanguageResponse(languageResponse);
        return;
      }
      
      // If direct parsing failed, try more aggressive extraction
      if (content.contains('vocabulary_breakdown')) {
        debugPrint('Vocabulary processor: Found vocabulary_breakdown in content, trying aggressive extraction');
        final String potentialJson = _extractJsonAggressively(content);
        if (potentialJson.isNotEmpty) {
          try {
            final extractedResponse = LanguageResponse.fromJson(json.decode(potentialJson));
            debugPrint('Vocabulary processor: Successfully parsed JSON with aggressive extraction');
            _processLanguageResponse(extractedResponse);
            return;
          } catch (e) {
            debugPrint('Vocabulary processor: Aggressive JSON extraction failed: $e');
          }
        }
      }
      
      // If all parsing attempts failed, display empty state
      debugPrint('Vocabulary processor: No structured JSON found in response');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Vocabulary processor: Error processing message: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Try to parse content as JSON and convert to LanguageResponse
  LanguageResponse? _tryParseJson(String content) {
    try {
      // First try direct parsing of the entire content
      return LanguageResponse.fromJson(json.decode(content));
    } catch (e) {
      debugPrint('Vocabulary processor: Direct JSON parsing failed, trying regex extraction');
      
      // Try to extract JSON if it's embedded in text
      final jsonRegex = RegExp(r'(\{[\s\S]*\})');
      final match = jsonRegex.firstMatch(content);
      
      if (match != null) {
        try {
          final jsonString = match.group(1);
          if (jsonString != null) {
            return LanguageResponse.fromJson(json.decode(jsonString));
          }
        } catch (e) {
          debugPrint('Vocabulary processor: Regex JSON extraction failed: $e');
        }
      }
    }
    return null;
  }
  
  // More aggressive JSON extraction
  String _extractJsonAggressively(String content) {
    // Look for patterns like ```json...``` or just {...} with newlines
    final jsonCodeBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonCodeBlockRegex.firstMatch(content);
    
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    
    // If no code block, try to find outermost {...} that contains "vocabulary_breakdown"
    int startBrace = content.indexOf('{');
    if (startBrace != -1) {
      int depth = 0;
      int endBrace = -1;
      
      for (int i = startBrace; i < content.length; i++) {
        if (content[i] == '{') {
          depth++;
        } else if (content[i] == '}') {
          depth--;
          if (depth == 0) {
            endBrace = i;
            break;
          }
        }
      }
      
      if (endBrace != -1) {
        return content.substring(startBrace, endBrace + 1);
      }
    }
    
    return '';
  }
  
  // Process structured LanguageResponse
  void _processLanguageResponse(LanguageResponse response) {
    debugPrint('=================== VOCABULARY DEBUG START ===================');
    debugPrint('Processing LanguageResponse with ${response.vocabularyBreakdown.length} vocabulary items');
    
    // Print the full response for debugging
    for (int i = 0; i < response.vocabularyBreakdown.length; i++) {
      final item = response.vocabularyBreakdown[i];
      debugPrint('Item $i: word=${item.word}, type=${item.wordType}, baseForm=${item.baseForm}');
      debugPrint('  forms: ${item.forms.join(', ')}');
      debugPrint('  translations: ${item.translations.join(', ')}');
    }
    
    // Clear existing collections to ensure clean processing
    _verbs.clear();
    _nouns.clear();
    _adverbs.clear();
    _conjugations.clear();
    _definitions.clear();
    
    try {
      for (final item in response.vocabularyBreakdown) {
        final String word = item.word;
        final String wordType = item.wordType;
        final String baseForm = item.baseForm;
        final List<String> forms = item.forms;
        final List<String> translations = item.translations;
        
        if (word.isEmpty) {
          debugPrint('Skipping empty word');
          continue;
        }
        
        String translationText = translations.isNotEmpty 
            ? translations.first 
            : '';
        
        debugPrint('Processing word: $word, type: $wordType');
        
        // Process based on word type (standardize to lowercase for comparison)
        final String lowerWordType = wordType.toLowerCase();
        
        if (lowerWordType.contains('verb')) {
          // Use base form for verbs instead of the conjugated form
          final String verbKey = baseForm.isNotEmpty ? baseForm : word;
          _verbs[verbKey] = translationText;
          
          // Process verb conjugations
          Map<String, dynamic> conjugationMap = {};
          for (int i = 0; i < forms.length; i++) {
            String key = i == 0 ? 'infinitive' : 'form$i';
            conjugationMap[key] = forms[i];
          }
          _conjugations[verbKey] = conjugationMap;
          debugPrint('Added verb: $verbKey (base form) with ${conjugationMap.length} conjugations');
          
        } else if (lowerWordType.contains('noun')) {
          _nouns[word] = translationText;
          if (baseForm.isNotEmpty) {
            _definitions[word] = 'Base form: $baseForm';
          }
          debugPrint('Added noun: $word');
          
        } else {
          // Default to adverbs for all other word types
          _adverbs[word] = translationText;
          if (baseForm.isNotEmpty) {
            _definitions[word] = 'Base form: $baseForm';
          }
          debugPrint('Added other word type: $word (type: $wordType)');
        }
      }
      
      // Debug summary
      debugPrint('Maps after processing:');
      debugPrint('_verbs: ${_verbs.keys.join(', ')}');
      debugPrint('_nouns: ${_nouns.keys.join(', ')}');
      debugPrint('_adverbs: ${_adverbs.keys.join(', ')}');
      debugPrint('After processing: ${_verbs.length} verbs, ${_nouns.length} nouns, and ${_adverbs.length} adverbs/others');
      
      // Important: Update the UI
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error processing vocabulary: $e');
      debugPrint(e.toString());
      if (e is Error) {
        debugPrint(e.stackTrace.toString());
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    debugPrint('=================== VOCABULARY DEBUG END ===================');
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

    // Force rebuild to ensure maps have been populated
    final int verbCount = _verbs.length;
    final int nounCount = _nouns.length;
    final int adverbCount = _adverbs.length;
    debugPrint('Building vocabulary buttons with $verbCount verbs, $nounCount nouns, and $adverbCount adverbs');

    // Don't show anything if there are no vocabulary items
    if (verbCount + nounCount + adverbCount == 0) {
      debugPrint('No vocabulary items to display');
      return const SizedBox();
    }

    // Create the vocabulary chips
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ..._verbs.entries.map((entry) => VocabularyChip(
                word: entry.key,
                type: VocabularyItem.typeVerb,
                translation: entry.value,
                conjugations: _conjugations[entry.key],
                conversationId: _conversationId,
              )),
          ..._nouns.entries.map((entry) => VocabularyChip(
                word: entry.key,
                type: VocabularyItem.typeNoun,
                translation: entry.value,
                definition: _definitions[entry.key],
                conversationId: _conversationId,
              )),
          ..._adverbs.entries.map((entry) => VocabularyChip(
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

class VocabularyChip extends StatefulWidget {
  final String word;
  final String type;
  final String translation;
  final Map<String, dynamic>? conjugations;
  final String? definition;
  final String conversationId;

  const VocabularyChip({
    Key? key,
    required this.word,
    required this.type,
    required this.translation,
    this.conjugations,
    this.definition,
    required this.conversationId,
  }) : super(key: key);

  @override
  State<VocabularyChip> createState() => VocabularyChipState();
}

class VocabularyChipState extends State<VocabularyChip> {
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
      if (isAdverb) return Colors.purple.shade700;
      return Colors.grey.shade700;
    }
    
    Color getBackgroundColor() {
      if (_isAdded) return Colors.green.shade50;
      if (isVerb) return Colors.blue.shade50;
      if (isNoun) return Colors.green.shade50;
      if (isAdverb) return Colors.purple.shade50;
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