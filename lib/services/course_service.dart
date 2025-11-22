import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/course.dart';

class CourseService {
  GenerativeModel? _geminiModel;

  CourseService() {
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

  Future<Course> generateCourse({
    required String topic,
    required String targetLanguage,
    required String nativeLanguage,
    required String level,
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
You are an expert language curriculum designer.

# TASK
Create a structured language course for learning $targetLanguage (for $nativeLanguage speakers).
Topic/Focus: $topic
Level: $level

# OUTPUT FORMAT
Generate a **single JSON object** that strictly adheres to the following schema:

{
  "title": "Course Title",
  "description": "Brief description of the course",
  "modules": [
    {
      "title": "Module Title",
      "description": "Module description",
      "lessons": [
        {
          "title": "Lesson Title",
          "content": "Detailed lesson content in Markdown format. Include explanations, examples, and cultural notes. Keep it engaging and educational."
        }
      ]
    }
  ]
}

# REQUIREMENTS
- Create at least 2 modules.
- Each module should have at least 2 lessons.
- Content should be high quality and suitable for the requested level.
''';

      debugPrint('Generating course with Gemini...');
      final response = await _geminiModel!.generateContent([Content.text(prompt)]);
      
      if (response.text == null) {
        throw Exception('No response received from Gemini');
      }

      final jsonMap = json.decode(response.text!);
      
      // Convert JSON to Course model
      final List<Module> modules = [];
      for (final m in jsonMap['modules']) {
        final List<Lesson> lessons = [];
        for (final l in m['lessons']) {
          lessons.add(Lesson(
            id: const Uuid().v4(),
            title: l['title'],
            content: l['content'],
          ));
        }
        modules.add(Module(
          id: const Uuid().v4(),
          title: m['title'],
          description: m['description'],
          lessons: lessons,
        ));
      }

      return Course(
        id: const Uuid().v4(),
        title: jsonMap['title'],
        description: jsonMap['description'],
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
        level: level,
        modules: modules,
        createdAt: DateTime.now(),
        isGenerated: true,
      );

    } catch (e) {
      debugPrint('Error generating course: $e');
      rethrow;
    }
  }
}
