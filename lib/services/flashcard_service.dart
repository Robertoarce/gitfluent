import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard_session.dart';
import '../models/flashcard_question.dart';
import '../models/user_vocabulary.dart';
import 'user_service.dart';
import 'vocabulary_service.dart';

enum FlashcardSessionStatus {
  notStarted,
  inProgress,
  paused,
  completed,
  cancelled,
}

class FlashcardService extends ChangeNotifier {
  static const String _currentSessionKey = 'current_flashcard_session';
  static const String _sessionPreferencesKey = 'flashcard_session_preferences';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Dependencies
  UserService? _userService;
  VocabularyService? _vocabularyService;
  VoidCallback? _userAuthListener;
  VoidCallback? _vocabularyListener;

  // Current session state
  FlashcardSession? _currentSession;
  FlashcardQuestion? _currentQuestion;
  List<FlashcardQuestion> _sessionQuestions = [];
  int _currentQuestionIndex = 0;
  FlashcardSessionStatus _sessionStatus = FlashcardSessionStatus.notStarted;
  DateTime? _sessionStartTime;
  DateTime? _questionStartTime;

  // Session preferences
  final Map<String, dynamic> _sessionPreferences = {
    'defaultDuration': 10, // minutes
    'questionTypeWeights': {
      'traditional': 40,
      'multipleChoice': 30,
      'fillInBlank': 20,
      'reverse': 10,
    },
    'maxWordsPerSession': 20,
    'prioritizeReview': true,
    'includeFavorites': true,
  };

  // Getters
  bool get isInitialized => _isInitialized;
  FlashcardSession? get currentSession => _currentSession;
  FlashcardQuestion? get currentQuestion => _currentQuestion;
  FlashcardSessionStatus get sessionStatus => _sessionStatus;
  int get currentQuestionIndex => _currentQuestionIndex;
  int get totalQuestions => _sessionQuestions.length;
  double get sessionProgress =>
      totalQuestions > 0 ? (currentQuestionIndex / totalQuestions) : 0.0;
  Map<String, dynamic> get sessionPreferences =>
      Map.unmodifiable(_sessionPreferences);

  // Session statistics
  int get correctAnswers => _currentSession?.correctAnswers ?? 0;
  int get incorrectAnswers => _currentSession?.incorrectAnswers ?? 0;
  double get accuracyPercentage =>
      totalQuestions > 0 ? ((correctAnswers / totalQuestions) * 100) : 0.0;
  Duration? get sessionDuration => _sessionStartTime != null
      ? DateTime.now().difference(_sessionStartTime!)
      : null;

  // Set dependencies
  void setUserService(UserService userService) {
    if (_userService != null && _userAuthListener != null) {
      _userService!.removeListener(_userAuthListener!);
    }

    _userService = userService;
    _userAuthListener = () => _handleUserChange();
    _userService!.addListener(_userAuthListener!);

    if (_isInitialized) {
      _handleUserChange();
    }
  }

  void setVocabularyService(VocabularyService vocabularyService) {
    if (_vocabularyService != null && _vocabularyListener != null) {
      _vocabularyService!.removeListener(_vocabularyListener!);
    }

    _vocabularyService = vocabularyService;
    _vocabularyListener = () => _handleVocabularyChange();
    _vocabularyService!.addListener(_vocabularyListener!);
  }

  /// Auto-cleanup expired sessions on service initialization
  Future<void> _performSessionMaintenance() async {
    try {
      final String? storedSession = _prefs.getString(_currentSessionKey);
      if (storedSession != null) {
        final Map<String, dynamic> sessionData = jsonDecode(storedSession);

        // Check if stored session is expired
        if (sessionData['session'] != null) {
          final session = FlashcardSession.fromJson(sessionData['session']);
          final sessionAge = DateTime.now().difference(session.sessionDate);

          if (sessionAge.inHours > 24) {
            debugPrint(
                'FlashcardService: Removing expired session during maintenance');
            await _prefs.remove(_currentSessionKey);
          }
        }
      }
    } catch (e) {
      debugPrint('FlashcardService: Error during session maintenance: $e');
      // Clear corrupted data
      await _prefs.remove(_currentSessionKey);
    }
  }

  /// Clear current session data
  Future<void> _clearCurrentSession() async {
    try {
      await _prefs.remove(_currentSessionKey);
      _currentSession = null;
      _currentQuestion = null;
      _sessionQuestions = [];
      _currentQuestionIndex = 0;
      _sessionStatus = FlashcardSessionStatus.notStarted;
      _sessionStartTime = null;
      _questionStartTime = null;
    } catch (e) {
      debugPrint('FlashcardService: Error clearing current session: $e');
    }
  }

