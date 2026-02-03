import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pongstrong/firebase/auth.dart';
import 'package:pongstrong/utils/app_logger.dart';

/// Manages the authentication state across the app
class AuthState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthState() {
    // Listen to auth state changes
    _authSubscription = _authService.userState.listen((user) {
      _user = user;
      Logger.debug('Auth state changed: ${user?.uid ?? 'null'}',
          tag: 'AuthState');
      notifyListeners();
    });
    _user = _authService.user;
    Logger.info('AuthState initialized', tag: 'AuthState');
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isEmailUser => _user?.email != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ein unerwarteter Fehler ist aufgetreten';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Create account with email and password
  Future<bool> createAccount(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.createUserWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ein unerwarteter Fehler ist aufgetreten';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      // Sign in anonymously again after logout
      await _authService.signInAnon();
    } catch (e) {
      _error = 'Fehler beim Abmelden';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ein unerwarteter Fehler ist aufgetreten';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    Logger.debug('Disposing AuthState', tag: 'AuthState');
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Get localized error message
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Kein Benutzer mit dieser E-Mail gefunden';
      case 'wrong-password':
        return 'Falsches Passwort';
      case 'invalid-email':
        return 'Ungültige E-Mail-Adresse';
      case 'user-disabled':
        return 'Dieses Konto wurde deaktiviert';
      case 'email-already-in-use':
        return 'Diese E-Mail wird bereits verwendet';
      case 'weak-password':
        return 'Das Passwort ist zu schwach (mindestens 6 Zeichen)';
      case 'invalid-credential':
        return 'Ungültige Anmeldedaten';
      default:
        return 'Ein Fehler ist aufgetreten: $code';
    }
  }
}
