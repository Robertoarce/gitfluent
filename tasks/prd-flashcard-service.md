# Product Requirements Document: Flashcard Service

## Introduction/Overview

The Flashcard Service is a comprehensive vocabulary learning feature that leverages spaced repetition and adaptive learning to help users master their vocabulary through interactive study sessions. This feature builds upon the existing vocabulary tracking system to provide engaging, scientifically-backed learning experiences through multiple question types and personalized difficulty adaptation.

**Problem it solves:** Users currently have vocabulary items stored but lack an interactive, systematic way to practice and reinforce their learning beyond passive review.

**Goal:** Provide an engaging, adaptive flashcard system that improves vocabulary retention and mastery through varied question types and spaced repetition algorithms.

## Goals

1. **Improve Learning Retention:** Implement spaced repetition algorithms to optimize memory consolidation
2. **Increase User Engagement:** Provide interactive, varied learning experiences that keep users motivated
3. **Adaptive Learning:** Automatically adjust difficulty and frequency based on user performance
4. **Comprehensive Practice:** Support multiple question types to reinforce different aspects of vocabulary learning
5. **Progress Tracking:** Provide clear feedback on learning progress and mastery improvements

## User Stories

**As a language learner, I want to:**

- Start focused study sessions to practice my vocabulary systematically
- Choose how long I want to study (5, 10, 15, or custom minutes)
- See different types of questions to test my knowledge comprehensively
- Get immediate feedback on my performance to understand my progress
- Have the system automatically focus on words I'm struggling with
- Track my improvement over time through clear metrics

**As a busy professional, I want to:**

- Quickly start a study session during short breaks
- Have the system remember where I left off
- See how much progress I'm making in limited time
- Focus my limited study time on the most important words

**As a visual learner, I want to:**

- See clean, intuitive flashcard interfaces
- Have clear progress indicators during sessions
- Get visual feedback on correct/incorrect answers

## Functional Requirements

### Core Session Management

1. **Study Session Creation:** Users must be able to start flashcard sessions from a dedicated "Study Flashcards" screen
2. **Session Duration Configuration:** Users must be able to select session duration (5, 10, 15 minutes, or custom duration)
3. **Word Selection Algorithm:** The system must prioritize words based on:
   - Spaced repetition schedule (words due for review)
   - Low mastery scores (< 70%)
   - Recently added words
   - User-specified focus areas
4. **Session Progress Tracking:** The system must display session progress (cards completed/total, time remaining)

### Question Types

5. **Traditional Flashcards:** Show word → reveal translation with flip animation
6. **Multiple Choice Questions:** Present word with 4 translation options (1 correct, 3 distractors)
7. **Fill-in-the-Blank:** Show translation/example sentence with missing target word
8. **Reverse Cards:** Show translation → reveal target word
9. **Question Type Distribution:** Mix question types within sessions (configurable weights)

### User Interface Components

10. **Card Display:** Clean, readable card interface with flip animations
11. **Self-Assessment Buttons:** Provide "Again", "Hard", "Good", "Easy" buttons for user feedback
12. **Timer Display:** Show per-card timer and session timer
13. **Progress Indicator:** Visual progress bar and statistics (X/Y cards completed)
14. **Immediate Feedback:** Display correct/incorrect status with brief explanations

### Adaptive Learning Features

15. **Difficulty Adjustment:** Increase frequency of difficult words within sessions
16. **Mastery Progression:** Graduate words to longer review intervals when consistently answered correctly
17. **Performance Analytics:** Track accuracy, response time, and confidence levels per word
18. **Spaced Repetition Integration:** Update `nextReview` dates based on performance using existing `UserVocabularyItem.calculateNextReview()`

### Data Integration

19. **Vocabulary Sync:** Pull from existing `UserVocabularyItem` database
20. **Mastery Updates:** Update `masteryLevel`, `timesSeen`, `timesCorrect` after each session
21. **Statistics Tracking:** Update `UserVocabularyStats` with session data
22. **Progress Persistence:** Save session progress for interrupted sessions

### Session Results

23. **Session Summary:** Display session statistics (accuracy, time spent, words reviewed)
24. **Individual Word Results:** Show performance breakdown per word
25. **Recommendations:** Suggest focus areas for next session
26. **Streak Tracking:** Track daily study streaks and milestones

