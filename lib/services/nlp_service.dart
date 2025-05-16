import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class WordInfo {
  final String word;
  final String type;
  final String lemma;
  final String pos;

  WordInfo({
    required this.word,
    required this.type,
    required this.lemma,
    required this.pos,
  });
}

class NLPService {
  static const Map<String, List<String>> _verbEndings = {
    'it': ['are', 'ere', 'ire'],
    'es': ['ar', 'er', 'ir'],
    'fr': ['er', 'ir', 're'],
  };

  static const Map<String, List<String>> _nounEndings = {
    'it': ['o', 'a', 'e', 'i', 'tà', 'tù', 'ione'],
    'es': ['o', 'a', 'os', 'as', 'ción', 'sión', 'dad'],
    'fr': ['tion', 'sion', 'ment', 'age', 'eur', 'esse', 'té'],
  };

  static const Map<String, Set<String>> _commonWords = {
    'it': {
      'il', 'lo', 'la', 'i', 'gli', 'le',
      'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
      'e', 'o', 'ma', 'se', 'perché', 'quando',
    },
    'es': {
      'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
      'de', 'a', 'en', 'con', 'por', 'para', 'sobre', 'entre',
      'y', 'o', 'pero', 'si', 'porque', 'cuando',
    },
    'fr': {
      'le', 'la', 'les', 'un', 'une', 'des',
      'de', 'à', 'en', 'dans', 'sur', 'sous', 'avec', 'par', 'pour',
      'et', 'ou', 'mais', 'si', 'parce', 'quand',
    },
  };

  static Future<List<WordInfo>> analyzeText(String text, String language) async {
    try {
      final words = text.split(RegExp(r'\s+'));
      final List<WordInfo> results = [];

      for (final word in words) {
        final normalized = word.toLowerCase().trim()
            .replaceAll(RegExp(r'[.,!?]'), '');
        
        if (normalized.isEmpty) continue;
        if (_commonWords[language]?.contains(normalized) ?? false) continue;

        String type = 'unknown';
        String lemma = normalized;

        // Check for verbs first (they usually have longer endings)
        if (_isVerb(normalized, language)) {
          type = 'verb';
          lemma = _getLemma(normalized, language);
        } 
        // Then check for nouns
        else if (_isNoun(normalized, language)) {
          type = 'noun';
          lemma = normalized;
        }

        results.add(WordInfo(
          word: normalized,
          type: type,
          lemma: lemma,
          pos: type.toUpperCase(),
        ));
      }

      return results;
    } catch (e) {
      debugPrint('Error analyzing text: $e');
      return [];
    }
  }

  static bool _isVerb(String word, String language) {
    final endings = _verbEndings[language] ?? [];
    return endings.any((ending) => word.endsWith(ending));
  }

  static bool _isNoun(String word, String language) {
    final endings = _nounEndings[language] ?? [];
    return endings.any((ending) => word.endsWith(ending));
  }

  static String _getLemma(String word, String language) {
    // Simple lemmatization: remove conjugation endings
    if (language == 'it') {
      for (final ending in ['o', 'i', 'a', 'amo', 'ate', 'ano', 
                          'evo', 'evi', 'eva', 'evamo', 'evate', 'evano',
                          'isco', 'isci', 'isce', 'iamo', 'ite', 'iscono']) {
        if (word.endsWith(ending)) {
          // Find the infinitive form
          final stem = word.substring(0, word.length - ending.length);
          if (word.contains('isc')) {
            return '$stem' 'ire';
          } else if (word.contains('ev')) {
            return '$stem' 'ere';
          } else {
            return '$stem' 'are';
          }
        }
      }
    }
    // Add similar patterns for Spanish and French
    
    return word;
  }
} 