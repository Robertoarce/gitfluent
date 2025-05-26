import 'package:flutter/material.dart';
import '../models/vocabulary_item.dart';
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
            if (item.type == 'verb' && item.conjugations != null)
              _buildConjugationsSection(item.conjugations!),
            const SizedBox(height: 24),
            _buildStatsSection(),
          ],
        ),
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
              children: conjugations.entries.map((entry) {
                final tense = entry.key;
                final conjugation = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tense,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getTypeColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (conjugation is String)
                        Text(
                          conjugation,
                          style: const TextStyle(fontSize: 15),
                        )
                      else if (conjugation is Map)
                        ...conjugation.entries.map((conj) => Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 4,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${conj.key}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(conj.value.toString()),
                            ],
                          ),
                        )),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatRow('Added', item.dateAdded),
            if (item.lastAdded != null)
              _buildStatRow('Last Added', item.lastAdded!),
            _buildStatRow('Times Added', item.addedCount.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    String displayValue = value is DateTime 
        ? _formatDate(value)
        : value.toString();
        
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          Text(
            displayValue,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 