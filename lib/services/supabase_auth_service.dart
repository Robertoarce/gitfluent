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
      debugPrint('SupabaseAuthService: Initializing Supabase Auth');
      final session = _supabase.auth.currentSession;
      if (session != null) {
        debugPrint('SupabaseAuthService: Found existing session, user ID: ${session.user.id}');
        _currentUser = _convertSupabaseUser(session.user);
        
        // Fetch complete user data including premium status
        try {
          debugPrint('SupabaseAuthService: Fetching complete user data during initialization');
          final dbUser = await _supabase
              .from(SupabaseConfig.usersTable)
              .select('*')
              .eq('id', _currentUser!.id)
              .single();
          
          if (dbUser != null) {
            final isPremium = dbUser['is_premium'] ?? false;
            _currentUser = _currentUser!.copyWith(isPremium: isPremium);
            debugPrint('SupabaseAuthService: Set premium status to $isPremium during initialization');
          }
        } catch (dbError) {
          debugPrint('SupabaseAuthService: Error fetching user data during initialization: $dbError');
          // Try with service role client if regular client fails
          try {
            debugPrint('SupabaseAuthService: Attempting with service role client');
            final serviceClient = SupabaseClient(
              SupabaseConfig.projectUrl,
              SupabaseConfig.serviceRoleKey,
            );
            
            final dbUser = await serviceClient
                .from(SupabaseConfig.usersTable)
                .select('*')
                .eq('id', _currentUser!.id)
                .single();
            
            if (dbUser != null) {
              final isPremium = dbUser['is_premium'] ?? false;
              _currentUser = _currentUser!.copyWith(isPremium: isPremium);
              debugPrint('SupabaseAuthService: Set premium status to $isPremium with service role');
            }
          } catch (serviceError) {
            debugPrint('SupabaseAuthService: Service role attempt also failed: $serviceError');
            // Continue with auth user if all database fetches fail
          }
        }
      } else {
        debugPrint('SupabaseAuthService: No active session found');
      }
    } catch (e) {
      debugPrint('Error initializing Supabase Auth: $e');
    }
  }

  @override
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      debugPrint('SupabaseAuthService: Signing in user with email: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('SupabaseAuthService: Sign in successful for: $email');
        _currentUser = _convertSupabaseUser(response.user!);
        
        // Attempt to fetch the complete user data including premium status
        try {
          debugPrint('SupabaseAuthService: Fetching complete user data from database');
          final dbUser = await _supabase
              .from(SupabaseConfig.usersTable)
              .select('*')
              .eq('id', _currentUser!.id)
              .single();
          
          if (dbUser != null) {
            // Update premium status from database
            final isPremium = dbUser['is_premium'] ?? false;
            _currentUser = _currentUser!.copyWith(isPremium: isPremium);
            debugPrint('SupabaseAuthService: Set premium status to $isPremium from database');
          }
        } catch (dbError) {
          debugPrint('SupabaseAuthService: Error fetching user data from database: $dbError');
          // Continue with auth user if database fetch fails
          // Premium status will be fetched in background by _fetchAndUpdatePremiumStatus
        }
        
        return AuthResult.success(_currentUser!);
      } else {
        debugPrint('SupabaseAuthService: Sign in failed - no user returned');
        return AuthResult.error('Sign in failed');
      }
    } on AuthException catch (e) {
      debugPrint('SupabaseAuthService: Auth exception: ${e.message}');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      debugPrint('SupabaseAuthService: Unexpected error: $e');
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
      debugPrint('=========== SUPABASE AUTH SIGNUP START ===========');
      debugPrint('SupabaseAuthService: Starting signUp for email: $email');
      debugPrint('SupabaseAuthService: Using firstName: $firstName, lastName: $lastName');
      
      debugPrint('SupabaseAuthService: Calling supabase.auth.signUp');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      debugPrint('SupabaseAuthService: Auth signUp response received');
      debugPrint('SupabaseAuthService: User ID: ${response.user?.id ?? 'null'}');
      debugPrint('SupabaseAuthService: Session: ${response.session != null ? 'active' : 'null'}');
      debugPrint('SupabaseAuthService: Email confirmed: ${response.user?.emailConfirmedAt != null ? 'yes' : 'no'}');
      
      if (response.user != null) {
        _currentUser = _convertSupabaseUser(response.user!);
        debugPrint('SupabaseAuthService: User created successfully: ${_currentUser!.id}');
        debugPrint('SupabaseAuthService: User metadata: ${response.user!.userMetadata}');
        debugPrint('SupabaseAuthService: User app metadata: ${response.user!.appMetadata}');
        debugPrint('=========== SUPABASE AUTH SIGNUP END (SUCCESS) ===========');
        return AuthResult.success(_currentUser!);
      } else {
        debugPrint('SupabaseAuthService: Account creation failed - no user returned');
        debugPrint('=========== SUPABASE AUTH SIGNUP END (FAILURE) ===========');
        return AuthResult.error('Account creation failed');
      }
    } on AuthException catch (e) {
      debugPrint('SupabaseAuthService: Auth exception: ${e.message}, statusCode: ${e.statusCode}');
      debugPrint('SupabaseAuthService: Error details: ${e.toString()}');
      debugPrint('=========== SUPABASE AUTH SIGNUP END (AUTH EXCEPTION) ===========');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      debugPrint('SupabaseAuthService: Unexpected error: $e');
      debugPrint('SupabaseAuthService: Error type: ${e.runtimeType}');
      debugPrint('=========== SUPABASE AUTH SIGNUP END (UNEXPECTED EXCEPTION) ===========');
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
      debugPrint('SupabaseAuthService: Starting Google sign in flow');
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback/',
      );
      
      // The OAuth flow will be handled by the platform
      // After the flow completes, the auth state change listener will update the user
      // Check if the user is logged in
      final session = _supabase.auth.currentSession;
      if (session != null && session.user != null) {
        debugPrint('SupabaseAuthService: Google sign in successful');
        _currentUser = _convertSupabaseUser(session.user);
        
        // Try to fetch premium status directly
        try {
          debugPrint('SupabaseAuthService: Fetching premium status after Google sign in');
          final dbUser = await _supabase
              .from(SupabaseConfig.usersTable)
              .select('is_premium')
              .eq('id', _currentUser!.id)
              .single();
          
          if (dbUser != null) {
            final isPremium = dbUser['is_premium'] ?? false;
            _currentUser = _currentUser!.copyWith(isPremium: isPremium);
            debugPrint('SupabaseAuthService: Set premium status to $isPremium after Google sign in');
          }
        } catch (dbError) {
          debugPrint('SupabaseAuthService: Error fetching premium status after Google sign in: $dbError');
          // Continue with auth user if database fetch fails
        }
        
        return AuthResult.success(_currentUser!);
      } else {
        debugPrint('SupabaseAuthService: Google sign in - no session or user found');
        return AuthResult.error('Google sign in failed');
      }
    } on AuthException catch (e) {
      debugPrint('SupabaseAuthService: Google sign in auth exception: ${e.message}');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      debugPrint('SupabaseAuthService: Google sign in unexpected error: $e');
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
    
    // Create the user with default premium status
    final newUser = app_user.User(
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
      // Default premium to false, will be updated from database
      isPremium: false,
    );

    // Immediately try to fetch premium status in the background
    _fetchAndUpdatePremiumStatus(newUser.id);
    
    return newUser;
  }

  // Fetch premium status and update current user
  Future<void> _fetchAndUpdatePremiumStatus(String userId) async {
    try {
      debugPrint('SupabaseAuthService: Fetching premium status for user: $userId');
      
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('is_premium')
          .eq('id', userId)
          .single();
      
      final isPremium = response['is_premium'] ?? false;
      debugPrint('SupabaseAuthService: Premium status from database: $isPremium');
      
      if (_currentUser != null && _currentUser!.id == userId) {
        _currentUser = _currentUser!.copyWith(isPremium: isPremium);
        debugPrint('SupabaseAuthService: Updated user premium status to: $isPremium');
      }
    } catch (e) {
      debugPrint('SupabaseAuthService: Error fetching premium status: $e');
      
      // Try with service role client if regular client fails
      try {
        final serviceClient = SupabaseClient(
          SupabaseConfig.projectUrl,
          SupabaseConfig.serviceRoleKey,
        );
        
        final response = await serviceClient
            .from(SupabaseConfig.usersTable)
            .select('is_premium')
            .eq('id', userId)
            .single();
        
        final isPremium = response['is_premium'] ?? false;
        debugPrint('SupabaseAuthService: Premium status from service role client: $isPremium');
        
        if (_currentUser != null && _currentUser!.id == userId) {
          _currentUser = _currentUser!.copyWith(isPremium: isPremium);
          debugPrint('SupabaseAuthService: Updated user premium status to: $isPremium');
        }
      } catch (serviceError) {
        debugPrint('SupabaseAuthService: Error fetching premium status with service role: $serviceError');
      }
    }
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