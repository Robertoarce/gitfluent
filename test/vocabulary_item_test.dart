import 'package:flutter_test/flutter_test.dart';
import 'package:llm_chat_app/models/vocabulary_item.dart';
import 'package:llm_chat_app/models/user_vocabulary.dart';

void main() {
  group('VocabularyItem', () {
    test(
        'fromUserVocabularyItem correctly maps verb with forms to conjugations',
        () {
      final userItem = UserVocabularyItem(
        id: '1',
        userId: 'user1',
        word: 'testare',
        baseForm: 'testare',
        wordType: 'verb',
        language: 'it',
        translations: ['to test'],
        forms: ['io testo', 'tu testi'],
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
      );

      final vocabularyItem = VocabularyItem.fromUserVocabularyItem(userItem);

      expect(vocabularyItem.word, 'testare');
      expect(vocabularyItem.type, VocabularyItem.typeVerb);
      expect(vocabularyItem.translation, 'to test');
      expect(vocabularyItem.definition, isNull);
      expect(vocabularyItem.conjugations, {
        'forms': ['io testo', 'tu testi']
      });
    });

    test(
        'fromUserVocabularyItem correctly maps noun with example sentence to definition',
        () {
      final userItem = UserVocabularyItem(
        id: '2',
        userId: 'user1',
        word: 'casa',
        baseForm: 'casa',
        wordType: 'noun',
        language: 'it',
        translations: ['house'],
        exampleSentences: ['La casa è bella.'],
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
      );

      final vocabularyItem = VocabularyItem.fromUserVocabularyItem(userItem);

      expect(vocabularyItem.word, 'casa');
      expect(vocabularyItem.type, VocabularyItem.typeNoun);
      expect(vocabularyItem.translation, 'house');
      expect(vocabularyItem.definition, 'La casa è bella.');
      expect(vocabularyItem.conjugations, isNull);
    });

    test(
        'fromUserVocabularyItem handles missing example sentences for definition',
        () {
      final userItem = UserVocabularyItem(
        id: '3',
        userId: 'user1',
        word: 'albero',
        baseForm: 'albero',
        wordType: 'noun',
        language: 'it',
        translations: ['tree'],
        exampleSentences: [], // Empty example sentences
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
      );

      final vocabularyItem = VocabularyItem.fromUserVocabularyItem(userItem);

      expect(vocabularyItem.definition, isNull);
    });

    test('fromUserVocabularyItem handles unknown word type', () {
      final userItem = UserVocabularyItem(
        id: '4',
        userId: 'user1',
        word: 'quickly',
        baseForm: 'quickly',
        wordType: 'adjective',
        language: 'en',
        translations: ['velocemente'],
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
      );

      final vocabularyItem = VocabularyItem.fromUserVocabularyItem(userItem);

      expect(vocabularyItem.type, 'other'); // Should default to 'other'
    });
  });
}
