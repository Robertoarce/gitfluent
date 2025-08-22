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
      debugPrint(
          '🚀 SupabaseAuthService.authStateChanges: Event received - ${event.event}');
      final session = event.session;
      if (session != null) {
        debugPrint(
            '🚀 SupabaseAuthService.authStateChanges: Session found, user ID: ${session.user.id}');

        // 🔧 CRITICAL FIX: Don't overwrite complete user data with incomplete data
        if (_currentUser != null &&
            _currentUser!.id == session.user.id &&
            _currentUser!.targetLanguage != null &&
            _currentUser!.targetLanguage != 'null') {
          debugPrint(
              '🔧 SupabaseAuthService.authStateChanges: Preserving existing complete user data - target: "${_currentUser!.targetLanguage}", native: "${_currentUser!.nativeLanguage}"');
          return _currentUser; // Return existing complete user
        }

        debugPrint(
            '🚀 SupabaseAuthService.authStateChanges: About to call _convertSupabaseUser...');
        _currentUser = _convertSupabaseUser(session.user);
        debugPrint(
            '🚀 SupabaseAuthService.authStateChanges: _convertSupabaseUser completed - target: "${_currentUser!.targetLanguage}", native: "${_currentUser!.nativeLanguage}"');
        return _currentUser;
      } else {
        debugPrint(
            '🚀 SupabaseAuthService.authStateChanges: No session, setting user to null');
        _currentUser = null;
        return null;
      }
    });
  }

  @override
  Future<void> initialize() async {
    try {
      debugPrint('🚀 SupabaseAuthService: INITIALIZE METHOD CALLED');
      final session = _supabase.auth.currentSession;
      debugPrint(
          '🚀 SupabaseAuthService: currentSession = ${session != null ? session.user.id : 'NULL'}');
      if (session != null) {
        debugPrint(
            'SupabaseAuthService: Found existing session, user ID: ${session.user.id}');

        // 🔧 CRITICAL FIX: Don't overwrite complete user data with incomplete data
        if (_currentUser != null &&
            _currentUser!.id == session.user.id &&
            _currentUser!.targetLanguage != null &&
            _currentUser!.targetLanguage != 'null') {
          debugPrint(
              '🔧 SupabaseAuthService.initialize: Preserving existing complete user data - target: "${_currentUser!.targetLanguage}", native: "${_currentUser!.nativeLanguage}"');
        } else {
          _currentUser = _convertSupabaseUser(session.user);
        }

        // Fetch complete user data including language settings and premium status
        try {
          debugPrint(
              'SupabaseAuthService: Fetching complete user data during initialization');
          final dbUser = await _supabase
              .from(SupabaseConfig.usersTable)
              .select('*')
              .eq('id', _currentUser!.id)
              .single();

          if (dbUser != null) {
            // 🔧 FIX: Create complete user object from database using User.fromSupabase
            _currentUser = app_user.User.fromSupabase(dbUser);
            debugPrint(
                'SupabaseAuthService: Created complete user from database with language settings');
            debugPrint(
                'SupabaseAuthService: User language settings - target: ${_currentUser!.targetLanguage}, native: ${_currentUser!.nativeLanguage}');
          }
        } catch (dbError) {
          debugPrint(
              'SupabaseAuthService: Error fetching user data during initialization: $dbError');
          // Try with service role client if regular client fails
          try {
            debugPrint(
                'SupabaseAuthService: Attempting with service role client');
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
              // 🔧 FIX: Create complete user object from database using User.fromSupabase
              _currentUser = app_user.User.fromSupabase(dbUser);
              debugPrint(
                  'SupabaseAuthService: Created complete user from database with service role');
              debugPrint(
                  'SupabaseAuthService: User language settings - target: ${_currentUser!.targetLanguage}, native: ${_currentUser!.nativeLanguage}');
            }
          } catch (serviceError) {
            debugPrint(
                'SupabaseAuthService: Service role attempt also failed: $serviceError');
            // Continue with auth user if all database fetches fail
          }
        }
      } else {
        debugPrint(
            '🚀 SupabaseAuthService: No active session found - this is why DB fetch didn\'t happen');
      }
    } catch (e) {
      debugPrint('🚨 SupabaseAuthService: EXCEPTION during initialization: $e');
      debugPrint('🚨 SupabaseAuthService: Exception type: ${e.runtimeType}');
    }
    debugPrint('🚀 SupabaseAuthService: INITIALIZE METHOD COMPLETED');
  }

  @override
  Future<AuthResult> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      debugPrint('SupabaseAuthService: Signing in user with email: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('SupabaseAuthService: Sign in successful for: $email');
        _currentUser = _convertSupabaseUser(response.user!);

        // 🔧 FIX: UserService will load complete user data from database
        // No need to fetch premium status here - UserService handles complete user loading
        debugPrint(
            'SupabaseAuthService: Skipping database fetch - UserService will load complete user data');

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
      debugPrint(
          'SupabaseAuthService: Using firstName: $firstName, lastName: $lastName');

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
      debugPrint(
          'SupabaseAuthService: User ID: ${response.user?.id ?? 'null'}');
      debugPrint(
          'SupabaseAuthService: Session: ${response.session != null ? 'active' : 'null'}');
      debugPrint(
          'SupabaseAuthService: Email confirmed: ${response.user?.emailConfirmedAt != null ? 'yes' : 'no'}');

      if (response.user != null) {
        _currentUser = _convertSupabaseUser(response.user!);
        debugPrint(
            'SupabaseAuthService: User created successfully: ${_currentUser!.id}');
        debugPrint(
            'SupabaseAuthService: User metadata: ${response.user!.userMetadata}');
        debugPrint(
            'SupabaseAuthService: User app metadata: ${response.user!.appMetadata}');
        debugPrint(
            '=========== SUPABASE AUTH SIGNUP END (SUCCESS) ===========');
        return AuthResult.success(_currentUser!);
      } else {
        debugPrint(
            'SupabaseAuthService: Account creation failed - no user returned');
        debugPrint(
            '=========== SUPABASE AUTH SIGNUP END (FAILURE) ===========');
        return AuthResult.error('Account creation failed');
      }
    } on AuthException catch (e) {
      debugPrint(
          'SupabaseAuthService: Auth exception: ${e.message}, statusCode: ${e.statusCode}');
      debugPrint('SupabaseAuthService: Error details: ${e.toString()}');
      debugPrint(
          '=========== SUPABASE AUTH SIGNUP END (AUTH EXCEPTION) ===========');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      debugPrint('SupabaseAuthService: Unexpected error: $e');
      debugPrint('SupabaseAuthService: Error type: ${e.runtimeType}');
      debugPrint(
          '=========== SUPABASE AUTH SIGNUP END (UNEXPECTED EXCEPTION) ===========');
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

        // 🔧 FIX: UserService will load complete user data from database
        debugPrint(
            'SupabaseAuthService: Skipping premium fetch after Google sign in - UserService will load complete data');

        return AuthResult.success(_currentUser!);
      } else {
        debugPrint(
            'SupabaseAuthService: Google sign in - no session or user found');
        return AuthResult.error('Google sign in failed');
      }
    } on AuthException catch (e) {
      debugPrint(
          'SupabaseAuthService: Google sign in auth exception: ${e.message}');
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
          .update({'is_premium': isPremium}).eq('id', _currentUser!.id);

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
    debugPrint(
        '🚨 SupabaseAuthService._convertSupabaseUser: CALLED - this creates INCOMPLETE User objects!');
    debugPrint(
        '🚨 SupabaseAuthService._convertSupabaseUser: user.id = ${user.id}');
    debugPrint(
        '🚨 SupabaseAuthService._convertSupabaseUser: user.userMetadata = ${user.userMetadata}');

    final userData = user.userMetadata ?? {};

    // Create the user with default premium status
    // 🚨 BUG: This method creates User objects WITHOUT language fields!
    final newUser = app_user.User(
      id: user.id,
      email: user.email ?? '',
      firstName: userData['first_name'] ?? '',
      lastName: userData['last_name'] ?? '',
      createdAt: DateTime.parse(user.createdAt),
      lastLoginAt:
          user.lastSignInAt != null ? DateTime.parse(user.lastSignInAt!) : null,
      profileImageUrl: userData['avatar_url'],
      authProvider: user.appMetadata['provider'] ?? 'email',
      providerId: user.id,
      preferences: app_user.UserPreferences(),
      statistics: app_user.UserStatistics(),
      // Default premium to false, will be updated from database
      isPremium: false,
      // 🚨 MISSING: Language fields! This is why we get null values!
      // targetLanguage: null (defaults to null)
      // nativeLanguage: null (defaults to null)
      // supportLanguage1: null (defaults to null)
      // supportLanguage2: null (defaults to null)
    );

    debugPrint(
        '🚨 SupabaseAuthService._convertSupabaseUser: Created incomplete user - target: "${newUser.targetLanguage}", native: "${newUser.nativeLanguage}"');

    // 🔧 FIX: Removed _fetchAndUpdatePremiumStatus call here to prevent race condition
    // UserService will load complete user data including premium status from database
    debugPrint(
        '🔧 SupabaseAuthService._convertSupabaseUser: Skipping premium fetch - UserService will load complete data');

    return newUser;
  }

  // 🔧 DISABLED: This method was causing race condition corruption
  // UserService loads complete user data including premium status
  Future<void> _fetchAndUpdatePremiumStatus(String userId) async {
    debugPrint(
        '🔧 DISABLED: _fetchAndUpdatePremiumStatus called but disabled to prevent corruption');
    return; // Exit early to prevent corruption
    try {
      debugPrint(
          'SupabaseAuthService: Fetching premium status for user: $userId');

      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('is_premium')
          .eq('id', userId)
          .single();

      final isPremium = response['is_premium'] ?? false;
      debugPrint(
          'SupabaseAuthService: Premium status from database: $isPremium');

      if (_currentUser != null && _currentUser!.id == userId) {
        debugPrint(
            '🚨 CORRUPTION SOURCE: _fetchAndUpdatePremiumStatus about to corrupt user data!');
        debugPrint(
            '🚨   Current user target: "${_currentUser!.targetLanguage}", native: "${_currentUser!.nativeLanguage}"');
        _currentUser = _currentUser!.copyWith(isPremium: isPremium);
        debugPrint(
            '🚨   After copyWith target: "${_currentUser!.targetLanguage}", native: "${_currentUser!.nativeLanguage}"');
        debugPrint(
            'SupabaseAuthService: Updated user premium status to: $isPremium');
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
        debugPrint(
            'SupabaseAuthService: Premium status from service role client: $isPremium');

        if (_currentUser != null && _currentUser!.id == userId) {
          debugPrint(
              '🚨 CORRUPTION SOURCE: _fetchAndUpdatePremiumStatus (service role) about to corrupt user data!');
          debugPrint(
              '🚨   Current user target: "${_currentUser!.targetLanguage}", native: "${_currentUser!.nativeLanguage}"');
          _currentUser = _currentUser!.copyWith(isPremium: isPremium);
          debugPrint(
              '🚨   After copyWith target: "${_currentUser!.targetLanguage}", native: "${_currentUser!.nativeLanguage}"');
          debugPrint(
              'SupabaseAuthService: Updated user premium status to: $isPremium');
        }
      } catch (serviceError) {
        debugPrint(
            'SupabaseAuthService: Error fetching premium status with service role: $serviceError');
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
