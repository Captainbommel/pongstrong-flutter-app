import 'package:firebase_auth/firebase_auth.dart';
import 'package:pongstrong/utils/app_logger.dart';

/// AuthService handles Firebase authentication.
/// Uses singleton pattern to ensure single instance across the app.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    Logger.info('AuthService singleton initialized', tag: 'AuthService');
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The currently signed-in Firebase user, or `null`.
  User? get user {
    return _auth.currentUser;
  }

  /// Get the current user's UID
  String? get userId {
    return _auth.currentUser?.uid;
  }

  /// Get the current user's email
  String? get userEmail {
    return _auth.currentUser?.email;
  }

  /// Check if user is logged in with email (not anonymous)
  bool get isEmailUser {
    return _auth.currentUser?.email != null;
  }

  /// stream for listening to user changes
  Stream<User?> get userState {
    return _auth.authStateChanges();
  }

  /// Creates an anonymous User and signs them in.
  Future<User?> signInAnon() async {
    try {
      Logger.debug('Signing in anonymously...', tag: 'AuthService');
      final UserCredential userCredential = await _auth.signInAnonymously();
      Logger.info('Anonymous sign-in successful: ${userCredential.user?.uid}',
          tag: 'AuthService');
      return userCredential.user;
    } catch (error) {
      Logger.error('Anonymous sign-in failed',
          tag: 'AuthService', error: error);
      return Future.error(error);
    }
  }

  /// Signs in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      Logger.debug('Signing in with email: $email', tag: 'AuthService');
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Logger.info('Email sign-in successful: ${userCredential.user?.uid}',
          tag: 'AuthService');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      Logger.warning('Firebase Auth Error: ${e.code}',
          tag: 'AuthService', error: e);
      rethrow;
    } catch (error) {
      Logger.error('Sign-in failed', tag: 'AuthService', error: error);
      return Future.error(error);
    }
  }

  /// Creates a new user with email and password
  Future<User?> createUserWithEmail(String email, String password) async {
    try {
      Logger.debug('Creating user with email: $email', tag: 'AuthService');
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      Logger.info('User created successfully: ${userCredential.user?.uid}',
          tag: 'AuthService');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      Logger.warning('Firebase Auth Error: ${e.code}',
          tag: 'AuthService', error: e);
      rethrow;
    } catch (error) {
      Logger.error('User creation failed', tag: 'AuthService', error: error);
      return Future.error(error);
    }
  }

  /// Signs the current user out. Might complete with error.
  Future signOut() async {
    try {
      Logger.debug('Signing out user', tag: 'AuthService');
      await _auth.signOut();
      Logger.info('Sign-out successful', tag: 'AuthService');
    } catch (error) {
      Logger.error('Sign-out failed', tag: 'AuthService', error: error);
      return Future.error(error);
    }
  }

  /// Sends a password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      Logger.debug('Sending password reset email to: $email',
          tag: 'AuthService');
      await _auth.sendPasswordResetEmail(email: email);
      Logger.info('Password reset email sent', tag: 'AuthService');
    } catch (error) {
      Logger.error('Password reset email failed',
          tag: 'AuthService', error: error);
      return Future.error(error);
    }
  }
}
