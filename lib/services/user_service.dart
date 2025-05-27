import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/user_vocabulary.dart';
import 'auth_service.dart';
import 'database_service.dart';

class UserService extends ChangeNotifier {
  final AuthService _authService;
  final DatabaseService _databaseService;
  
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserService({
    required AuthService authService,
    required DatabaseService databaseService,
  }) : _authService = authService, _databaseService = databaseService {
    _initialize();
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isPremium => _currentUser?.isPremium ?? false;

  void _initialize() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) async {
      debugPrint('UserService: Auth state changed - user: ${user?.email ?? 'null'}');
      if (user != null) {
        // Set the user directly from auth service
        _currentUser = user;
        notifyListeners();
        
        // Try to sync with database, but don't fail if it doesn't work
        try {
          final dbUser = await _databaseService.getUserById(user.id);
          if (dbUser != null) {
            _currentUser = dbUser;
            debugPrint('UserService: Loaded user from database: ${dbUser.email}');
          } else {
            // Create user in database if it doesn't exist
            await _databaseService.createUser(user);
            debugPrint('UserService: Created user in database: ${user.email}');
          }
        } catch (e) {
          debugPrint('UserService: Database sync failed (using auth user): $e');
          // Continue with auth user even if database fails
        }
        notifyListeners();
      } else {
        _currentUser = null;
        debugPrint('UserService: User signed out');
        notifyListeners();
      }
    });
  }

  // Authentication methods
  Future<AuthResult> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _authService.signInWithEmailAndPassword(email, password);
      
      if (result.success && result.user != null) {
        _currentUser = result.user;
        // Update last login
        await _updateLastLogin();
      } else {
        _error = result.error;
      }
      
      return result;
    } catch (e) {
      _error = 'Sign in failed: $e';
      return AuthResult.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> signUp(String email, String password, String firstName, String lastName) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create user in authentication system
      final authResult = await _authService.createUserWithEmailAndPassword(email, password, firstName, lastName);
      
      if (authResult.success && authResult.user != null) {
        // Upsert user in database (prevents duplicate key errors)
        final user = User(
          id: authResult.user!.id,
          email: email,
          passwordHash: _hashPassword(password),
          firstName: firstName,
          lastName: lastName,
          createdAt: DateTime.now(),
          preferences: UserPreferences(),
          statistics: UserStatistics(),
        );
        await _databaseService.createUser(user); // This is now upsert
        _currentUser = user;
        return AuthResult.success(user);
      } else {
        _error = authResult.error;
        return authResult;
      }
    } catch (e) {
      _error = 'Sign up failed: $e';
      return AuthResult.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Sign out failed: $e';
      notifyListeners();
    }
  }

  // OAuth methods
  Future<AuthResult> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _authService.signInWithGoogle();
      
      if (result.success && result.user != null) {
        // Check if user exists in database, create if not
        final existingUser = await _databaseService.getUserById(result.user!.id);
        if (existingUser == null) {
          await _databaseService.createUser(result.user!);
        }
        _currentUser = result.user;
        await _updateLastLogin();
      } else {
        _error = result.error;
      }
      
      return result;
    } catch (e) {
      _error = 'Google sign in failed: $e';
      return AuthResult.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // User profile management
  Future<void> updateProfile({String? firstName, String? lastName, String? profileImageUrl}) async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updatedUser = _currentUser!.copyWith(
        firstName: firstName ?? _currentUser!.firstName,
        lastName: lastName ?? _currentUser!.lastName,
        profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
      );

      await _databaseService.updateUser(updatedUser);
      await _authService.updateUserProfile(
        firstName: firstName,
        lastName: lastName,
        profileImageUrl: profileImageUrl,
      );

      _currentUser = updatedUser;
    } catch (e) {
      _error = 'Failed to update profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    if (_currentUser == null) return;

    try {
      final updatedUser = _currentUser!.copyWith(preferences: preferences);
      await _databaseService.updateUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update preferences: $e';
      notifyListeners();
    }
  }

  // Premium management
  Future<void> upgradeToPremium() async {
    if (_currentUser == null) return;

    try {
      await _databaseService.updatePremiumStatus(_currentUser!.id, true);
      await _authService.updatePremiumStatus(true);
      
      _currentUser = _currentUser!.copyWith(isPremium: true);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to upgrade to premium: $e';
      notifyListeners();
    }
  }

  // Vocabulary management
  Future<List<UserVocabularyItem>> getUserVocabulary({String? language}) async {
    if (_currentUser == null) return [];

    try {
      return await _databaseService.getUserVocabulary(
        _currentUser!.id,
        language: language ?? _currentUser!.preferences.targetLanguage,
      );
    } catch (e) {
      _error = 'Failed to load vocabulary: $e';
      notifyListeners();
      return [];
    }
  }

  Future<void> saveVocabularyItem(UserVocabularyItem item) async {
    if (_currentUser == null) return;

    try {
      await _databaseService.saveVocabularyItem(item);
      await _updateVocabularyStats(item.language);
    } catch (e) {
      _error = 'Failed to save vocabulary item: $e';
      notifyListeners();
    }
  }

  Future<UserVocabularyStats?> getVocabularyStats({String? language}) async {
    if (_currentUser == null) return null;

    try {
      return await _databaseService.getUserVocabularyStats(
        _currentUser!.id,
        language ?? _currentUser!.preferences.targetLanguage,
      );
    } catch (e) {
      _error = 'Failed to load vocabulary stats: $e';
      notifyListeners();
      return null;
    }
  }

  // Chat history (premium only)
  Future<void> saveChatMessage(Map<String, dynamic> message) async {
    if (_currentUser == null || !_currentUser!.isPremium) return;

    try {
      await _databaseService.saveChatMessage(_currentUser!.id, message);
    } catch (e) {
      _error = 'Failed to save chat message: $e';
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 50}) async {
    if (_currentUser == null || !_currentUser!.isPremium) return [];

    try {
      return await _databaseService.getChatHistory(_currentUser!.id, limit: limit);
    } catch (e) {
      _error = 'Failed to load chat history: $e';
      notifyListeners();
      return [];
    }
  }

  // Helper methods
  Future<void> _updateLastLogin() async {
    if (_currentUser == null) return;

    try {
      final updatedUser = _currentUser!.copyWith(lastLoginAt: DateTime.now());
      await _databaseService.updateUser(updatedUser);
      _currentUser = updatedUser;
    } catch (e) {
      debugPrint('Failed to update last login: $e');
    }
  }

  Future<void> _updateVocabularyStats(String language) async {
    if (_currentUser == null) return;

    try {
      final vocabulary = await _databaseService.getUserVocabulary(_currentUser!.id, language: language);
      
      final totalWords = vocabulary.length;
      final masteredWords = vocabulary.where((item) => item.masteryLevel >= 90).length;
      final learningWords = vocabulary.where((item) => item.masteryLevel >= 30 && item.masteryLevel < 90).length;
      final newWords = vocabulary.where((item) => item.masteryLevel < 30).length;
      final wordsDueReview = vocabulary.where((item) => item.needsReview).length;
      final averageMastery = totalWords > 0 
          ? vocabulary.map((item) => item.masteryLevel).reduce((a, b) => a + b) / totalWords 
          : 0.0;

      final wordsByType = <String, int>{};
      for (final item in vocabulary) {
        wordsByType[item.wordType] = (wordsByType[item.wordType] ?? 0) + 1;
      }

      final stats = UserVocabularyStats(
        userId: _currentUser!.id,
        language: language,
        totalWords: totalWords,
        masteredWords: masteredWords,
        learningWords: learningWords,
        newWords: newWords,
        wordsDueReview: wordsDueReview,
        averageMastery: averageMastery,
        lastUpdated: DateTime.now(),
        wordsByType: wordsByType,
      );

      await _databaseService.updateVocabularyStats(stats);
    } catch (e) {
      debugPrint('Failed to update vocabulary stats: $e');
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate unique ID
  String _generateId() {
    return const Uuid().v4();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
} 