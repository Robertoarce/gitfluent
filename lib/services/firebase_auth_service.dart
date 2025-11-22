import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/user.dart' as app_user;
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  app_user.User? _currentUser;

  @override
  app_user.User? get currentUser => _currentUser;

  @override
  Stream<app_user.User?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) {
        _currentUser = null;
        return null;
      }
      
      // If we already have a complete user object, return it
      if (_currentUser != null && _currentUser!.id == firebaseUser.uid) {
        return _currentUser;
      }
      
      // Otherwise create a basic user object from Firebase user
      _currentUser = _convertFirebaseUser(firebaseUser);
      return _currentUser;
    });
  }

  @override
  Future<void> initialize() async {
    // Firebase is initialized in main.dart, but we can check current user here
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      _currentUser = _convertFirebaseUser(firebaseUser);
    }
  }

  @override
  Future<AuthResult> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        _currentUser = _convertFirebaseUser(credential.user!);
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Sign in failed');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.error(e.message ?? 'Authentication failed');
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  @override
  Future<AuthResult> createUserWithEmailAndPassword(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName('$firstName $lastName');
        
        _currentUser = _convertFirebaseUser(credential.user!);
        // Note: We need to store first/last name in Firestore separately since
        // Firebase Auth only has displayName
        
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Account creation failed');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.error(e.message ?? 'Account creation failed');
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    _currentUser = null;
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    // Note: This requires platform specific setup (Google Sign In)
    // For now we'll just return an error if not implemented fully
    // In a real app, you'd use google_sign_in package here
    return AuthResult.error('Google Sign In not implemented yet');
  }

  @override
  Future<AuthResult> signInWithApple() async {
    return AuthResult.error('Apple Sign In not implemented yet');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _firebaseAuth.currentUser?.updatePassword(newPassword);
  }

  @override
  Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? profileImageUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    if (firstName != null || lastName != null) {
      final currentName = user.displayName ?? '';
      final parts = currentName.split(' ');
      final currentFirst = parts.isNotEmpty ? parts.first : '';
      final currentLast = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      
      final newFirst = firstName ?? currentFirst;
      final newLast = lastName ?? currentLast;
      
      await user.updateDisplayName('$newFirst $newLast');
    }

    if (profileImageUrl != null) {
      await user.updatePhotoURL(profileImageUrl);
    }
    
    // Update local user
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        firstName: firstName ?? _currentUser!.firstName,
        lastName: lastName ?? _currentUser!.lastName,
        profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
      );
    }
  }

  @override
  Future<void> deleteAccount() async {
    await _firebaseAuth.currentUser?.delete();
    _currentUser = null;
  }

  @override
  Future<bool> isPremiumUser() async {
    // This should be checked against Firestore or Claims
    // For now, return false or check local user
    return _currentUser?.isPremium ?? false;
  }

  @override
  Future<void> updatePremiumStatus(bool isPremium) async {
    // This should update Firestore
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isPremium: isPremium);
    }
  }

  @override
  Future<void> cleanup() async {
    // Nothing to clean up
  }

  app_user.User _convertFirebaseUser(firebase_auth.User user) {
    final nameParts = (user.displayName ?? '').split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    return app_user.User(
      id: user.uid,
      email: user.email ?? '',
      firstName: firstName,
      lastName: lastName,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime,
      profileImageUrl: user.photoURL,
      authProvider: user.providerData.isNotEmpty 
          ? user.providerData.first.providerId 
          : 'email',
      providerId: user.uid,
      preferences: app_user.UserPreferences(),
      statistics: app_user.UserStatistics(),
      isPremium: false, // Will be updated from Firestore
    );
  }
}
