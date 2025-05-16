import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vocabulary_service.dart';

class VocabularyReviewScreen extends StatelessWidget {
  const VocabularyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vocabulary Review'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Verbs'),
              Tab(text: 'Nouns'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VocabularyList(type: 'all'),
            _VocabularyList(type: 'verb'),
            _VocabularyList(type: 'noun'),
          ],
        ),
      ),
    );
  }
}

class _VocabularyList extends StatelessWidget {
  final String type;

  const _VocabularyList({required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyService>(
      builder: (context, vocabularyService, child) {
        final items = switch (type) {
          'verb' => vocabularyService.verbs,
          'noun' => vocabularyService.nouns,
          _ => vocabularyService.vocabulary.values.toList(),
        };

        if (items.isEmpty) {
          return Center(
            child: Text(
              'No ${type == "all" ? "vocabulary" : type}s saved yet',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.type == 'verb' 
                      ? Colors.blue.shade100 
                      : Colors.green.shade100,
                  child: Text(
                    item.word[0].toUpperCase(),
                    style: TextStyle(
                      color: item.type == 'verb' 
                          ? Colors.blue.shade900 
                          : Colors.green.shade900,
                    ),
                  ),
                ),
                title: Text(item.word),
                subtitle: Text(item.translation),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.type == 'verb' 
                            ? Colors.blue.shade50 
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.count}×',
                        style: TextStyle(
                          color: item.type == 'verb' 
                              ? Colors.blue.shade900 
                              : Colors.green.shade900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        vocabularyService.removeItem(item.word);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
} 