import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class ConversationStarterTopic {
  final String title;
  final String description;

  ConversationStarterTopic({required this.title, required this.description});

  factory ConversationStarterTopic.fromYaml(dynamic yaml) {
    return ConversationStarterTopic(
      title: yaml['title'] as String,
      description: yaml['description'] as String,
    );
  }
}

class ConversationStarterCategory {
  final String name;
  final List<ConversationStarterTopic> topics;

  ConversationStarterCategory({required this.name, required this.topics});

  factory ConversationStarterCategory.fromYaml(dynamic yaml) {
    final List<dynamic> topicsYaml = yaml['topics'] as List<dynamic>;
    final List<ConversationStarterTopic> topics = topicsYaml
        .map((topicYaml) => ConversationStarterTopic.fromYaml(topicYaml))
        .toList();

    return ConversationStarterCategory(
      name: yaml['name'] as String,
      topics: topics,
    );
  }
}

class ConversationStarterService {
  static Future<List<ConversationStarterCategory>> loadStarters() async {
    try {
      final String yamlString =
          await rootBundle.loadString('lib/config/conversation_starters.yaml');
      final dynamic yamlData = loadYaml(yamlString);

      final List<dynamic> categoriesYaml =
          yamlData['categories'] as List<dynamic>;
      return categoriesYaml
          .map((categoryYaml) =>
              ConversationStarterCategory.fromYaml(categoryYaml))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading conversation starters: $e');
      return [];
    }
  }
}
