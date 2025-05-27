import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:gotrue/gotrue.dart' as supabase_auth;
import '../models/user.dart' as app_user;
import 'auth_service.dart';
import '../config/supabase_config.dart';

class SupabaseAuthService implements AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  app_user.User? _currentUser;

  @override
  app_user.User? get currentUser => _currentUser;

  @override
  Stream<app_user.User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((event) {
      final session = event.session;
      if (session != null) {
        _currentUser = _convertSupabaseUser(session.user);
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
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _currentUser = _convertSupabaseUser(session.user);
      }
    } catch (e) {
      debugPrint('Error initializing Supabase Auth: $e');
    }
  }

  @override
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _currentUser = _convertSupabaseUser(response.user!);
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Sign in failed');
      }
    } on AuthException catch (e) {
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
    String lastName,
  ) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      if (response.user != null) {
        _currentUser = _convertSupabaseUser(response.user!);
        return AuthResult.success(_currentUser!);
      } else {
        return AuthResult.error('Account creation failed');
      }
    } on AuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback/',
      );
      
      // The OAuth flow will be handled by the platform
      // The auth state change listener will update the user
      return AuthResult.success(_currentUser!);
    } on AuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Google sign in failed: $e');
    }
  }

  @override
  Future<AuthResult> signInWithApple() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.flutter://login-callback/',
      );
      
      // The OAuth flow will be handled by the platform
      // The auth state change listener will update the user
      return AuthResult.success(_currentUser!);
    } on AuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Apple sign in failed: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  @override
  Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? profileImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (profileImageUrl != null) updates['avatar_url'] = profileImageUrl;

      await _supabase.auth.updateUser(
        UserAttributes(data: updates),
      );

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          firstName: firstName ?? _currentUser!.firstName,
          lastName: lastName ?? _currentUser!.lastName,
          profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
        );
      }
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      if (_currentUser?.id != null) {
        await _supabase.auth.admin.deleteUser(_currentUser!.id);
        _currentUser = null;
      }
    } on AuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  @override
  Future<bool> isPremiumUser() async {
    try {
      if (_currentUser?.id == null) return false;
      
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('is_premium')
          .eq('id', _currentUser!.id)
          .single();
      
      return response['is_premium'] ?? false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  @override
  Future<void> updatePremiumStatus(bool isPremium) async {
    try {
      if (_currentUser?.id == null) return;
      
      // Use the service role client for premium updates
      final serviceClient = SupabaseClient(
        SupabaseConfig.projectUrl,
        SupabaseConfig.serviceRoleKey,
      );
      
      await serviceClient
          .from(SupabaseConfig.usersTable)
          .update({'is_premium': isPremium})
          .eq('id', _currentUser!.id);
      
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(isPremium: isPremium);
      }
    } catch (e) {
      throw Exception('Failed to update premium status: $e');
    }
  }

  @override
  Future<void> cleanup() async {
    // Supabase handles cleanup automatically
  }

  // Helper methods
  app_user.User _convertSupabaseUser(supabase_auth.User user) {
    final userData = user.userMetadata ?? {};
    return app_user.User(
      id: user.id,
      email: user.email ?? '',
      firstName: userData['first_name'] ?? '',
      lastName: userData['last_name'] ?? '',
      createdAt: DateTime.parse(user.createdAt),
      lastLoginAt: user.lastSignInAt != null ? DateTime.parse(user.lastSignInAt!) : null,
      profileImageUrl: userData['avatar_url'],
      authProvider: user.appMetadata['provider'] ?? 'email',
      providerId: user.id,
      preferences: app_user.UserPreferences(),
      statistics: app_user.UserStatistics(),
    );
  }

  String _getErrorMessage(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'Invalid email or password.';
      case 'Email not confirmed':
        return 'Please confirm your email address.';
      case 'User already registered':
        return 'An account already exists with this email address.';
      case 'Password should be at least 6 characters':
        return 'Password must be at least 6 characters long.';
      case 'Invalid email':
        return 'Invalid email address.';
      case 'User not found':
        return 'No user found with this email address.';
      case 'Too many requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return e.message;
    }
  }
} 