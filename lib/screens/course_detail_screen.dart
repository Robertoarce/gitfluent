import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/course.dart';
import 'lesson_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                course.title,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                color: Colors.blue[50],
                child: Center(
                  child: Icon(
                    Icons.school,
                    size: 80,
                    color: Colors.blue[200],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.description,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Modules',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final module = course.modules[index];
                return _buildModuleCard(context, module, index + 1);
              },
              childCount: course.modules.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, Module module, int moduleNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          title: Text(
            'Module $moduleNumber: ${module.title}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            module.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          initiallyExpanded: true,
          children: module.lessons.map((lesson) {
            return ListTile(
              leading: const Icon(Icons.play_circle_outline, color: Color(0xFF6B47ED)),
              title: Text(lesson.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonScreen(lesson: lesson),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