## Non-Goals (Out of Scope)

- **Audio pronunciation features** (can be added in future iterations)
- **Multiplayer or social features** (focus on individual learning)
- **Custom deck creation** (uses existing vocabulary only)
- **Offline mode** (requires internet for Supabase sync)
- **Advanced analytics dashboard** (basic stats only in v1)
- **Integration with external flashcard apps** (native solution only)

## Design Considerations

### UI/UX Requirements

- **Modern Material Design 3:** Consistent with existing app design
- **Accessibility:** Support for larger text, high contrast, screen readers
- **Mobile-First:** Optimized for touch interactions and small screens
- **Smooth Animations:** Card flips, progress transitions, and feedback animations
- **Color Coding:** Use existing vocabulary type colors (blue=verbs, green=nouns, purple=adverbs)

### Key Components

- **FlashcardScreen:** Main study interface
- **SessionConfigScreen:** Pre-session setup (duration, focus areas)
- **SessionResultsScreen:** Post-session summary and statistics
- **FlashcardWidget:** Individual card component with flip animations
- **ProgressWidget:** Session progress and timer display

## Technical Considerations

### Dependencies

- **Integration with existing `VocabularyService`** for data access
- **Use `UserVocabularyItem.updateMastery()`** for performance tracking
- **Leverage existing Supabase integration** for data persistence
- **Provider pattern** for state management consistency
- **SharedPreferences** for session preferences and offline caching

### Performance Requirements

- **Fast card transitions** (< 200ms animation duration)
- **Efficient word selection algorithms** (< 100ms query time)
- **Background data sync** to avoid UI blocking
- **Memory optimization** for large vocabulary sets

### Data Schema Additions

```sql
-- New table for session tracking
CREATE TABLE flashcard_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  duration_minutes INTEGER,
  words_studied INTEGER,
  total_cards INTEGER,
  accuracy_percentage DECIMAL,
  session_type VARCHAR -- 'timed', 'count-based', etc.
);

-- Session details for individual card performance
CREATE TABLE flashcard_session_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES flashcard_sessions(id) ON DELETE CASCADE,
  vocabulary_item_id UUID REFERENCES user_vocabulary(id) ON DELETE CASCADE,
  question_type VARCHAR, -- 'traditional', 'multiple_choice', 'fill_blank'
  response_time_ms INTEGER,
  was_correct BOOLEAN,
  difficulty_rating VARCHAR -- 'again', 'hard', 'good', 'easy'
);
```

## Success Metrics

### User Engagement

- **Daily Active Users:** Track users who complete at least one flashcard session daily
- **Session Completion Rate:** Percentage of started sessions that are completed
- **Average Session Duration:** Track if users are spending their intended study time
- **Return Rate:** Percentage of users who return for multiple sessions within a week

### Learning Effectiveness

- **Mastery Improvement:** Average increase in vocabulary mastery scores over time
- **Retention Rate:** Percentage of words that maintain high mastery after 30 days
- **Response Time Improvement:** Decreasing average response time for mastered words
- **Accuracy Trends:** Overall accuracy improvement across sessions

### Feature Adoption

- **Feature Discovery:** Percentage of active users who try the flashcard feature
- **Feature Retention:** Percentage of users who use flashcards regularly (3+ times/week)
- **Question Type Preferences:** Usage distribution across different question types
- **Session Length Preferences:** Most popular session duration choices

## Open Questions

1. **Gamification Elements:** Should we add points, badges, or leaderboards in future iterations?
2. **Question Difficulty Weighting:** What should be the default distribution of question types?
3. **Session Interruption Handling:** How should we handle phone calls or app backgrounding during sessions?
4. **Bulk Actions:** Should users be able to mark multiple words as "known" or "needs practice"?
5. **Advanced Settings:** What level of customization should power users have access to?
6. **Performance Thresholds:** What accuracy percentage should trigger mastery level increases?
7. **Review Frequency:** Should there be suggested daily study time recommendations?

---

**Document Version:** 1.0  
**Created:** January 2025  
**Target Implementation:** Q1 2025
