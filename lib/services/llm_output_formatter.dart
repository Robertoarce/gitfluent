import 'package:flutter/material.dart';
import '../models/language_response.dart';

/// A service for formatting LLM output in a structured way
class LlmOutputFormatter {
  /// Format a LanguageResponse into a structured UI display
  static Widget formatResponse(LanguageResponse response) {
    debugPrint('LlmOutputFormatter: formatting response');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original text with corrections
        if (response.corrections.isNotEmpty)
          _buildCorrectionSection(response.corrections, response.targetLanguageSentence),
          
        // Translation section
        _buildTranslationSection(response.targetLanguageSentence, response.nativeLanguageTranslation),
        
        // Vocabulary breakdown
        if (response.vocabularyBreakdown.isNotEmpty)
          _buildVocabularySection(response.vocabularyBreakdown),
        
        // Additional context if available
        if (response.additionalContext != null && response.additionalContext!.isNotEmpty)
          _buildAdditionalContext(response.additionalContext!),
      ],
    );
  }
  
  /// Builds the corrections section showing original text with corrections
  static Widget _buildCorrectionSection(List<String> corrections, String correctedText) {
    // Skip if corrected text is empty
    if (correctedText.isEmpty) {
      return const SizedBox();
    }
    
    final bool hasCorrections = !(corrections.length == 1 && corrections[0] == "None.");
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasCorrections ? Icons.edit : Icons.check_circle,
                  color: hasCorrections ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Corrections',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              correctedText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasCorrections) ...[
              const SizedBox(height: 8),
              ...corrections.map((correction) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(correction),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Builds the translation section
  static Widget _buildTranslationSection(String targetText, String nativeText) {
    // Skip if both texts are empty
    if (targetText.isEmpty && nativeText.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Translation',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (targetText.isNotEmpty)
              SelectableText(
                targetText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (targetText.isNotEmpty && nativeText.isNotEmpty)
              const SizedBox(height: 8),
            if (nativeText.isNotEmpty)
              SelectableText(
                nativeText,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Builds the vocabulary breakdown section
  static Widget _buildVocabularySection(List<VocabularyBreakdown> vocabulary) {
    // Skip if vocabulary is empty
    if (vocabulary.isEmpty) {
      return const SizedBox();
    }
    
    try {
      // Group vocabulary by type
      final verbs = vocabulary.where((item) => 
        item.wordType.toLowerCase().contains('verb')).toList();
      final nouns = vocabulary.where((item) => 
        item.wordType.toLowerCase().contains('noun')).toList();
      final others = vocabulary.where((item) => 
        !item.wordType.toLowerCase().contains('verb') && 
        !item.wordType.toLowerCase().contains('noun')).toList();
      
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'Vocabulary',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Divider(),
              
              // Verbs section
              if (verbs.isNotEmpty) ...[
                _buildVocabularyTypeHeader('Verbs', Icons.run_circle, Colors.blue),
                ...verbs.map((verb) => _buildVocabularyItem(verb)),
                const SizedBox(height: 8),
              ],
              
              // Nouns section
              if (nouns.isNotEmpty) ...[
                _buildVocabularyTypeHeader('Nouns', Icons.label, Colors.green),
                ...nouns.map((noun) => _buildVocabularyItem(noun)),
                const SizedBox(height: 8),
              ],
              
              // Other words section
              if (others.isNotEmpty) ...[
                _buildVocabularyTypeHeader('Other Words', Icons.text_fields, Colors.orange),
                ...others.map((other) => _buildVocabularyItem(other)),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building vocabulary section: $e');
      return const SizedBox();
    }
  }
  
  /// Builds a header for a vocabulary type section
  static Widget _buildVocabularyTypeHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds a single vocabulary item display
  static Widget _buildVocabularyItem(VocabularyBreakdown item) {
    if (item.word.isEmpty) {
      return const SizedBox();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.word} ',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (item.baseForm.isNotEmpty && item.baseForm != item.word)
                Text(
                  '(${item.baseForm})',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
          ),
          if (item.translations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                item.translations.join(', '),
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                ),
              ),
            ),
          if (item.forms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                'Forms: ${item.forms.join(', ')}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Builds the additional context section if available
  static Widget _buildAdditionalContext(String context) {
    if (context.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Additional Context',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              context,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 