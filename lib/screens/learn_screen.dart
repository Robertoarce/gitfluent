import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/course_service.dart';
import '../services/user_service.dart';
import '../models/course.dart';
import 'course_detail_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final List<Course> _courses = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Learn'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? _buildEmptyState()
              : _buildCourseList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCourseDialog,
        label: const Text('New Course'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF6B47ED),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No courses yet',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a custom AI course to start learning',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return _buildCourseCard(course);
      },
    );
  }

  Widget _buildCourseCard(Course course) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(course: course),
          ),
        );
      },
      child: ShadCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    course.level,
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              course.description,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.library_books, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${course.modules.length} Modules',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.language, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  course.targetLanguage.toUpperCase(),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCourseDialog() {
    final topicController = TextEditingController();
    String selectedLevel = 'Beginner';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic (e.g., Travel, Business, Food)',
                  hintText: 'What do you want to learn about?',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedLevel,
                decoration: const InputDecoration(labelText: 'Level'),
                items: ['Beginner', 'Intermediate', 'Advanced']
                    .map((level) => DropdownMenuItem(
                          value: level,
                          child: Text(level),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedLevel = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generateCourse(topicController.text, selectedLevel);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateCourse(String topic, String level) async {
    if (topic.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final courseService = context.read<CourseService>();
      final userService = context.read<UserService>();
      
      final targetLang = userService.currentUser?.targetLanguage ?? 'it';
      final nativeLang = userService.currentUser?.nativeLanguage ?? 'en';

      final course = await courseService.generateCourse(
        topic: topic,
        targetLanguage: _getLanguageName(targetLang),
        nativeLanguage: _getLanguageName(nativeLang),
        level: level,
      );

      setState(() {
        _courses.insert(0, course);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create course: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
}
