import '../models/user.dart';

/// Authentication result class
class AuthResult {
  final User? user;
  final String? error;
  final bool success;

  AuthResult({this.user, this.error, this.success = false});

  factory AuthResult.success(User user) => AuthResult(user: user, success: true);
  factory AuthResult.error(String error) => AuthResult(error: error, success: false);
}

/// Abstract authentication service interface
abstract class AuthService {
  // Current user
  User? get currentUser;
  Stream<User?> get authStateChanges;

  // Email/Password authentication
  Future<AuthResult> signInWithEmailAndPassword(String email, String password);
  Future<AuthResult> createUserWithEmailAndPassword(String email, String password, String firstName, String lastName);
  Future<void> signOut();

  // OAuth authentication
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> signInWithApple();

  // Password management
  Future<void> sendPasswordResetEmail(String email);
  Future<void> updatePassword(String newPassword);

  // User management
  Future<void> updateUserProfile({String? firstName, String? lastName, String? profileImageUrl});
  Future<void> deleteAccount();

  // Premium status
  Future<bool> isPremiumUser();
  Future<void> updatePremiumStatus(bool isPremium);

  // Initialization and cleanup
  Future<void> initialize();
  Future<void> cleanup();
} 