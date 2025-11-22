import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'dart:math';
import '../services/user_service.dart';
import '../models/user_vocabulary.dart';
import '../models/flashcard_session.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  List<UserVocabularyItem> _reviewItems = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  FlashcardSession? _currentSession;
  
  // Animation
  late AnimationController _flipController;
  late Animation<double> _frontAnimation;
  late Animation<double> _backAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _frontAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -pi / 2), weight: 50),
      TweenSequenceItem(tween: ConstantTween(-pi / 2), weight: 50),
    ]).animate(_flipController);

    _backAnimation = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(pi / 2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: pi / 2, end: 0.0), weight: 50),
    ]).animate(_flipController);

    _loadSession();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    try {
      final userService = context.read<UserService>();
      if (!userService.isLoggedIn) {
        // Handle not logged in
        setState(() => _isLoading = false);
        return;
      }

      final items = await userService.getUserVocabulary();
      // Filter for items due for review
      final dueItems = items.where((item) => item.needsReview).toList();
      
      // If no items due, maybe add some new ones or random ones for practice
      if (dueItems.isEmpty && items.isNotEmpty) {
        // For now, just show empty state
      }

      // Create a session
      if (dueItems.isNotEmpty) {
        final session = FlashcardSession.create(
          userId: userService.currentUser!.id,
          durationMinutes: 0, // Will update on completion
        );
        // Save session start? Maybe later.
        
        setState(() {
          _reviewItems = dueItems;
          _currentSession = session;
        });
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  Future<void> _handleResponse(int difficulty) async {
    // difficulty: 1 (Again), 2 (Hard), 3 (Good), 4 (Easy)
    final item = _reviewItems[_currentIndex];
    final userService = context.read<UserService>();

    // Update item mastery
    // Simple SRS logic for now
    bool wasCorrect = difficulty > 1;
    UserVocabularyItem updatedItem = item.updateMastery(wasCorrect);
    
    // Adjust next review based on difficulty
    if (difficulty == 4) { // Easy
      updatedItem = updatedItem.copyWith(
        nextReview: DateTime.now().add(const Duration(days: 4)),
      );
    } else if (difficulty == 3) { // Good
      updatedItem = updatedItem.copyWith(
        nextReview: DateTime.now().add(const Duration(days: 1)),
      );
    } else if (difficulty == 2) { // Hard
      updatedItem = updatedItem.copyWith(
        nextReview: DateTime.now().add(const Duration(hours: 12)),
      );
    } else { // Again
      updatedItem = updatedItem.copyWith(
        nextReview: DateTime.now().add(const Duration(minutes: 10)),
      );
    }

    await userService.saveVocabularyItem(updatedItem);

    // Move to next card
    if (_currentIndex < _reviewItems.length - 1) {
      // Reset flip
      _flipController.reset();
      setState(() {
        _isFlipped = false;
        _currentIndex++;
      });
    } else {
      // Session complete
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Text('You reviewed ${_reviewItems.length} words.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reviewItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('All caught up!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('No words due for review right now.'),
              const SizedBox(height: 24),
              ShadButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final currentItem = _reviewItems[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Review (${_currentIndex + 1}/${_reviewItems.length})'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _reviewItems.length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6B47ED)),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: GestureDetector(
                    onTap: _flipCard,
                    child: Stack(
                      children: [
                        // Back of card (Translation)
                        AnimatedBuilder(
                          animation: _backAnimation,
                          builder: (context, child) {
                            final transform = Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(_backAnimation.value);
                            return Transform(
                              transform: transform,
                              alignment: Alignment.center,
                              child: _isFlipped 
                                  ? _buildCardBack(currentItem) 
                                  : Container(), // Hide when not visible to avoid interaction
                            );
                          },
                        ),
                        // Front of card (Word)
                        AnimatedBuilder(
                          animation: _frontAnimation,
                          builder: (context, child) {
                            final transform = Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(_frontAnimation.value);
                            return Transform(
                              transform: transform,
                              alignment: Alignment.center,
                              child: !_isFlipped 
                                  ? _buildCardFront(currentItem) 
                                  : Container(), // Hide when not visible
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Controls
            if (_isFlipped)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDifficultyButton('Again', Colors.red, 1),
                    _buildDifficultyButton('Hard', Colors.orange, 2),
                    _buildDifficultyButton('Good', Colors.blue, 3),
                    _buildDifficultyButton('Easy', Colors.green, 4),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ShadButton(
                    onPressed: _flipCard,
                    child: const Text('Show Answer'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(UserVocabularyItem item) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.word,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            item.wordType,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(UserVocabularyItem item) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF6B47ED), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.translations.join(', '),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Divider(indent: 40, endIndent: 40),
          const SizedBox(height: 24),
          if (item.exampleSentences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                item.exampleSentences.first,
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultyButton(String label, Color color, int difficulty) {
    return Column(
      children: [
        InkWell(
          onTap: () => _handleResponse(difficulty),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Icon(Icons.check, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
