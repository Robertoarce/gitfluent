import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart' as app_user;
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  app_user.User? _currentUser;

  @override
  app_user.User? get currentUser => _currentUser;

  @override
  Stream<app_user.User?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser != null) {
        _currentUser = await _convertFirebaseUser(firebaseUser);
        return _currentUser;
      } else {
        _currentUser = null;
        return null;
      }
    });
  }

  @override
  Future<void> initialize() async {
    try {
      // Firebase Auth initializes automatically with Firebase Core
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        _currentUser = await _convertFirebaseUser(firebaseUser);
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Auth: $e');
    }
  }

  @override
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        _currentUser = await _convertFirebaseUser(credential.user!);
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Sign in failed');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  @override
  Future<AuthResult> createUserWithEmailAndPassword(
    String email, 
    String password, 
    String firstName, 
    String lastName
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update the display name
        await credential.user!.updateDisplayName('$firstName $lastName');
        
        _currentUser = await _convertFirebaseUser(
          credential.user!, 
          firstName: firstName, 
          lastName: lastName
        );
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Account creation failed');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Note: Google Sign-In requires additional setup and dependencies
      // For now, we'll return an error indicating it's not implemented
      return AuthResult.error('Google Sign-In not implemented yet. Please use email/password.');
    } catch (e) {
      return AuthResult.error('Google sign in failed: $e');
    }
  }

  @override
  Future<AuthResult> signInWithApple() async {
    try {
      // Note: Apple Sign-In requires additional setup and dependencies
      // For now, we'll return an error indicating it's not implemented
      return AuthResult.error('Apple Sign-In not implemented yet. Please use email/password.');
    } catch (e) {
      return AuthResult.error('Apple sign in failed: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      } else {
        throw Exception('No user signed in');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  @override
  Future<void> updateUserProfile({
    String? firstName, 
    String? lastName, 
    String? profileImageUrl
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        String? displayName;
        if (firstName != null || lastName != null) {
          final currentFirstName = firstName ?? _currentUser?.firstName ?? '';
          final currentLastName = lastName ?? _currentUser?.lastName ?? '';
          displayName = '$currentFirstName $currentLastName'.trim();
        }

        await user.updateDisplayName(displayName);
        if (profileImageUrl != null) {
          await user.updatePhotoURL(profileImageUrl);
        }

        // Update our current user
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            firstName: firstName ?? _currentUser!.firstName,
            lastName: lastName ?? _currentUser!.lastName,
            profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
        _currentUser = null;
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  @override
  Future<bool> isPremiumUser() async {
    // This would typically check custom claims or database
    // For now, return the current user's premium status
    return _currentUser?.isPremium ?? false;
  }

  @override
  Future<void> updatePremiumStatus(bool isPremium) async {
    // This would typically update custom claims
    // For now, we'll just update our local user object
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isPremium: isPremium);
    }
  }

  @override
  Future<void> cleanup() async {
    // Firebase Auth handles cleanup automatically
  }

  // Helper methods
  Future<app_user.User> _convertFirebaseUser(
    firebase_auth.User firebaseUser, {
    String? firstName,
    String? lastName,
  }) async {
    final displayName = firebaseUser.displayName ?? '';
    final nameParts = displayName.split(' ');
    
    final userFirstName = firstName ?? (nameParts.isNotEmpty ? nameParts.first : '');
    final userLastName = lastName ?? (nameParts.length > 1 ? nameParts.skip(1).join(' ') : '');

    return app_user.User(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      firstName: userFirstName,
      lastName: userLastName,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: firebaseUser.metadata.lastSignInTime,
      profileImageUrl: firebaseUser.photoURL,
      authProvider: _getAuthProvider(firebaseUser),
      providerId: firebaseUser.uid,
      preferences: app_user.UserPreferences(),
      statistics: app_user.UserStatistics(),
    );
  }

  String _getAuthProvider(firebase_auth.User firebaseUser) {
    if (firebaseUser.providerData.isNotEmpty) {
      final providerId = firebaseUser.providerData.first.providerId;
      switch (providerId) {
        case 'google.com':
          return 'google';
        case 'apple.com':
          return 'apple';
        case 'password':
        default:
          return 'email';
      }
    }
    return 'email';
  }

  String _getErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
} 