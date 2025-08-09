import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vocabulary_service.dart';
import '../models/vocabulary_item.dart';
import 'vocabulary_detail_screen.dart';
import 'flashcard_start_screen.dart';
import '../utils/flashcard_route_transitions.dart';

class VocabularyReviewScreen extends StatelessWidget {
  const VocabularyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vocabulary Review'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Verbs'),
              Tab(text: 'Nouns'),
              Tab(text: 'Adverbs'),
            ],
          ),
        ),
        body: Consumer<VocabularyService>(
          builder: (context, vocabularyService, child) {
            if (!vocabularyService.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Get items
            final List<VocabularyItem> allItems =
                List.from(vocabularyService.items);
            final List<VocabularyItem> verbs =
                vocabularyService.getItemsByType(VocabularyItem.typeVerb);
            final List<VocabularyItem> nouns =
                vocabularyService.getItemsByType(VocabularyItem.typeNoun);
            final List<VocabularyItem> adverbs =
                vocabularyService.getItemsByType(VocabularyItem.typeAdverb);

            return TabBarView(
              children: [
                _buildWordList(context, allItems),
                _buildWordList(context, verbs),
                _buildWordList(context, nouns),
                _buildWordList(context, adverbs),
              ],
            );
          },
        ),
        floatingActionButton: Consumer<VocabularyService>(
          builder: (context, vocabularyService, child) {
            final hasVocabulary = vocabularyService.items.isNotEmpty;

            return FloatingActionButton.extended(
              onPressed: hasVocabulary
                  ? () {
                      FlashcardNavigation.toFlashcardStart(context);
                    }
                  : null,
              icon: const Icon(Icons.quiz),
              label: const Text('Study Flashcards'),
              backgroundColor: hasVocabulary
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              foregroundColor: hasVocabulary
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: hasVocabulary
                  ? 'Start flashcard study session'
                  : 'Add vocabulary words to study with flashcards',
            );
          },
        ),
      ),
    );
  }

  Widget _buildWordList(BuildContext context, List<VocabularyItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items yet',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getItemBackgroundColor(item.type, context),
              child: Icon(
                _getItemIcon(item.type),
                color: _getItemColor(item.type, context),
              ),
            ),
            title: Text(
              item.word,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.translation),
                if (item.definition != null ||
                    (item.type == VocabularyItem.typeVerb &&
                        item.conjugations != null))
                  Text(
                    item.type == VocabularyItem.typeVerb
                        ? 'Has conjugations'
                        : 'Has definition',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Added: ${item.addedCount}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VocabularyDetailScreen(item: item),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getItemBackgroundColor(String type, BuildContext context) {
    switch (type) {
      case VocabularyItem.typeVerb:
        return Colors.blue.shade100;
      case VocabularyItem.typeNoun:
        return Colors.green.shade100;
      case VocabularyItem.typeAdverb:
        return Colors.purple.shade100;
      default:
        return Theme.of(context).colorScheme.surfaceVariant;
    }
  }

  Color _getItemColor(String type, BuildContext context) {
    switch (type) {
      case VocabularyItem.typeVerb:
        return Colors.blue.shade700;
      case VocabularyItem.typeNoun:
        return Colors.green.shade700;
      case VocabularyItem.typeAdverb:
        return Colors.purple.shade700;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData _getItemIcon(String type) {
    switch (type) {
      case VocabularyItem.typeVerb:
        return Icons.run_circle;
      case VocabularyItem.typeNoun:
        return Icons.label;
      case VocabularyItem.typeAdverb:
        return Icons.speed;
      default:
        return Icons.help_outline;
    }
  }
}