  // Enhanced initialization with session maintenance
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSessionPreferences();
      await _performSessionMaintenance(); // Clean up expired sessions
      await _loadCurrentSession();
      _isInitialized = true;
      debugPrint('FlashcardService: Initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('FlashcardService: Error during initialization: $e');
      _isInitialized = true; // Mark as initialized even if there were errors
      notifyListeners();
    }
  }

  Future<void> _handleUserChange() async {
    debugPrint(
        'FlashcardService: Detected user change. Clearing session data.');

    // Cancel current session if any
    if (_sessionStatus == FlashcardSessionStatus.inProgress) {
      await cancelSession();
    }

    // Clear local session data
    await _clearCurrentSession();

    if (_isInitialized) {
      notifyListeners();
    }
  }

  void _handleVocabularyChange() {
    // Vocabulary items changed, might need to refresh session questions
    if (_sessionStatus == FlashcardSessionStatus.inProgress &&
        _vocabularyService != null) {
      debugPrint(
          'FlashcardService: Vocabulary changed during session, monitoring for updates');
      // Don't interrupt current session, but note that vocabulary has changed
    }
  }

  Future<void> _loadSessionPreferences() async {
    try {
      final String? storedPrefs = _prefs.getString(_sessionPreferencesKey);
      if (storedPrefs != null) {
        final Map<String, dynamic> decoded = jsonDecode(storedPrefs);
        _sessionPreferences.addAll(decoded);
        debugPrint('FlashcardService: Loaded session preferences');
      }
    } catch (e) {
      debugPrint('FlashcardService: Error loading session preferences: $e');
    }
  }

  Future<void> _saveSessionPreferences() async {
    try {
      final String encoded = jsonEncode(_sessionPreferences);
      await _prefs.setString(_sessionPreferencesKey, encoded);
    } catch (e) {
      debugPrint('FlashcardService: Error saving session preferences: $e');
    }
  }

  /// Clear session data (call after user views results)
  Future<void> clearSessionData() async {
    await _clearCurrentSession();
    notifyListeners();
  }

  // Session Persistence for Interrupted Sessions

  /// Check if there's an interrupted session that can be resumed
  bool hasInterruptedSession() {
    return _currentSession != null &&
        _sessionStatus == FlashcardSessionStatus.paused;
  }

  /// Get information about the interrupted session
  Map<String, dynamic>? getInterruptedSessionInfo() {
    if (!hasInterruptedSession()) return null;

    return {
      'sessionId': _currentSession!.id,
      'totalQuestions': _sessionQuestions.length,
      'currentQuestionIndex': _currentQuestionIndex,
      'questionsRemaining': _sessionQuestions.length - _currentQuestionIndex,
      'accuracy': _currentSession!.accuracyPercentage,
      'timeElapsed': sessionDuration?.inMinutes ?? 0,
      'sessionDate': _currentSession!.sessionDate,
      'isExpired': _isSessionExpired(),
    };
  }

  /// Check if the current session has expired (older than 24 hours)
  bool _isSessionExpired() {
    if (_currentSession == null) return false;

    final sessionAge = DateTime.now().difference(_currentSession!.sessionDate);
    return sessionAge.inHours > 24;
  }

  /// Resume an interrupted session
  Future<bool> resumeInterruptedSession() async {
    if (!hasInterruptedSession()) {
      debugPrint('FlashcardService: No interrupted session to resume');
      return false;
    }

    if (_isSessionExpired()) {
      debugPrint('FlashcardService: Session expired, cannot resume');
      await _clearExpiredSession();
      return false;
    }

    try {
      // Validate session data integrity
      if (!_validateSessionIntegrity()) {
        debugPrint('FlashcardService: Session data corrupted, cannot resume');
        await _clearCurrentSession();
        return false;
      }

      // Restore session state
      _sessionStatus = FlashcardSessionStatus.inProgress;
      _questionStartTime = DateTime.now(); // Reset question timer

      // Ensure current question is set
      if (_currentQuestionIndex < _sessionQuestions.length) {
        _currentQuestion = _sessionQuestions[_currentQuestionIndex];
      } else {
        // Session was completed but not marked as such
        await completeSession();
        return false;
      }

      await _saveCurrentSession();

      debugPrint('FlashcardService: Resumed interrupted session');
      debugPrint('  - Session ID: ${_currentSession!.id}');
      debugPrint(
          '  - Question: ${_currentQuestionIndex + 1}/${_sessionQuestions.length}');
      debugPrint(
          '  - Current word: "${_currentQuestion!.vocabularyItem.word}"');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FlashcardService: Error resuming interrupted session: $e');
      await _clearCurrentSession();
      return false;
    }
  }

  /// Validate the integrity of session data
  bool _validateSessionIntegrity() {
    if (_currentSession == null) return false;
    if (_sessionQuestions.isEmpty) return false;
    if (_currentQuestionIndex < 0 ||
        _currentQuestionIndex >= _sessionQuestions.length) return false;

    // Check if session questions match vocabulary items
    for (final question in _sessionQuestions) {
      if (question.vocabularyItem.id.isEmpty) return false;
      if (question.question.isEmpty) return false;
    }

    return true;
  }

  /// Clear expired session data
  Future<void> _clearExpiredSession() async {
    debugPrint('FlashcardService: Clearing expired session');
    await _clearCurrentSession();
  }

  /// Enhanced session loading with recovery mechanisms
  Future<void> _loadCurrentSession() async {
    try {
      final String? storedSession = _prefs.getString(_currentSessionKey);
      if (storedSession != null) {
        final Map<String, dynamic> sessionData = jsonDecode(storedSession);

        // Validate stored session structure
        if (!_validateStoredSessionStructure(sessionData)) {
          debugPrint(
              'FlashcardService: Invalid stored session structure, clearing');
          await _prefs.remove(_currentSessionKey);
          return;
        }

        // Restore session state
        _currentSession = FlashcardSession.fromJson(sessionData['session']);
        _currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;
        _sessionStatus = FlashcardSessionStatus.values.firstWhere(
          (status) => status.name == sessionData['status'],
          orElse: () => FlashcardSessionStatus.notStarted,
        );

        if (sessionData['sessionStartTime'] != null) {
          _sessionStartTime = DateTime.parse(sessionData['sessionStartTime']);
        }

        // Restore session questions if available
        if (sessionData['sessionQuestions'] != null) {
          try {
            // Session questions will need to be regenerated since FlashcardQuestion
            // doesn't have JSON serialization yet - this will be handled in UI tasks
            debugPrint(
                'FlashcardService: Session questions found but will be regenerated');
            _sessionQuestions = [];
          } catch (e) {
            debugPrint(
                'FlashcardService: Error restoring session questions: $e');
            // Mark for regeneration
            _sessionQuestions = [];
          }
        }

        // Check if session is expired
        if (_isSessionExpired()) {
          debugPrint('FlashcardService: Loaded session is expired, clearing');
          await _clearExpiredSession();
          return;
        }

        // Validate integrity after loading
        if (!_validateSessionIntegrity() && _sessionQuestions.isNotEmpty) {
          debugPrint(
              'FlashcardService: Session integrity check failed, clearing');
          await _clearCurrentSession();
          return;
        }

        // Set current question if valid
        if (_sessionQuestions.isNotEmpty &&
            _currentQuestionIndex < _sessionQuestions.length) {
          _currentQuestion = _sessionQuestions[_currentQuestionIndex];
        }

        debugPrint('FlashcardService: Restored session ${_currentSession?.id}');
        debugPrint('  - Status: ${_sessionStatus.name}');
        debugPrint('  - Questions: ${_sessionQuestions.length}');
        debugPrint('  - Current index: $_currentQuestionIndex');
      }
    } catch (e) {
      debugPrint('FlashcardService: Error loading current session: $e');
      await _clearCurrentSession();
    }
  }

  /// Validate the structure of stored session data
  bool _validateStoredSessionStructure(Map<String, dynamic> sessionData) {
    try {
      // Check required fields exist
      if (!sessionData.containsKey('session')) return false;
      if (!sessionData.containsKey('currentQuestionIndex')) return false;
      if (!sessionData.containsKey('status')) return false;

      // Validate session object
      final session = sessionData['session'];
      if (session is! Map<String, dynamic>) return false;
      if (!session.containsKey('id')) return false;
      if (!session.containsKey('user_id')) return false;

      // Validate question index
      final questionIndex = sessionData['currentQuestionIndex'];
      if (questionIndex is! int || questionIndex < 0) return false;

      // Validate status
      final status = sessionData['status'];
      if (status is! String) return false;

      return true;
    } catch (e) {
      debugPrint('FlashcardService: Session structure validation failed: $e');
      return false;
    }
  }

  /// Enhanced session saving with questions data
  Future<void> _saveCurrentSession() async {
    try {
      if (_currentSession == null) {
        await _prefs.remove(_currentSessionKey);
        return;
      }

      final Map<String, dynamic> sessionData = {
        'session': _currentSession!.toJson(),
        'currentQuestionIndex': _currentQuestionIndex,
        'status': _sessionStatus.name,
        'sessionStartTime': _sessionStartTime?.toIso8601String(),
        'lastSaved': DateTime.now().toIso8601String(),
        // Note: sessionQuestions not persisted as FlashcardQuestion lacks JSON serialization
        // Will be regenerated on session restoration
      };

      final String encoded = jsonEncode(sessionData);
      await _prefs.setString(_currentSessionKey, encoded);

      debugPrint('FlashcardService: Session saved to local storage');
    } catch (e) {
      debugPrint('FlashcardService: Error saving current session: $e');
    }
  }

  /// Get session recovery statistics
  Map<String, dynamic> getSessionRecoveryStats() {
    return {
      'hasStoredSession': _prefs.containsKey(_currentSessionKey),
      'canResumeSession': hasInterruptedSession(),
      'sessionAge': _currentSession != null
          ? DateTime.now().difference(_currentSession!.sessionDate).inMinutes
          : null,
      'isExpired': _isSessionExpired(),
      'questionsComplete': _currentQuestionIndex,
      'questionsTotal': _sessionQuestions.length,
      'completionPercentage': _sessionQuestions.isNotEmpty
          ? (_currentQuestionIndex / _sessionQuestions.length) * 100
          : 0.0,
    };
  }

  /// Force clear all session data (for debugging or reset purposes)
  Future<void> forceResetSession() async {
    debugPrint('FlashcardService: Force resetting all session data');
    await _prefs.remove(_currentSessionKey);
    await _clearCurrentSession();
    notifyListeners();
  }

  // Word selection algorithm based on spaced repetition
  Future<List<UserVocabularyItem>> selectWordsForSession({
    int? maxWords,
    String? language,
    List<String>? focusWordTypes,
    bool prioritizeReview = true,
    bool includeFavorites = true,
  }) async {
    if (_userService == null || !_userService!.isLoggedIn) {
      debugPrint('FlashcardService: Cannot select words - user not logged in');
      return [];
    }

    try {
      // Get all user vocabulary
      final allVocabulary =
          await _vocabularyService?.getUserVocabulary(language: language) ?? [];
      if (allVocabulary.isEmpty) {
        debugPrint('FlashcardService: No vocabulary items found for session');
        return [];
      }

      final maxWordsPerSession = maxWords ?? getMaxWordsPerSession();
      final now = DateTime.now();

      // Categorize words by priority
      final List<UserVocabularyItem> prioritizedWords = [];
      final List<UserVocabularyItem> reviewWords = [];
      final List<UserVocabularyItem> strugglingWords = [];
      final List<UserVocabularyItem> favoriteWords = [];
      final List<UserVocabularyItem> recentWords = [];
      final List<UserVocabularyItem> regularWords = [];

      for (final word in allVocabulary) {
        // Skip if focus types specified and word doesn't match
        if (focusWordTypes != null && focusWordTypes.isNotEmpty) {
          if (!focusWordTypes.contains(word.wordType.toLowerCase())) {
            continue;
          }
        }

        // Categorize by priority
        if (word.needsReview) {
          reviewWords.add(word);
        } else if (word.masteryLevel < 70) {
          strugglingWords.add(word);
        } else if (includeFavorites && word.isFavorite) {
          favoriteWords.add(word);
        } else if (word.firstLearned
            .isAfter(now.subtract(const Duration(days: 7)))) {
          recentWords.add(word);
        } else {
          regularWords.add(word);
        }
      }

      // Sort each category by relevance
      _sortWordsByPriority(reviewWords);
      _sortWordsByPriority(strugglingWords);
      _sortWordsByPriority(favoriteWords);
      _sortWordsByPriority(recentWords);
      _sortWordsByPriority(regularWords);

      // Build prioritized list based on preferences
      if (prioritizeReview) {
        // Prioritize review words (50% of session)
        final reviewCount = min(reviewWords.length, maxWordsPerSession ~/ 2);
        prioritizedWords.addAll(reviewWords.take(reviewCount));

        // Add struggling words (30% of remaining)
        final strugglingCount = min(strugglingWords.length,
            ((maxWordsPerSession - prioritizedWords.length) * 0.6).round());
        prioritizedWords.addAll(strugglingWords.take(strugglingCount));

        // Fill remaining with favorites, recent, and regular words
        final remaining = maxWordsPerSession - prioritizedWords.length;
        if (remaining > 0) {
          final mixedWords = <UserVocabularyItem>[
            ...favoriteWords,
            ...recentWords,
            ...regularWords,
          ];
          mixedWords.shuffle(); // Randomize for variety
          prioritizedWords.addAll(mixedWords.take(remaining));
        }
      } else {
        // More balanced distribution
        final allCategorized = <UserVocabularyItem>[
          ...reviewWords,
          ...strugglingWords,
          ...favoriteWords,
          ...recentWords,
          ...regularWords,
        ];
        allCategorized.shuffle();
        prioritizedWords.addAll(allCategorized.take(maxWordsPerSession));
      }

      debugPrint(
          'FlashcardService: Selected ${prioritizedWords.length} words for session');
      debugPrint('  - Review words: ${reviewWords.length}');
      debugPrint('  - Struggling words: ${strugglingWords.length}');
      debugPrint('  - Favorite words: ${favoriteWords.length}');
      debugPrint('  - Recent words: ${recentWords.length}');
      debugPrint('  - Regular words: ${regularWords.length}');

      return prioritizedWords.take(maxWordsPerSession).toList();
    } catch (e) {
      debugPrint('FlashcardService: Error selecting words for session: $e');
      return [];
    }
  }

  void _sortWordsByPriority(List<UserVocabularyItem> words) {
    words.sort((a, b) {
      // Primary: Lower mastery first
      final masteryComparison = a.masteryLevel.compareTo(b.masteryLevel);
      if (masteryComparison != 0) return masteryComparison;

      // Secondary: More times seen (struggling words)
      final timesSeenComparison = b.timesSeen.compareTo(a.timesSeen);
      if (timesSeenComparison != 0) return timesSeenComparison;

      // Tertiary: Less accuracy
      final accuracyComparison = a.accuracy.compareTo(b.accuracy);
      if (accuracyComparison != 0) return accuracyComparison;

      // Finally: Older review date (more overdue)
      if (a.nextReview != null && b.nextReview != null) {
        return a.nextReview!.compareTo(b.nextReview!);
      }

      return 0;
    });
  }

  // Session preferences management
  Future<void> updateSessionPreferences(
      Map<String, dynamic> newPreferences) async {
    _sessionPreferences.addAll(newPreferences);
    await _saveSessionPreferences();
    debugPrint('FlashcardService: Updated session preferences');
    notifyListeners();
  }

  int getDefaultDuration() => _sessionPreferences['defaultDuration'] ?? 10;

  Map<String, int> getQuestionTypeWeights() =>
      Map<String, int>.from(_sessionPreferences['questionTypeWeights'] ?? {});

  int getMaxWordsPerSession() =>
      _sessionPreferences['maxWordsPerSession'] ?? 20;

  bool shouldPrioritizeReview() =>
      _sessionPreferences['prioritizeReview'] ?? true;

  bool shouldIncludeFavorites() =>
      _sessionPreferences['includeFavorites'] ?? true;

  // Core session management methods (to be implemented in next tasks)
  Future<void> cancelSession() async {
    debugPrint('FlashcardService: Cancelling current session');

    // Mark as cancelled in database
    if (_currentSession != null && _userService!.isLoggedIn) {
      try {
        final cancelledSession = _currentSession!.copyWith(
          isCompleted: false,
          updatedAt: DateTime.now(),
        );
        await _userService!.updateFlashcardSession(cancelledSession);
        debugPrint('FlashcardService: Session marked as cancelled in database');
      } catch (e) {
        debugPrint(
            'FlashcardService: Warning - could not update cancelled session: $e');
      }
    }

    _sessionStatus = FlashcardSessionStatus.cancelled;
    await _clearCurrentSession();
    notifyListeners();
  }

  // Question generation based on selected words
  Future<List<FlashcardQuestion>> generateQuestionsForSession(
    List<UserVocabularyItem> selectedWords, {
    String? language, // Add language parameter
  }) async {
    if (selectedWords.isEmpty) {
      debugPrint(
          'FlashcardService: Cannot generate questions - no words provided');
      return [];
    }

    final questions = <FlashcardQuestion>[];
    final weights = getQuestionTypeWeights();
    final random = Random();

    // Get all vocabulary for generating distractors (for multiple choice)
    // Use the same language filter as the selected words to ensure consistent distractors
    final allVocabulary =
        await _vocabularyService?.getUserVocabulary(language: language) ?? [];

    debugPrint(
        'FlashcardService: Generating questions for ${selectedWords.length} words');
    debugPrint('FlashcardService: Question type weights: $weights');

    for (int i = 0; i < selectedWords.length; i++) {
      final word = selectedWords[i];
      final questionType = _selectQuestionType(weights, random);

      try {
        final question = await _generateQuestion(
          word,
          questionType,
          allVocabulary,
          i.toString(),
        );

        if (question != null) {
          questions.add(question);
        }
      } catch (e) {
        debugPrint(
            'FlashcardService: Error generating question for word "${word.word}": $e');
        // Fallback to traditional flashcard
        final fallbackQuestion = FlashcardQuestion.traditional(
          id: '${i}_fallback',
          vocabularyItem: word,
        );
        questions.add(fallbackQuestion);
      }
    }

    // Shuffle questions for variety
    questions.shuffle(random);

    debugPrint('FlashcardService: Generated ${questions.length} questions');
    return questions;
  }

  String _selectQuestionType(Map<String, int> weights, Random random) {
    // Calculate total weight
    final totalWeight = weights.values.fold(0, (sum, weight) => sum + weight);
    if (totalWeight == 0) return 'traditional'; // Fallback

    // Generate random number
    final randomValue = random.nextInt(totalWeight);

    // Select type based on weights
    int currentWeight = 0;
    for (final entry in weights.entries) {
      currentWeight += entry.value;
      if (randomValue < currentWeight) {
        return entry.key;
      }
    }

    return 'traditional'; // Fallback
  }

  Future<FlashcardQuestion?> _generateQuestion(
    UserVocabularyItem word,
    String questionType,
    List<UserVocabularyItem> allVocabulary,
    String questionId,
  ) async {
    switch (questionType) {
      case 'traditional':
        return FlashcardQuestion.traditional(
          id: '${questionId}_traditional',
          vocabularyItem: word,
        );

      case 'reverse':
        return FlashcardQuestion.reverse(
          id: '${questionId}_reverse',
          vocabularyItem: word,
        );

      case 'multipleChoice':
        return _generateMultipleChoiceQuestion(word, allVocabulary, questionId);

      case 'fillInBlank':
        return _generateFillInBlankQuestion(word, questionId);

      default:
        // Fallback to traditional
        return FlashcardQuestion.traditional(
          id: '${questionId}_traditional',
          vocabularyItem: word,
        );
    }
  }

  FlashcardQuestion? _generateMultipleChoiceQuestion(
    UserVocabularyItem word,
    List<UserVocabularyItem> allVocabulary,
    String questionId,
  ) {
    if (word.translations.isEmpty) return null;

    // Get correct answer
    final correctAnswer = word.translations.first;

    // Generate distractors
    final distractors = _generateDistractors(word, allVocabulary);
    if (distractors.length < 3) {
      // Not enough distractors, fallback to traditional
      return FlashcardQuestion.traditional(
        id: '${questionId}_traditional',
        vocabularyItem: word,
      );
    }

    return FlashcardQuestion.multipleChoice(
      id: '${questionId}_mc',
      vocabularyItem: word,
      distractors: distractors.take(3).toList(),
    );
  }

  List<String> _generateDistractors(
    UserVocabularyItem targetWord,
    List<UserVocabularyItem> allVocabulary,
  ) {
    final distractors = <String>[];
    final targetTranslation = targetWord.translations.isNotEmpty
        ? targetWord.translations.first.toLowerCase()
        : '';

    // Filter vocabulary to get potential distractors
    final candidates = allVocabulary
        .where((word) =>
            word.id != targetWord.id && // Not the same word
            word.wordType ==
                targetWord.wordType && // Same type (noun, verb, etc.)
            word.translations.isNotEmpty) // Has translations
        .toList();

    // Shuffle for randomness
    candidates.shuffle();

    // Add distractors, avoiding duplicates and the correct answer
    for (final candidate in candidates) {
      final translation = candidate.translations.first;
      if (translation.toLowerCase() != targetTranslation &&
          !distractors.contains(translation)) {
        distractors.add(translation);
        if (distractors.length >= 5) break; // Get extras in case we need them
      }
    }

    // If not enough from same type, add from other types
    if (distractors.length < 3) {
      final otherCandidates = allVocabulary
          .where((word) =>
              word.id != targetWord.id &&
              word.translations.isNotEmpty &&
              !distractors.contains(word.translations.first))
          .toList();

      otherCandidates.shuffle();

      for (final candidate in otherCandidates) {
        final translation = candidate.translations.first;
        if (!distractors.contains(translation)) {
          distractors.add(translation);
          if (distractors.length >= 3) break;
        }
      }
    }

    return distractors;
  }

  FlashcardQuestion? _generateFillInBlankQuestion(
    UserVocabularyItem word,
    String questionId,
  ) {
    // Use example sentence if available
    if (word.exampleSentences.isNotEmpty) {
      return FlashcardQuestion.fillInBlank(
        id: '${questionId}_fill',
        vocabularyItem: word,
        customContext: word.exampleSentences.first,
      );
    }

    // Generate a simple context if no example sentence
    final translation =
        word.translations.isNotEmpty ? word.translations.first : 'this word';

    String context;
    switch (word.wordType.toLowerCase()) {
      case 'verb':
        context = 'I like to ____ every day. (Translation: $translation)';
        break;
      case 'noun':
        context = 'The ____ is very important. (Translation: $translation)';
        break;
      case 'adjective':
        context = 'This is very ____. (Translation: $translation)';
        break;
      case 'adverb':
        context = 'She does it ____. (Translation: $translation)';
        break;
      default:
        context = 'The word ____ means "$translation" in English.';
    }

    return FlashcardQuestion.fillInBlank(
      id: '${questionId}_fill',
      vocabularyItem: word,
      customContext: context,
    );
  }

  // Helper method to get question type distribution for current session
  Map<String, int> getSessionQuestionTypeStats() {
    final stats = <String, int>{};

    for (final question in _sessionQuestions) {
      final typeName = question.typeDisplayName;
      stats[typeName] = (stats[typeName] ?? 0) + 1;
    }

    return stats;
  }

  // Session Management Methods

  /// Start a new flashcard session with the given configuration
  Future<bool> startSession({
    required int durationMinutes,
    String? language,
    List<String>? focusWordTypes,
    int? maxWords,
    bool prioritizeReview = true,
    bool includeFavorites = true,
  }) async {
    if (!_isInitialized) {
      debugPrint(
          'FlashcardService: Cannot start session - service not initialized');
      return false;
    }

    if (_sessionStatus == FlashcardSessionStatus.inProgress) {
      debugPrint(
          'FlashcardService: Cannot start session - another session is in progress');
      return false;
    }

    if (_userService == null || !_userService!.isLoggedIn) {
      debugPrint('FlashcardService: Cannot start session - user not logged in');
      return false;
    }

    try {
      debugPrint('FlashcardService: Starting new session...');
      debugPrint('  - Duration: ${durationMinutes}min');
      debugPrint('  - Language: ${language ?? "all"}');
      debugPrint('  - Focus types: ${focusWordTypes ?? "all"}');
      debugPrint('  - Max words: ${maxWords ?? getMaxWordsPerSession()}');

      // Step 1: Clear any existing session
      await _clearCurrentSession();

      // Step 2: Select words for the session
      final selectedWords = await selectWordsForSession(
        maxWords: maxWords,
        language: language,
        focusWordTypes: focusWordTypes,
        prioritizeReview: prioritizeReview,
        includeFavorites: includeFavorites,
      );

      if (selectedWords.isEmpty) {
        debugPrint(
            'FlashcardService: Cannot start session - no words available');
        return false;
      }

      // Step 3: Generate questions from selected words
      _sessionQuestions =
          await generateQuestionsForSession(selectedWords, language: language);

      if (_sessionQuestions.isEmpty) {
        debugPrint(
            'FlashcardService: Cannot start session - no questions generated');
        return false;
      }

      // Step 4: Create session record
      _currentSession = FlashcardSession.create(
        userId: _userService!.currentUser!.id,
        durationMinutes: durationMinutes,
        sessionType: 'timed',
      );

      _currentSession = _currentSession!.copyWith(
        totalCards: _sessionQuestions.length,
      );

      // Step 5: Initialize session state
      _currentQuestionIndex = 0;
      _currentQuestion = _sessionQuestions.first;
      _sessionStatus = FlashcardSessionStatus.inProgress;
      _sessionStartTime = DateTime.now();
      _questionStartTime = DateTime.now();

      // Step 6: Save session to database
      if (_userService!.isLoggedIn) {
        try {
          await _userService!.createFlashcardSession(_currentSession!);
          debugPrint('FlashcardService: Session saved to database');
        } catch (e) {
          debugPrint(
              'FlashcardService: Warning - could not save session to database: $e');
          // Continue anyway - session will work locally
        }
      }

      // Step 7: Save to local storage
      await _saveCurrentSession();

      debugPrint('FlashcardService: Session started successfully');
      debugPrint('  - Session ID: ${_currentSession!.id}');
      debugPrint('  - Total questions: ${_sessionQuestions.length}');
      debugPrint('  - First question: "${_currentQuestion!.question}"');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FlashcardService: Error starting session: $e');
      await _clearCurrentSession();
      _sessionStatus = FlashcardSessionStatus.notStarted;
      notifyListeners();
      return false;
    }
  }

  /// Pause the current session
  Future<bool> pauseSession() async {
    if (_sessionStatus != FlashcardSessionStatus.inProgress) {
      debugPrint('FlashcardService: Cannot pause - no session in progress');
      return false;
    }

    try {
      _sessionStatus = FlashcardSessionStatus.paused;
      await _saveCurrentSession();

      debugPrint('FlashcardService: Session paused');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FlashcardService: Error pausing session: $e');
      return false;
    }
  }

  /// Resume a paused session
  Future<bool> resumeSession() async {
    if (_sessionStatus != FlashcardSessionStatus.paused) {
      debugPrint('FlashcardService: Cannot resume - session not paused');
      return false;
    }

    try {
      _sessionStatus = FlashcardSessionStatus.inProgress;
      _questionStartTime = DateTime.now(); // Reset question timer
      await _saveCurrentSession();

      debugPrint('FlashcardService: Session resumed');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FlashcardService: Error resuming session: $e');
      return false;
    }
  }

  /// Complete the current session and calculate final statistics
  Future<bool> completeSession() async {
    if (_currentSession == null) {
      debugPrint('FlashcardService: Cannot complete - no active session');
      return false;
    }

    try {
      debugPrint('FlashcardService: Completing session...');

      // Calculate final session statistics
      final now = DateTime.now();
      final actualDuration = _sessionStartTime != null
          ? now.difference(_sessionStartTime!).inMinutes
          : _currentSession!.durationMinutes;

      final completedCards = _currentQuestionIndex;
      final totalCards = _sessionQuestions.length;
      final accuracy =
          totalCards > 0 ? (correctAnswers / totalCards) * 100 : 0.0;

      // Update session with final stats
      _currentSession = _currentSession!.copyWith(
        isCompleted: true,
        wordsStudied: completedCards,
        accuracyPercentage: accuracy,
        updatedAt: now,
      );

      // Save to database
      if (_userService!.isLoggedIn) {
        try {
          await _userService!.updateFlashcardSession(_currentSession!);
          debugPrint('FlashcardService: Session stats saved to database');
        } catch (e) {
          debugPrint(
              'FlashcardService: Warning - could not save session stats: $e');
        }
      }

      // Update session status
      _sessionStatus = FlashcardSessionStatus.completed;

      debugPrint('FlashcardService: Session completed successfully');
      debugPrint(
          '  - Duration: ${actualDuration}min (planned: ${_currentSession!.durationMinutes}min)');
      debugPrint('  - Cards completed: $completedCards/$totalCards');
      debugPrint('  - Accuracy: ${accuracy.toStringAsFixed(1)}%');
      debugPrint('  - Correct answers: $correctAnswers');
      debugPrint('  - Incorrect answers: $incorrectAnswers');

      // Keep session data for results screen, don't clear yet
      await _saveCurrentSession();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FlashcardService: Error completing session: $e');
      return false;
    }
  }

  // Question Navigation Methods

  /// Move to the next question in the session
  Future<bool> nextQuestion() async {
    if (_sessionStatus != FlashcardSessionStatus.inProgress) {
      debugPrint(
          'FlashcardService: Cannot move to next question - session not in progress');
      return false;
    }

    if (_currentQuestionIndex >= _sessionQuestions.length - 1) {
      debugPrint('FlashcardService: Reached end of session');
      // Automatically complete the session
      await completeSession();
      return false;
    }

    _currentQuestionIndex++;
    _currentQuestion = _sessionQuestions[_currentQuestionIndex];
    _questionStartTime = DateTime.now();

    await _saveCurrentSession();
    notifyListeners();

    debugPrint(
        'FlashcardService: Moved to question ${_currentQuestionIndex + 1}/${_sessionQuestions.length}');
    return true;
  }

  /// Move to the previous question (if allowed)
  Future<bool> previousQuestion() async {
    if (_sessionStatus != FlashcardSessionStatus.inProgress) {
      debugPrint(
          'FlashcardService: Cannot move to previous question - session not in progress');
      return false;
    }

    if (_currentQuestionIndex <= 0) {
      debugPrint('FlashcardService: Already at first question');
      return false;
    }

    _currentQuestionIndex--;
    _currentQuestion = _sessionQuestions[_currentQuestionIndex];
    _questionStartTime = DateTime.now();

    await _saveCurrentSession();
    notifyListeners();

    debugPrint(
        'FlashcardService: Moved to question ${_currentQuestionIndex + 1}/${_sessionQuestions.length}');
    return true;
  }

  /// Check if there are more questions in the session
  bool hasNextQuestion() {
    return _currentQuestionIndex < _sessionQuestions.length - 1;
  }

  /// Check if there are previous questions in the session
  bool hasPreviousQuestion() {
    return _currentQuestionIndex > 0;
  }

  /// Get the current question number (1-based)
  int getCurrentQuestionNumber() {
    return _currentQuestionIndex + 1;
  }

  /// Get time spent on current question
  Duration? getCurrentQuestionDuration() {
    return _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!)
        : null;
  }

  // Performance Tracking and Mastery Updates

  /// Record an answer for the current question
  Future<bool> recordAnswer({
    required bool isCorrect,
    String? userAnswer,
    String? difficultyRating, // 'again', 'hard', 'good', 'easy' (Anki-style)
  }) async {
    if (_currentQuestion == null || _currentSession == null) {
      debugPrint(
          'FlashcardService: Cannot record answer - no active question or session');
      return false;
    }

    if (_sessionStatus != FlashcardSessionStatus.inProgress) {
      debugPrint(
          'FlashcardService: Cannot record answer - session not in progress');
      return false;
    }

    try {
      final now = DateTime.now();
      final responseTime = _questionStartTime != null
          ? now.difference(_questionStartTime!).inMilliseconds
          : null;

      // Create session card record for this answer
      final sessionCard = FlashcardSessionCard.create(
        sessionId: _currentSession!.id,
        vocabularyItemId: _currentQuestion!.vocabularyItem.id,
        questionType: _currentQuestion!.type.name,
        responseTimeMs: responseTime ?? 0,
        wasCorrect: isCorrect,
        difficultyRating: difficultyRating,
      );

      // Add to current session's cards
      _currentSession = _currentSession!.copyWith(
        cards: [..._currentSession!.cards, sessionCard],
      );

      // Update vocabulary item mastery
      await _updateVocabularyMastery(
        _currentQuestion!.vocabularyItem,
        isCorrect: isCorrect,
        difficultyRating: difficultyRating,
        responseTimeMs: responseTime,
      );

      // Save session card to database
      if (_userService!.isLoggedIn) {
        try {
          await _userService!.saveFlashcardSessionCard(sessionCard);
          debugPrint('FlashcardService: Session card saved to database');
        } catch (e) {
          debugPrint(
              'FlashcardService: Warning - could not save session card: $e');
        }
      }

      // Save updated session locally
      await _saveCurrentSession();

      debugPrint(
          'FlashcardService: Answer recorded for "${_currentQuestion!.vocabularyItem.word}"');
      debugPrint('  - Correct: $isCorrect');
      debugPrint('  - Response time: ${responseTime}ms');
      debugPrint('  - Difficulty rating: ${difficultyRating ?? "none"}');
      debugPrint('  - User answer: ${userAnswer ?? "self-assessed"}');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FlashcardService: Error recording answer: $e');
      return false;
    }
  }

  /// Record a self-assessment (Again, Hard, Good, Easy)
  Future<bool> recordSelfAssessment(String difficultyRating) async {
    if (_currentQuestion == null) {
      debugPrint(
          'FlashcardService: Cannot record self-assessment - no active question');
      return false;
    }

    // Map difficulty rating to correctness for mastery calculation
    final isCorrect = switch (difficultyRating.toLowerCase()) {
      'again' => false, // Incorrect - need to see again
      'hard' => true, // Correct but difficult
      'good' => true, // Correct and normal
      'easy' => true, // Correct and easy
      _ => true, // Default to correct
    };

    return await recordAnswer(
      isCorrect: isCorrect,
      difficultyRating: difficultyRating.toLowerCase(),
    );
  }

  /// Record a specific answer (for multiple choice, fill-in-blank, etc.)
  Future<bool> recordSpecificAnswer(String userAnswer) async {
    if (_currentQuestion == null) {
      debugPrint(
          'FlashcardService: Cannot record specific answer - no active question');
      return false;
    }

    final isCorrect = _currentQuestion!.isCorrectAnswer(userAnswer);

    // Auto-determine difficulty rating based on question type and correctness
    String difficultyRating;
    if (isCorrect) {
      // For objective questions, correct answers are generally "good"
      difficultyRating =
          _currentQuestion!.type == FlashcardQuestionType.multipleChoice
              ? 'good' // Multiple choice correct = good
              : 'good'; // Fill-in-blank correct = good
    } else {
      difficultyRating = 'again'; // Incorrect = need to see again
    }

    return await recordAnswer(
      isCorrect: isCorrect,
      userAnswer: userAnswer,
      difficultyRating: difficultyRating,
    );
  }

  /// Update vocabulary item mastery based on performance
  Future<void> _updateVocabularyMastery(
    UserVocabularyItem vocabularyItem, {
    required bool isCorrect,
    String? difficultyRating,
    int? responseTimeMs,
  }) async {
    try {
      // Calculate mastery adjustment based on difficulty rating
      double masteryMultiplier = 1.0;
      if (difficultyRating != null) {
        masteryMultiplier = switch (difficultyRating.toLowerCase()) {
          'again' => 0.7, // Reduce mastery more for "again"
          'hard' => 0.9, // Slight reduction for "hard"
          'good' => 1.0, // Normal mastery update
          'easy' => 1.1, // Slight boost for "easy"
          _ => 1.0,
        };
      }

      // Use the existing updateMastery method
      UserVocabularyItem updatedItem = vocabularyItem.updateMastery(isCorrect);

      // Apply difficulty rating adjustment to mastery level
      if (masteryMultiplier != 1.0) {
        final adjustedMastery =
            (updatedItem.masteryLevel * masteryMultiplier).round();
        updatedItem = updatedItem.copyWith(
          masteryLevel: adjustedMastery.clamp(0, 100),
          nextReview: updatedItem.calculateNextReview(),
        );
      }

      // Factor in response time (faster responses indicate better mastery)
      if (responseTimeMs != null && responseTimeMs > 0) {
        const int fastResponseThreshold = 3000; // 3 seconds
        const int slowResponseThreshold = 15000; // 15 seconds

        double timeMultiplier = 1.0;
        if (responseTimeMs < fastResponseThreshold && isCorrect) {
          timeMultiplier = 1.05; // Small boost for fast correct answers
        } else if (responseTimeMs > slowResponseThreshold) {
          timeMultiplier = 0.95; // Small penalty for very slow responses
        }

        if (timeMultiplier != 1.0) {
          final timeAdjustedMastery =
              (updatedItem.masteryLevel * timeMultiplier).round();
          updatedItem = updatedItem.copyWith(
            masteryLevel: timeAdjustedMastery.clamp(0, 100),
            nextReview: updatedItem.calculateNextReview(),
          );
        }
      }

      // Update through UserService and notify VocabularyService if available
      if (_userService != null) {
        try {
          await _userService!.saveVocabularyItem(updatedItem);
          debugPrint(
              'FlashcardService: Updated mastery for "${vocabularyItem.word}": ${vocabularyItem.masteryLevel} → ${updatedItem.masteryLevel}');

          // Notify VocabularyService to trigger UI updates
          _vocabularyService?.notifyListeners();
        } catch (e) {
          debugPrint(
              'FlashcardService: Warning - could not update vocabulary item: $e');
        }
      }
    } catch (e) {
      debugPrint('FlashcardService: Error updating vocabulary mastery: $e');
    }
  }

  /// Get performance statistics for the current session
  Map<String, dynamic> getSessionPerformanceStats() {
    if (_currentSession == null) return {};

    final cards = _currentSession!.cards;
    if (cards.isEmpty) return {};

    // Basic statistics
    final totalAnswered = cards.length;
    final correctAnswers = cards.where((card) => card.wasCorrect).length;
    final incorrectAnswers = totalAnswered - correctAnswers;
    final accuracy =
        totalAnswered > 0 ? (correctAnswers / totalAnswered) * 100 : 0.0;

    // Response time statistics
    final responseTimes = cards
        .where((card) => card.responseTimeMs != null)
        .map((card) => card.responseTimeMs!)
        .toList();

    final averageResponseTime = responseTimes.isNotEmpty
        ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
        : 0.0;

    // Difficulty rating distribution
    final difficultyRatings = <String, int>{};
    for (final card in cards) {
      final rating = card.difficultyRating ?? 'unrated';
      difficultyRatings[rating] = (difficultyRatings[rating] ?? 0) + 1;
    }

    // Question type performance
    final questionTypeStats = <String, Map<String, dynamic>>{};
    for (final card in cards) {
      final type = card.questionType;
      if (!questionTypeStats.containsKey(type)) {
        questionTypeStats[type] = {'total': 0, 'correct': 0};
      }
      questionTypeStats[type]!['total'] =
          questionTypeStats[type]!['total']! + 1;
      if (card.wasCorrect) {
        questionTypeStats[type]!['correct'] =
            questionTypeStats[type]!['correct']! + 1;
      }
    }

    // Calculate accuracy per question type
    for (final entry in questionTypeStats.entries) {
      final stats = entry.value;
      stats['accuracy'] =
          stats['total'] > 0 ? (stats['correct'] / stats['total']) * 100 : 0.0;
    }

    return {
      'totalAnswered': totalAnswered,
      'correctAnswers': correctAnswers,
      'incorrectAnswers': incorrectAnswers,
      'accuracy': accuracy,
      'averageResponseTimeMs': averageResponseTime,
      'difficultyRatings': difficultyRatings,
      'questionTypeStats': questionTypeStats,
      'sessionDurationMs': sessionDuration?.inMilliseconds ?? 0,
    };
  }

  /// Get performance improvement recommendations
  List<String> getPerformanceRecommendations() {
    final stats = getSessionPerformanceStats();
    final recommendations = <String>[];

    if (stats.isEmpty) return recommendations;

    final accuracy = stats['accuracy'] as double;
    final difficultyRatings = stats['difficultyRatings'] as Map<String, int>;
    final questionTypeStats =
        stats['questionTypeStats'] as Map<String, Map<String, dynamic>>;

    // Accuracy-based recommendations
    if (accuracy < 60) {
      recommendations.add(
          'Consider focusing on words with lower difficulty levels to build confidence');
      recommendations
          .add('Try shorter study sessions with more frequent reviews');
    } else if (accuracy > 85) {
      recommendations.add(
          'Great performance! Consider adding more challenging words to your study set');
      recommendations.add(
          'You might benefit from longer intervals between reviews for mastered words');
    }

    // Difficulty rating recommendations
    final againCount = difficultyRatings['again'] ?? 0;
    final totalRated =
        difficultyRatings.values.fold(0, (sum, count) => sum + count);

    if (totalRated > 0 && (againCount / totalRated) > 0.3) {
      recommendations.add(
          'Consider spending more time with problem words before moving on');
      recommendations
          .add('Try using example sentences to better understand word context');
    }

    // Question type recommendations
    String? weakestType;
    double lowestAccuracy = 100.0;

    for (final entry in questionTypeStats.entries) {
      final typeAccuracy = entry.value['accuracy'] as double;
      if (typeAccuracy < lowestAccuracy && entry.value['total'] >= 3) {
        lowestAccuracy = typeAccuracy;
        weakestType = entry.key;
      }
    }

    if (weakestType != null && lowestAccuracy < 70) {
      switch (weakestType) {
        case 'multipleChoice':
          recommendations.add(
              'Practice multiple choice questions by eliminating obviously wrong answers first');
          break;
        case 'fillInBlank':
          recommendations.add(
              'Focus on understanding word context and sentence structure');
          break;
        case 'reverse':
          recommendations.add(
              'Practice translating from your native language to the target language');
          break;
        case 'traditional':
          recommendations
              .add('Spend more time on basic word recognition and meaning');
          break;
      }
    }

    // Response time recommendations
    final averageResponseTime = stats['averageResponseTimeMs'] as double;
    if (averageResponseTime > 10000) {
      // More than 10 seconds
      recommendations
          .add('Try to answer more quickly to improve word recall speed');
      recommendations.add(
          'Consider reviewing words more frequently to improve automatic recall');
    }

    return recommendations;
  }

  /// Get detailed performance analysis for vocabulary items studied in this session
  Map<String, Map<String, dynamic>> getVocabularyItemPerformance() {
    if (_currentSession == null) return {};

    final itemPerformance = <String, Map<String, dynamic>>{};

    for (final card in _currentSession!.cards) {
      final itemId = card.vocabularyItemId;

      if (!itemPerformance.containsKey(itemId)) {
        itemPerformance[itemId] = {
          'totalAttempts': 0,
          'correctAttempts': 0,
          'averageResponseTime': 0.0,
          'difficultyRatings': <String, int>{},
          'lastAttemptCorrect': false,
          'improvementTrend': 'stable', // improving, declining, stable
        };
      }

      final stats = itemPerformance[itemId]!;
      stats['totalAttempts'] = stats['totalAttempts'] + 1;

      if (card.wasCorrect) {
        stats['correctAttempts'] = stats['correctAttempts'] + 1;
      }

      stats['lastAttemptCorrect'] = card.wasCorrect;

      // Update response time average
      if (card.responseTimeMs != null) {
        final currentAvg = stats['averageResponseTime'] as double;
        final attempts = stats['totalAttempts'] as int;
        stats['averageResponseTime'] =
            ((currentAvg * (attempts - 1)) + card.responseTimeMs!) / attempts;
      }

      // Update difficulty ratings
      final rating = card.difficultyRating ?? 'unrated';
      final ratings = stats['difficultyRatings'] as Map<String, int>;
      ratings[rating] = (ratings[rating] ?? 0) + 1;
    }

    // Calculate accuracy and improvement trends
    for (final stats in itemPerformance.values) {
      final total = stats['totalAttempts'] as int;
      final correct = stats['correctAttempts'] as int;
      stats['accuracy'] = total > 0 ? (correct / total) * 100 : 0.0;

      // Simple trend analysis based on recent performance
      if (total >= 3) {
        final lastCorrect = stats['lastAttemptCorrect'] as bool;
        final accuracy = stats['accuracy'] as double;

        if (lastCorrect && accuracy > 75) {
          stats['improvementTrend'] = 'improving';
        } else if (!lastCorrect && accuracy < 50) {
          stats['improvementTrend'] = 'declining';
        } else {
          stats['improvementTrend'] = 'stable';
        }
      }
    }

    return itemPerformance;
  }

  // Integration and Synchronization Methods

  /// Sync flashcard session data with vocabulary service
  Future<void> syncWithVocabularyService() async {
    if (_vocabularyService == null || _userService == null) {
      debugPrint('FlashcardService: Cannot sync - services not available');
      return;
    }

    try {
      debugPrint('FlashcardService: Starting sync with VocabularyService...');

      // Trigger vocabulary reload to get latest mastery levels
      if (_userService!.isLoggedIn) {
        // Force vocabulary service to reload user vocabulary
        final userVocabulary = await _userService!.getUserVocabulary();
        debugPrint(
            'FlashcardService: Synced ${userVocabulary.length} vocabulary items');

        // Notify vocabulary service of updates
        _vocabularyService!.notifyListeners();
        debugPrint('FlashcardService: Vocabulary sync completed');
      }
    } catch (e) {
      debugPrint('FlashcardService: Error during vocabulary sync: $e');
    }
  }

  /// Ensure session data integrity and fix any inconsistencies
  Future<void> validateSessionIntegrity() async {
    if (_currentSession == null) return;

    try {
      debugPrint('FlashcardService: Validating session integrity...');

      // Check if session cards match questions
      if (_currentSession!.cards.length != _sessionQuestions.length) {
        debugPrint(
            'FlashcardService: Warning - session cards/questions mismatch');
        debugPrint('  Cards: ${_currentSession!.cards.length}');
        debugPrint('  Questions: ${_sessionQuestions.length}');
      }

      // Validate vocabulary items still exist
      final vocabularyIds =
          _sessionQuestions.map((q) => q.vocabularyItem.id).toSet();

      if (_userService != null && _userService!.isLoggedIn) {
        final currentVocabulary = await _userService!.getUserVocabulary();
        final currentIds = currentVocabulary.map((v) => v.id).toSet();

        final missingIds = vocabularyIds.difference(currentIds);
        if (missingIds.isNotEmpty) {
          debugPrint(
              'FlashcardService: Warning - ${missingIds.length} vocabulary items no longer exist');
          // Could handle this by filtering out questions for missing items
        }
      }

      debugPrint('FlashcardService: Session integrity validation completed');
    } catch (e) {
      debugPrint('FlashcardService: Error during session validation: $e');
    }
  }

  /// Get integration health status
  Map<String, dynamic> getIntegrationStatus() {
    return {
      'isInitialized': _isInitialized,
      'hasUserService': _userService != null,
      'hasVocabularyService': _vocabularyService != null,
      'userLoggedIn': _userService?.isLoggedIn ?? false,
      'vocabularyServiceInitialized':
          _vocabularyService?.isInitialized ?? false,
      'currentSessionActive': _currentSession != null,
      'sessionStatus': _sessionStatus.name,
      'questionsLoaded': _sessionQuestions.length,
      'lastSync': DateTime.now().toIso8601String(),
    };
  }

  @override
  void dispose() {
    if (_userService != null && _userAuthListener != null) {
      _userService!.removeListener(_userAuthListener!);
    }
    if (_vocabularyService != null && _vocabularyListener != null) {
      _vocabularyService!.removeListener(_vocabularyListener!);
    }
    super.dispose();
  }
}
