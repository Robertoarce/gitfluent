# Flashcard Learning System Documentation

## Overview

The Flashcard Learning System is a comprehensive spaced repetition learning feature that helps users memorize vocabulary through adaptive flashcard sessions. The system uses intelligent algorithms to prioritize words based on difficulty, mastery level, and review schedule.

## Architecture

### Core Components

```
FlashcardService (Core Logic)
├── Word Selection Algorithm
├── Question Generation Engine
├── Session Management
├── Performance Tracking
└── Persistence Layer

UI Components
├── FlashcardWidget (Main Card Display)
├── ProgressWidget (Session Progress)
├── FeedbackWidget (Answer Feedback)
└── Screen Flow (Start → Study → Results)

Data Models
├── FlashcardSession (Session Data)
├── FlashcardSessionCard (Individual Card Data)
└── FlashcardQuestion (Question Structure)
```

### Database Schema

The system uses two main tables in Supabase:

#### `flashcard_sessions`

- `id` (UUID, PK): Unique session identifier
- `user_id` (UUID, FK): Reference to the user
- `duration_minutes` (INTEGER): Planned session duration
- `language` (TEXT): Target language filter
- `focus_word_types` (TEXT[]): Word types to focus on
- `total_questions` (INTEGER): Total questions in session
- `current_question_index` (INTEGER): Current question position
- `is_completed` (BOOLEAN): Session completion status
- `created_at` (TIMESTAMP): Session start time
- `updated_at` (TIMESTAMP): Last session update

#### `flashcard_session_cards`

- `id` (UUID, PK): Unique card identifier
- `session_id` (UUID, FK): Reference to flashcard session
- `vocabulary_item_id` (TEXT): Reference to vocabulary item
- `question_type` (TEXT): Type of question (traditional, multiple_choice, etc.)
- `is_correct` (BOOLEAN): Whether answer was correct
- `difficulty_rating` (TEXT): User's difficulty assessment
- `response_time_ms` (INTEGER): Time taken to answer
- `shown_at` (TIMESTAMP): When question was shown
- `answered_at` (TIMESTAMP): When question was answered

## Core Services

### FlashcardService

The main service that orchestrates all flashcard functionality.

#### Key Methods

```dart
// Session Management
Future<bool> startSession({
  required int durationMinutes,
  int? maxWords,
  String? language,
  List<String>? focusWordTypes,
  bool prioritizeReview = true,
  bool includeFavorites = true,
})

Future<void> pauseSession()
Future<void> resumeSession()
Future<void> completeSession()
Future<void> cancelSession()

// Question Navigation
Future<void> nextQuestion()
Future<void> previousQuestion()
bool hasNextQuestion()
bool hasPreviousQuestion()

// Answer Recording
Future<void> recordAnswer({
  required bool isCorrect,
  required String difficultyRating, // 'again', 'hard', 'good', 'easy'
  String? userAnswer,
})

// Word Selection & Question Generation
Future<List<UserVocabularyItem>> selectWordsForSession(...)
Future<List<FlashcardQuestion>> generateQuestionsForSession(...)
```

#### State Management

The service extends `ChangeNotifier` and maintains:

- Current session state
- Active question
- Session progress
- Performance statistics

#### Session Status Enum

```dart
enum FlashcardSessionStatus {
  notStarted,
  active,
  paused,
  completed,
  cancelled,
}
```

### Word Selection Algorithm

The system uses a sophisticated algorithm to select the most relevant words for study:

#### Selection Criteria

1. **Review Priority** (40% weight)

   - Words past their next review date
   - Based on spaced repetition schedule

2. **Mastery Level** (30% weight)

   - Words with lower mastery scores
   - Struggling words (< 40% mastery)

3. **Recency** (20% weight)

   - Recently learned words
   - Words not seen recently

4. **User Preferences** (10% weight)
   - Favorite words
   - Specific word types

#### Algorithm Steps

```dart
1. Filter by language and word types
2. Categorize words:
   - Review words (past next_review date)
   - Struggling words (mastery < 40%)
   - Recent words (learned < 7 days ago)
   - Regular words (remaining)
3. Apply weighted random selection
4. Sort by composite priority score
5. Return top N words
```

### Question Generation Engine

Supports multiple question types with intelligent generation:

#### Question Types

1. **Traditional** (40% weight)

   - Show word, ask for translation
   - Most common format

2. **Multiple Choice** (30% weight)

   - 4 options with smart distractors
   - Similar words or same word type

3. **Fill-in-the-Blank** (20% weight)

   - Context-based questions
   - Uses example sentences

4. **Reverse** (10% weight)
   - Show translation, ask for word
   - Advanced comprehension

#### Distractor Generation

For multiple choice questions:

- Same word type (noun, verb, etc.)
- Similar difficulty level
- Same language
- Avoid obvious wrong answers

## UI Components

### FlashcardWidget

Main card display component with 3D flip animations.

#### Features

- Smooth flip animations (AnimationController)
- Multiple question type support
- Self-assessment buttons
- Accessibility integration
- Responsive design

#### Usage

```dart
FlashcardWidget(
  question: currentQuestion,
  showAnswer: isAnswerRevealed,
  onShowAnswer: () => setState(() => isAnswerRevealed = true),
  onAnswerSubmitted: (answer) => handleAnswer(answer),
  onSelfAssessment: (rating) => handleSelfAssessment(rating),
)
```

### ProgressWidget

Session progress and statistics display.

#### Features

- Progress bar with animations
- Session timer and question timer
- Live accuracy statistics
- Pause/resume controls
- Responsive layouts

### FeedbackWidget

Immediate feedback for answers.

#### Features

- Elastic scale animations
- Color-coded feedback (green/red)
- Celebration effects for streaks
- Performance badges
- Contextual explanations

