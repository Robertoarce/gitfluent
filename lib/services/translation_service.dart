import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import '../models/language_response.dart';

class TranslationService {
  GenerativeModel? _geminiModel;
  
  // Structured JSON output schema - copied from Prompts.dart for self-containment
  static const String _jsonOutputSchema = '''
{
  "type": "object",
  "properties": {
    "corrections": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "List of corrections. If no corrections, the array should contain 'None.'",
      "minItems": 1
    },
    "target_language_sentence": {
      "type": "string",
      "description": "The corrected sentence in the target language."
    },
    "native_language_translation": {
      "type": "string",
      "description": "Direct translation of the corrected sentence into the native language."
    },
    "vocabulary_breakdown": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "word": {
            "type": "string",
            "description": "The specific word being broken down."
          },
          "word_type": {
            "type": "string",
            "description": "e.g., Verb, Noun, Adverb, Adjective, Preposition, etc."
          },
          "base_form": {
            "type": "string",
            "description": "Infinitive or base form of the word."
          },
          "forms": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "For verbs, include all conjugations (infinitive, present, past, future) with their respective pronouns (e.g., 'io, parlo (Present)'). For other word types, include plural forms, gendered forms, or other relevant variations. Each form is a string."
          },
          "translations": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "Translations of the word and its forms."
          }
        },
        "required": ["word", "word_type", "base_form", "forms", "translations"]
      },
      "description": "Detailed breakdown of key vocabulary in the sentence."
    },
    "additional_context": {
      "type": "string",
      "description": "Optional additional context in support languages, if needed.",
      "nullable": true
    },
    "languages_used":{
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "List of languages used, such as {target_language}, {native_language}, {support_language_1} and or {support_language_2}."
    }
  },
  "required": [
    "corrections",
    "target_language_sentence",
    "native_language_translation",
    "vocabulary_breakdown"
  ]
}
''';

  TranslationService() {
    _initializeAI();
  }

  void _initializeAI() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Error: Gemini API key not found in .env file.');
      return;
    }

    _geminiModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2, // Low temperature for deterministic results
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<LanguageResponse?> translateAndAnalyze({
    required String text,
    required String targetLanguage,
    required String nativeLanguage,
    String supportLanguage1 = 'es',
    String supportLanguage2 = 'fr',
  }) async {
    if (_geminiModel == null) {
      _initializeAI();
      if (_geminiModel == null) {
        throw Exception('AI Service not initialized. Check API key.');
      }
    }

    try {
      final prompt = '''
# ROLE
You are a deterministic language learning professor with 40 years of experience helping a user learn $targetLanguage. Your primary goal is to provide a structured JSON response.

# TASK
Given a sentence in $nativeLanguage (or potentially mixed with $targetLanguage) provided by the user: "$text"
1. Identify and correct any grammatical or usage errors if the user attempted $targetLanguage.
2. Translate the text into $targetLanguage (if it's in $nativeLanguage) or correct it (if it's in $targetLanguage).
3. Provide a detailed vocabulary breakdown for key words in the sentence.
4. If essential for understanding, include additional context in $supportLanguage1 or $supportLanguage2.

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following JSON Schema. Do NOT include any other text.

$_jsonOutputSchema

# RULES FOR GENERATION
- For 'corrections', if there are no errors, the array must contain exactly one string: "None.". Otherwise, list each correction as a separate string.
- For 'vocabulary_breakdown', ensure each 'word_type' is specific (e.g., "Verb", "Noun", "Adjective").
- For 'forms' within 'vocabulary_breakdown', **it is crucial to include all relevant forms and conjugations**. For verbs, list the infinitive, and conjugated forms for present, past (e.g., passato remoto), and future tenses, each with its corresponding pronoun (e.g., 'io, parlo', 'tu, parli'). For nouns, include plural forms. Each form must be a distinct string.
- Ensure all relevant pronouns are included before verbs in the corrected $targetLanguage sentence.
- Ensure articles are included before nouns in the corrected $targetLanguage sentence, unless standard usage in $targetLanguage dictates otherwise.
- The 'additional_context' field is optional. If no additional context is needed, omit this field or set its value to `null`.
''';

      debugPrint('Sending translation request to Gemini...');
      final response = await _geminiModel!.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        throw Exception('No response received from Gemini');
      }

      debugPrint('Received response from Gemini');
      // debugPrint(response.text);

      // Parse JSON
      final jsonString = response.text!;
      final jsonMap = json.decode(jsonString);
      
      return LanguageResponse.fromJson(jsonMap);
    } catch (e) {
      debugPrint('Error in translation service: $e');
      rethrow;
    }
  }
}
