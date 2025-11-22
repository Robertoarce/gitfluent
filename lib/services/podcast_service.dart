import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import '../models/podcast.dart';

class PodcastService {
  GenerativeModel? _geminiModel;

  PodcastService() {
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
        temperature: 0.7,
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<PodcastScript> generatePodcast({
    required String topic,
    required String targetLanguage,
    required String nativeLanguage,
    String level = 'Beginner',
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
You are a podcast producer creating educational language learning content.

# TASK
Create a short podcast script (approx. 10-15 exchanges) about "$topic".
Target Language: $targetLanguage
Level: $level
Format: A conversation between a "Teacher" (explaining in $nativeLanguage) and a "Student" (practicing in $targetLanguage) OR two people conversing naturally in $targetLanguage with occasional explanations.

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following schema:

{
  "title": "Podcast Title",
  "topic": "$topic",
  "dialogue": [
    {
      "speaker": "Teacher", 
      "text": "Hello! Today we are talking about food.",
      "language_code": "en"
    },
    {
      "speaker": "Student",
      "text": "Ciao! Mi piace il cibo.",
      "language_code": "it"
    }
  ]
}

# REQUIREMENTS
- Ensure the dialogue is engaging and educational.
- Use correct language codes (e.g., 'en', 'it', 'es', 'fr', 'de').
- The 'speaker' should be consistent (e.g., Host/Guest or Teacher/Student).
''';

      debugPrint('Generating podcast with Gemini...');
      final response = await _geminiModel!.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        throw Exception('No response received from Gemini');
      }

      final jsonMap = json.decode(response.text!);
      return PodcastScript.fromJson(jsonMap);

    } catch (e) {
      debugPrint('Error generating podcast: $e');
      rethrow;
    }
  }
}
