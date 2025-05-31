import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import 'auth_service.dart';

/// Simple local authentication service for testing
class LocalAuthService implements AuthService {
  User? _currentUser;
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();
  
  // Simple in-memory user storage for testing
  final Map<String, Map<String, dynamic>> _registeredUsers = {};

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  Future<void> initialize() async {
    debugPrint('LocalAuth: Initialized');
    // For testing, we can start with no user logged in
    _currentUser = null;
  }

  @override
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    try {
      final userData = _registeredUsers[email.toLowerCase()];
      if (userData == null) {
        return AuthResult.error('No account found with this email address.');
      }

      final storedPasswordHash = userData['passwordHash'] as String;
      final inputPasswordHash = _hashPassword(password);

      if (storedPasswordHash != inputPasswordHash) {
        return AuthResult.error('Incorrect password.');
      }

      _currentUser = User(
        id: userData['id'] as String,
        email: email,
        firstName: userData['firstName'] as String,
        lastName: userData['lastName'] as String,
        createdAt: DateTime.parse(userData['createdAt'] as String),
        lastLoginAt: DateTime.now(),
        isPremium: userData['isPremium'] as bool? ?? false,
        preferences: UserPreferences(),
        statistics: UserStatistics(),
      );

      _authStateController.add(_currentUser);
      debugPrint('LocalAuth: User signed in: ${_currentUser!.email}');
      return AuthResult.success(_currentUser!);
    } catch (e) {
      return AuthResult.error('Sign in failed: $e');
    }
  }

  @override
  Future<AuthResult> createUserWithEmailAndPassword(
    String email, 
    String password, 
    String firstName, 
    String lastName
  ) async {
    await Future.delayed(const Duration(milliseconds: 700)); // Simulate network delay
    
    try {
      final emailLower = email.toLowerCase();
      
      // Check if user already exists
      if (_registeredUsers.containsKey(emailLower)) {
        return AuthResult.error('An account already exists with this email address.');
      }

      // Validate password strength
      if (password.length < 6) {
        return AuthResult.error('Password must be at least 6 characters long.');
      }

      // Create new user
      final userId = const Uuid().v4();
      final passwordHash = _hashPassword(password);
      final now = DateTime.now();

      _registeredUsers[emailLower] = {
        'id': userId,
        'email': email,
        'passwordHash': passwordHash,
        'firstName': firstName,
        'lastName': lastName,
        'createdAt': now.toIso8601String(),
        'isPremium': false,
      };

      _currentUser = User(
        id: userId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        createdAt: now,
        preferences: UserPreferences(),
        statistics: UserStatistics(),
      );

      _authStateController.add(_currentUser);
      debugPrint('LocalAuth: User created and signed in: ${_currentUser!.email}');
      return AuthResult.success(_currentUser!);
    } catch (e) {
      return AuthResult.error('Account creation failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    _currentUser = null;
    _authStateController.add(null);
    debugPrint('LocalAuth: User signed out');
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return AuthResult.error('Google Sign-In not available in local testing mode.');
  }

  @override
  Future<AuthResult> signInWithApple() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return AuthResult.error('Apple Sign-In not available in local testing mode.');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final emailLower = email.toLowerCase();
    if (!_registeredUsers.containsKey(emailLower)) {
      throw Exception('No account found with this email address.');
    }
    
    debugPrint('LocalAuth: Password reset email sent to $email (simulated)');
    // In a real implementation, this would send an actual email
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_currentUser == null) {
      throw Exception('No user signed in');
    }

    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters long.');
    }

    final emailLower = _currentUser!.email.toLowerCase();
    final userData = _registeredUsers[emailLower];
    if (userData != null) {
      userData['passwordHash'] = _hashPassword(newPassword);
      debugPrint('LocalAuth: Password updated for ${_currentUser!.email}');
    }
  }

  @override
  Future<void> updateUserProfile({
    String? firstName, 
    String? lastName, 
    String? profileImageUrl
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_currentUser == null) return;

    final emailLower = _currentUser!.email.toLowerCase();
    final userData = _registeredUsers[emailLower];
    if (userData != null) {
      if (firstName != null) userData['firstName'] = firstName;
      if (lastName != null) userData['lastName'] = lastName;
      if (profileImageUrl != null) userData['profileImageUrl'] = profileImageUrl;
    }

    _currentUser = _currentUser!.copyWith(
      firstName: firstName ?? _currentUser!.firstName,
      lastName: lastName ?? _currentUser!.lastName,
      profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
    );

    _authStateController.add(_currentUser);
    debugPrint('LocalAuth: Profile updated for ${_currentUser!.email}');
  }

  @override
  Future<void> deleteAccount() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_currentUser == null) return;

    final emailLower = _currentUser!.email.toLowerCase();
    _registeredUsers.remove(emailLower);
    
    debugPrint('LocalAuth: Account deleted for ${_currentUser!.email}');
    await signOut();
  }

  @override
  Future<bool> isPremiumUser() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _currentUser?.isPremium ?? false;
  }

  @override
  Future<void> updatePremiumStatus(bool isPremium) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (_currentUser == null) return;

    final emailLower = _currentUser!.email.toLowerCase();
    final userData = _registeredUsers[emailLower];
    if (userData != null) {
      userData['isPremium'] = isPremium;
    }

    _currentUser = _currentUser!.copyWith(isPremium: isPremium);
    _authStateController.add(_currentUser);
    debugPrint('LocalAuth: Premium status updated to $isPremium for ${_currentUser!.email}');
  }

  @override
  Future<void> cleanup() async {
    await _authStateController.close();
    debugPrint('LocalAuth: Cleanup completed');
  }

  // Helper methods
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Testing helper methods
  void clearAllUsers() {
    _registeredUsers.clear();
    _currentUser = null;
    _authStateController.add(null);
    debugPrint('LocalAuth: Cleared all users');
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'registered_users_count': _registeredUsers.length,
      'current_user': _currentUser?.email ?? 'None',
      'registered_emails': _registeredUsers.keys.toList(),
    };
  }

  void printDebugInfo() {
    final info = getDebugInfo();
    debugPrint('LocalAuth Debug Info: $info');
  }

  // Create a test premium user for testing
  Future<void> createTestPremiumUser() async {
    final emailLower = 'premium@test.com';
    
    // Check if user already exists
    if (_registeredUsers.containsKey(emailLower)) {
      debugPrint('LocalAuth: Premium test user already exists');
      return;
    }
    
    // Create user data without signing in
    final userId = const Uuid().v4();
    final passwordHash = _hashPassword('password123');
    final now = DateTime.now();

    _registeredUsers[emailLower] = {
      'id': userId,
      'email': 'premium@test.com',
      'passwordHash': passwordHash,
      'firstName': 'Premium',
      'lastName': 'User',
      'createdAt': now.toIso8601String(),
      'isPremium': true,
    };
    
    debugPrint('LocalAuth: Created test premium user (not signed in)');
  }

  // Create a test regular user for testing
  Future<void> createTestRegularUser() async {
    final emailLower = 'regular@test.com';
    
    // Check if user already exists
    if (_registeredUsers.containsKey(emailLower)) {
      debugPrint('LocalAuth: Regular test user already exists');
      return;
    }
    
    // Create user data without signing in
    final userId = const Uuid().v4();
    final passwordHash = _hashPassword('password123');
    final now = DateTime.now();

    _registeredUsers[emailLower] = {
      'id': userId,
      'email': 'regular@test.com',
      'passwordHash': passwordHash,
      'firstName': 'Regular',
      'lastName': 'User',
      'createdAt': now.toIso8601String(),
      'isPremium': false,
    };
    
    debugPrint('LocalAuth: Created test regular user (not signed in)');
  }
} 