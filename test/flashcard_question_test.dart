import 'package:flutter_test/flutter_test.dart';
import 'package:llm_chat_app/models/flashcard_question.dart';
import 'package:llm_chat_app/models/user_vocabulary.dart';

void main() {
  group('FlashcardQuestionType', () {
    test('enum values are correct', () {
      expect(FlashcardQuestionType.traditional.name, 'traditional');
      expect(FlashcardQuestionType.reverse.name, 'reverse');
      expect(FlashcardQuestionType.multipleChoice.name, 'multipleChoice');
      expect(FlashcardQuestionType.fillInBlank.name, 'fillInBlank');
    });
  });

  group('FlashcardQuestion', () {
    late UserVocabularyItem testVocabularyItem;

    setUp(() {
      testVocabularyItem = UserVocabularyItem(
        id: 'vocab-123',
        userId: 'user-456',
        word: 'casa',
        baseForm: 'casa',
        wordType: 'noun',
        language: 'it',
        translations: ['house', 'home'],
        exampleSentences: ['La casa è bella', 'Vado a casa'],
        lastSeen: DateTime.now(),
        firstLearned: DateTime.now(),
      );
    });

    group('Traditional Flashcard', () {
      test('constructor sets properties correctly', () {
        final question = FlashcardQuestion(
          id: 'q-1',
          type: FlashcardQuestionType.traditional,
          vocabularyItem: testVocabularyItem,
          question: 'What does "casa" mean?',
          correctAnswer: 'house',
        );

        expect(question.id, 'q-1');
        expect(question.type, FlashcardQuestionType.traditional);
        expect(question.vocabularyItem, testVocabularyItem);
        expect(question.question, 'What does "casa" mean?');
        expect(question.correctAnswer, 'house');
        expect(question.options, isEmpty);
        expect(question.context, isNull);
      });

      test('traditional factory constructor creates correct question', () {
        final question = FlashcardQuestion.traditional(
          id: 'traditional-1',
          vocabularyItem: testVocabularyItem,
        );

        expect(question.id, 'traditional-1');
        expect(question.type, FlashcardQuestionType.traditional);
        expect(question.vocabularyItem, testVocabularyItem);
        expect(question.question, 'casa');
        expect(question.correctAnswer, 'house');
        expect(question.options, isEmpty);
        expect(question.context, isNull);
      });
    });

    group('Reverse Flashcard', () {
      test('reverse factory constructor creates correct question', () {
        final question = FlashcardQuestion.reverse(
          id: 'reverse-1',
          vocabularyItem: testVocabularyItem,
        );

        expect(question.id, 'reverse-1');
        expect(question.type, FlashcardQuestionType.reverse);
        expect(question.vocabularyItem, testVocabularyItem);
        expect(question.question, 'house');
        expect(question.correctAnswer, 'casa');
        expect(question.options, isEmpty);
        expect(question.context, isNull);
      });
    });

    group('Multiple Choice', () {
      test('multipleChoice factory constructor creates correct question', () {
        final distractors = ['car', 'dog', 'book'];
        final question = FlashcardQuestion.multipleChoice(
          id: 'mc-1',
          vocabularyItem: testVocabularyItem,
          distractors: distractors,
        );

        expect(question.id, 'mc-1');
        expect(question.type, FlashcardQuestionType.multipleChoice);
        expect(question.vocabularyItem, testVocabularyItem);
        expect(question.question, 'What does "casa" mean?');
        expect(question.correctAnswer, 'house');
        expect(question.options, isNotNull);
        expect(question.options!.length, 4); // 1 correct + 3 distractors
        expect(question.options!.contains('house'), true);
        expect(question.options!.contains('car'), true);
        expect(question.options!.contains('dog'), true);
        expect(question.options!.contains('book'), true);
        expect(question.context, isNull);
      });

      test('multipleChoice handles insufficient distractors', () {
        final distractors = ['car']; // Only 1 distractor
        final question = FlashcardQuestion.multipleChoice(
          id: 'mc-2',
          vocabularyItem: testVocabularyItem,
          distractors: distractors,
        );

        expect(question.options!.length, 2); // 1 correct + 1 distractor
        expect(question.options!.contains('house'), true);
        expect(question.options!.contains('car'), true);
      });

      test('multipleChoice options are shuffled', () {
        final distractors = ['car', 'dog', 'book'];
        final questions = List.generate(
            10,
            (i) => FlashcardQuestion.multipleChoice(
                  id: 'mc-$i',
                  vocabularyItem: testVocabularyItem,
                  distractors: distractors,
                ));

        // Check that not all questions have the same order
        final firstOrder = questions[0].options!;
        final hasDifferentOrder =
            questions.any((q) => !_listsEqual(q.options!, firstOrder));

        expect(hasDifferentOrder, true);
      });
    });

    group('Fill-in-the-blank', () {
      test('fillInBlank factory constructor creates correct question', () {
        final question = FlashcardQuestion.fillInBlank(
          id: 'fib-1',
          vocabularyItem: testVocabularyItem,
          customContext: 'La casa è bella',
        );

        expect(question.id, 'fib-1');
        expect(question.type, FlashcardQuestionType.fillInBlank);
        expect(question.vocabularyItem, testVocabularyItem);
        expect(question.question, 'La ____ è bella');
        expect(question.correctAnswer, 'casa');
        expect(question.options, isEmpty);
        expect(question.context, 'La casa è bella');
      });

      test('fillInBlank uses example sentence when no context provided', () {
        final question = FlashcardQuestion.fillInBlank(
          id: 'fib-2',
          vocabularyItem: testVocabularyItem,
        );

        expect(question.context, isNotNull);
        expect(question.context!.contains('casa'), true);
        expect(question.question, 'La ____ è bella');
      });
    });

    group('Answer Validation', () {
      late FlashcardQuestion traditionalQuestion;
      late FlashcardQuestion multipleChoiceQuestion;
      late FlashcardQuestion fillInBlankQuestion;

      setUp(() {
        traditionalQuestion = FlashcardQuestion.traditional(
          id: 'trad',
          vocabularyItem: testVocabularyItem,
        );

        multipleChoiceQuestion = FlashcardQuestion.multipleChoice(
          id: 'mc',
          vocabularyItem: testVocabularyItem,
          distractors: ['car', 'dog', 'book'],
        );

        fillInBlankQuestion = FlashcardQuestion.fillInBlank(
          id: 'fib',
          vocabularyItem: testVocabularyItem,
          customContext: 'La ___ è bella',
        );
      });

      test('isCorrectAnswer validates traditional questions correctly', () {
        expect(traditionalQuestion.isCorrectAnswer('house'), true);
        expect(traditionalQuestion.isCorrectAnswer('House'),
            true); // Case insensitive
        expect(traditionalQuestion.isCorrectAnswer('HOUSE'), true);
        expect(traditionalQuestion.isCorrectAnswer('home'),
            false); // Only first translation is correct
        expect(traditionalQuestion.isCorrectAnswer('car'), false);
        expect(traditionalQuestion.isCorrectAnswer(''), false);
      });

      test('isCorrectAnswer validates multiple choice correctly', () {
        expect(multipleChoiceQuestion.isCorrectAnswer('house'), true);
        expect(multipleChoiceQuestion.isCorrectAnswer('House'), true);
        expect(multipleChoiceQuestion.isCorrectAnswer('home'),
            false); // Only first translation is correct
        expect(multipleChoiceQuestion.isCorrectAnswer('car'), false);
        expect(multipleChoiceQuestion.isCorrectAnswer('invalid'), false);
      });

      test('isCorrectAnswer validates fill-in-blank correctly', () {
        expect(fillInBlankQuestion.isCorrectAnswer('casa'), true);
        expect(fillInBlankQuestion.isCorrectAnswer('Casa'), true);
        expect(fillInBlankQuestion.isCorrectAnswer('CASA'), true);
        expect(fillInBlankQuestion.isCorrectAnswer('house'), false);
        expect(fillInBlankQuestion.isCorrectAnswer('car'), false);
      });

      test('isCorrectAnswer handles edge cases', () {
        expect(
            traditionalQuestion.isCorrectAnswer('  house  '), true); // Trimmed
        expect(traditionalQuestion.isCorrectAnswer('house!'),
            false); // Extra characters
        expect(traditionalQuestion.isCorrectAnswer('houses'), false); // Plural
      });
    });

    group('Hints', () {
      test('getHint returns appropriate hints for different question types',
          () {
        final traditionalQuestion = FlashcardQuestion.traditional(
          id: 'trad',
          vocabularyItem: testVocabularyItem,
        );

        final multipleChoiceQuestion = FlashcardQuestion.multipleChoice(
          id: 'mc',
          vocabularyItem: testVocabularyItem,
          distractors: ['car', 'dog', 'book'],
        );

        final fillInBlankQuestion = FlashcardQuestion.fillInBlank(
          id: 'fib',
          vocabularyItem: testVocabularyItem,
          customContext: 'La ___ è bella',
        );

        expect(traditionalQuestion.getHint(), equals('Type: noun'));
        expect(multipleChoiceQuestion.getHint(), equals('Starts with: H'));
        expect(fillInBlankQuestion.getHint(), equals('Length: 4 letters'));
      });

      test('getHint handles vocabulary items without definitions', () {
        final simpleVocab = UserVocabularyItem(
          id: 'simple',
          userId: 'user',
          word: 'test',
          baseForm: 'test',
          wordType: 'noun',
          language: 'en',
          translations: ['prova'],
          lastSeen: DateTime.now(),
          firstLearned: DateTime.now(),
        );

        final question = FlashcardQuestion.traditional(
          id: 'simple-q',
          vocabularyItem: simpleVocab,
        );

        final hint = question.getHint();
        expect(hint, isNotNull);
        expect(hint?.length, greaterThan(0));
      });
    });

    group('Equality and Hash Code', () {
      test('questions with same id are equal', () {
        final question1 = FlashcardQuestion.traditional(
          id: 'same-id',
          vocabularyItem: testVocabularyItem,
        );

        final question2 = FlashcardQuestion.traditional(
          id: 'same-id',
          vocabularyItem: testVocabularyItem,
        );

        expect(question1, equals(question2));
        expect(question1.hashCode, equals(question2.hashCode));
      });

      test('questions with different ids are not equal', () {
        final question1 = FlashcardQuestion.traditional(
          id: 'id-1',
          vocabularyItem: testVocabularyItem,
        );

        final question2 = FlashcardQuestion.traditional(
          id: 'id-2',
          vocabularyItem: testVocabularyItem,
        );

        expect(question1, isNot(equals(question2)));
        expect(question1.hashCode, isNot(equals(question2.hashCode)));
      });
    });
  });
}

/// Helper function to compare two lists for equality
bool _listsEqual<T>(List<T> list1, List<T> list2) {
  if (list1.length != list2.length) return false;
  for (int i = 0; i < list1.length; i++) {
    if (list1[i] != list2[i]) return false;
  }
  return true;
}
