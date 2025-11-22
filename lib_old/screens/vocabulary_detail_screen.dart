import 'package:flutter/material.dart';
import '../models/vocabulary_item.dart';
import 'flashcard_start_screen.dart';
// import '../services/vocabulary_service.dart';
// import 'package:provider/provider.dart';

class VocabularyDetailScreen extends StatelessWidget {
  final VocabularyItem item;

  const VocabularyDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.word),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement edit functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (item.definition != null) ...[
              _buildSection('Definition', item.definition!),
              const SizedBox(height: 24),
            ],
            if (item.type == VocabularyItem.typeVerb &&
                item.conjugations != null)
              _buildConjugationsSection(item.conjugations!),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FlashcardStartScreen(),
            ),
          );
        },
        icon: const Icon(Icons.quiz),
        label: const Text('Study Flashcards'),
        tooltip: 'Practice this word with flashcards',
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item.word,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    item.type,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _getTypeColor(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.translation,
              style: const TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (item.type) {
      case VocabularyItem.typeVerb:
        return Colors.blue.shade700;
      case VocabularyItem.typeNoun:
        return Colors.green.shade700;
      case VocabularyItem.typeAdverb:
        return Colors.purple.shade700;
      case VocabularyItem.typeOther: // Added for new type
        return Colors.orange.shade700; // Choose an appropriate color
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConjugationsSection(Map<String, dynamic> conjugations) {
    final List<dynamic>? forms = conjugations['forms'];

    if (forms == null || forms.isEmpty) {
      return const SizedBox
          .shrink(); // Return empty widget if no forms are present
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conjugations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Iterate directly over the forms list
              children: forms.map((formEntry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    formEntry.toString(), // Display the form entry as a string
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
