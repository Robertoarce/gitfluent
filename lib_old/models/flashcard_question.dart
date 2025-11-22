import '../models/user_vocabulary.dart';

enum FlashcardQuestionType {
  traditional,
  multipleChoice,
  fillInBlank,
  reverse,
}

class FlashcardQuestion {
  final String id;
  final UserVocabularyItem vocabularyItem;
  final FlashcardQuestionType type;
  final String question;
  final String correctAnswer;
  final List<String> options; // For multiple choice questions
  final String? context; // For fill-in-blank questions
  final DateTime createdAt;

  FlashcardQuestion({
    required this.id,
    required this.vocabularyItem,
    required this.type,
    required this.question,
    required this.correctAnswer,
    this.options = const [],
    this.context,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Factory constructor for traditional flashcard (word -> translation)
  factory FlashcardQuestion.traditional({
    required String id,
    required UserVocabularyItem vocabularyItem,
  }) {
    return FlashcardQuestion(
      id: id,
      vocabularyItem: vocabularyItem,
      type: FlashcardQuestionType.traditional,
      question: vocabularyItem.word,
      correctAnswer: vocabularyItem.translations.isNotEmpty
          ? vocabularyItem.translations.first
          : '',
    );
  }

  // Factory constructor for reverse flashcard (translation -> word)
  factory FlashcardQuestion.reverse({
    required String id,
    required UserVocabularyItem vocabularyItem,
  }) {
    return FlashcardQuestion(
      id: id,
      vocabularyItem: vocabularyItem,
      type: FlashcardQuestionType.reverse,
      question: vocabularyItem.translations.isNotEmpty
          ? vocabularyItem.translations.first
          : '',
      correctAnswer: vocabularyItem.word,
    );
  }

  // Factory constructor for multiple choice question
  factory FlashcardQuestion.multipleChoice({
    required String id,
    required UserVocabularyItem vocabularyItem,
    required List<String> distractors,
  }) {
    final correctAnswer = vocabularyItem.translations.isNotEmpty
        ? vocabularyItem.translations.first
        : '';

    // Create options list with correct answer and distractors
    final options = [correctAnswer, ...distractors];
    options.shuffle(); // Randomize order

    return FlashcardQuestion(
      id: id,
      vocabularyItem: vocabularyItem,
      type: FlashcardQuestionType.multipleChoice,
      question: 'What does "${vocabularyItem.word}" mean?',
      correctAnswer: correctAnswer,
      options: options,
    );
  }

  // Factory constructor for fill-in-the-blank question
  factory FlashcardQuestion.fillInBlank({
    required String id,
    required UserVocabularyItem vocabularyItem,
    String? customContext,
  }) {
    // Use example sentence if available, otherwise create a simple context
    String context = customContext ??
        (vocabularyItem.exampleSentences.isNotEmpty
            ? vocabularyItem.exampleSentences.first
            : 'Complete the sentence: "The word means ___"');

    // Replace the word with a blank
    final questionText = context.replaceAll(vocabularyItem.word, '____');

    return FlashcardQuestion(
      id: id,
      vocabularyItem: vocabularyItem,
      type: FlashcardQuestionType.fillInBlank,
      question: questionText,
      correctAnswer: vocabularyItem.word,
      context: context,
    );
  }

  // Check if a given answer is correct
  bool isCorrectAnswer(String userAnswer) {
    final normalizedUserAnswer = userAnswer.trim().toLowerCase();
    final normalizedCorrectAnswer = correctAnswer.trim().toLowerCase();

    // For traditional and reverse cards, check exact match
    if (type == FlashcardQuestionType.traditional ||
        type == FlashcardQuestionType.reverse) {
      return normalizedUserAnswer == normalizedCorrectAnswer;
    }

    // For multiple choice, check exact match
    if (type == FlashcardQuestionType.multipleChoice) {
      return normalizedUserAnswer == normalizedCorrectAnswer;
    }

    // For fill-in-blank, allow some flexibility
    if (type == FlashcardQuestionType.fillInBlank) {
      // Check if the answer contains the correct word or is the correct word
      return normalizedUserAnswer == normalizedCorrectAnswer ||
          normalizedCorrectAnswer.contains(normalizedUserAnswer);
    }

    return false;
  }

  // Get hint for the question
  String? getHint() {
    switch (type) {
      case FlashcardQuestionType.traditional:
      case FlashcardQuestionType.reverse:
        // For traditional cards, show word type as hint
        return 'Type: ${vocabularyItem.wordType}';

      case FlashcardQuestionType.multipleChoice:
        // For multiple choice, show first letter of correct answer
        return correctAnswer.isNotEmpty
            ? 'Starts with: ${correctAnswer[0].toUpperCase()}'
            : null;

      case FlashcardQuestionType.fillInBlank:
        // For fill-in-blank, show length of word
        return 'Length: ${correctAnswer.length} letters';
    }
  }

  // Get question type display name
  String get typeDisplayName {
    switch (type) {
      case FlashcardQuestionType.traditional:
        return 'Traditional';
      case FlashcardQuestionType.multipleChoice:
        return 'Multiple Choice';
      case FlashcardQuestionType.fillInBlank:
        return 'Fill in the Blank';
      case FlashcardQuestionType.reverse:
        return 'Reverse';
    }
  }

  // Get difficulty level based on vocabulary item mastery
  int get difficultyLevel => vocabularyItem.masteryLevel;

  // Check if this question needs review based on spaced repetition
  bool get needsReview => vocabularyItem.needsReview;

  FlashcardQuestion copyWith({
    String? id,
    UserVocabularyItem? vocabularyItem,
    FlashcardQuestionType? type,
    String? question,
    String? correctAnswer,
    List<String>? options,
    String? context,
    DateTime? createdAt,
  }) {
    return FlashcardQuestion(
      id: id ?? this.id,
      vocabularyItem: vocabularyItem ?? this.vocabularyItem,
      type: type ?? this.type,
      question: question ?? this.question,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
      context: context ?? this.context,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlashcardQuestion &&
        other.id == id &&
        other.vocabularyItem.id == vocabularyItem.id;
  }

  @override
  int get hashCode => Object.hash(id, vocabularyItem.id);

  @override
  String toString() {
    return 'FlashcardQuestion(id: $id, type: $typeDisplayName, question: $question)';
  }
}