## Screen Flow

### 1. FlashcardStartScreen

Session configuration and setup.

#### Features

- Session duration selection (1-60 minutes)
- Language filtering
- Word type focus areas
- Resume interrupted sessions
- Quick start options

### 2. FlashcardScreen

Main study interface.

#### Features

- Question display and navigation
- Answer input/selection
- Self-assessment interface
- Session controls (pause/resume/exit)
- Progress tracking

### 3. FlashcardResultsScreen

Session results and analytics.

#### Features

- Performance summary
- Individual word performance
- Study recommendations
- Historical statistics
- Next session suggestions

## Performance Optimizations

### Database Efficiency

- Minimized database calls
- Batch operations where possible
- Efficient query patterns
- Local caching with SharedPreferences

### Memory Management

- Proper disposal of animation controllers
- Efficient list operations
- Minimal widget rebuilds
- Stream subscription management

### Algorithm Optimization

- O(n log n) sorting complexity
- Efficient filtering operations
- Smart caching of generated questions
- Minimal redundant calculations

### Measured Performance Metrics

- Word selection: <10ms for 10,000 words
- Question generation: <1ms per question
- Session operations: <100ms end-to-end
- Memory usage: Stable, no observable leaks

## Integration Points

### VocabularyService Integration

- Mastery level updates
- Review schedule adjustments
- Vocabulary statistics tracking
- Synchronization with vocabulary changes

### UserService Integration

- User authentication validation
- Session persistence
- Premium feature access
- User preference management

### Navigation Integration

- Entry points from vocabulary screens
- Custom route transitions
- Deep linking support
- Back navigation handling

## Configuration

### Session Defaults

- Duration: 5-20 minutes
- Max words: 20-50 per session
- Question types: All enabled
- Review prioritization: Enabled

### Customizable Settings

- Session duration preferences
- Question type weights
- Difficulty algorithm parameters
- Progress notification preferences

## Error Handling

### Common Error Scenarios

- No vocabulary available
- User not authenticated
- Network connectivity issues
- Session data corruption

### Recovery Mechanisms

- Graceful fallbacks
- Session restoration
- Data validation
- User notification system

## Testing Strategy

### Unit Tests

- Model serialization/deserialization
- Service method functionality
- Algorithm correctness
- Widget behavior

### Integration Tests

- Service interaction
- Database operations
- Navigation flow
- State management

### Performance Tests

- Large vocabulary handling
- Memory efficiency
- Response times
- Scalability analysis

### E2E Tests

- Complete user journey
- Session lifecycle
- Error scenarios
- Data persistence

## Security Considerations

### Row Level Security (RLS)

- Users can only access their own sessions
- Automatic user_id filtering
- Secure data isolation

### Data Validation

- Input sanitization
- Type checking
- Range validation
- Malformed data handling

## Accessibility Features

### Screen Reader Support

- Semantic labels
- Content descriptions
- Navigation announcements
- Progress updates

### Motor Accessibility

- Large touch targets (min 44dp)
- Customizable timing
- Alternative input methods
- Reduced motion options

### Visual Accessibility

- High contrast support
- Font scaling
- Color-blind friendly colors
- Clear visual hierarchies

## Future Enhancements

### Planned Features

- Offline mode support
- Advanced analytics dashboard
- Social learning features
- Custom question types

### Performance Improvements

- Advanced caching strategies
- Background synchronization
- Predictive preloading
- Enhanced algorithms

### UI/UX Enhancements

- Voice input support
- Gesture controls
- Customizable themes
- Gamification elements

## Troubleshooting

### Common Issues

1. **Sessions not saving**

   - Check user authentication
   - Verify network connectivity
   - Validate session data

2. **Poor word selection**

   - Review vocabulary mastery data
   - Check spaced repetition settings
   - Verify algorithm parameters

3. **Performance issues**
   - Monitor memory usage
   - Check for memory leaks
   - Optimize database queries

### Debug Information

- Enable debug logging
- Check service initialization
- Monitor state changes
- Validate data integrity

## API Reference

### FlashcardService Methods

```dart
// Properties
bool get isInitialized
FlashcardSessionStatus get status
FlashcardSession? get currentSession
FlashcardQuestion? get currentQuestion
int get currentQuestionIndex
bool get canNavigateNext
bool get canNavigatePrevious

// Session Management
Future<bool> startSession(...)
Future<void> pauseSession()
Future<void> resumeSession()
Future<void> completeSession()
Future<void> cancelSession()

// Question Navigation
Future<void> nextQuestion()
Future<void> previousQuestion()

// Answer Processing
Future<void> recordAnswer(...)

// Statistics
Map<String, dynamic> getSessionPerformanceStats()
List<String> getPerformanceRecommendations()

// Persistence
Future<void> saveSession()
Future<bool> hasInterruptedSession()
Future<void> resumeInterruptedSession()
```

### Model Classes

```dart
class FlashcardSession {
  final String id;
  final String userId;
  final int durationMinutes;
  final String? language;
  final List<String>? focusWordTypes;
  final int totalQuestions;
  final int currentQuestionIndex;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FlashcardSessionCard> cards;

  // Computed properties
  double get completionPercentage;
  int get correctAnswers;
  int get incorrectAnswers;
  double get averageResponseTime;
}

class FlashcardQuestion {
  final FlashcardQuestionType type;
  final String question;
  final String correctAnswer;
  final List<String>? options;
  final String? context;
  final UserVocabularyItem vocabularyItem;

  bool isCorrectAnswer(String answer);
  String? getHint();
}
```

This documentation provides a comprehensive overview of the flashcard learning system, covering architecture, implementation details, usage patterns, and maintenance procedures.
