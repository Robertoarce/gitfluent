import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/course.dart';

class LessonScreen extends StatelessWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
      ),
      body: Markdown(
        data: lesson.content,
        padding: const EdgeInsets.all(16),
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          p: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
          listBullet: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
