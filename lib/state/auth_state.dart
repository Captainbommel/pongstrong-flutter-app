import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pongstrong/services/auth_service.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/utils/app_logger.dart';

/// Manages the authentication state across the app
class AuthState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _isLoading = false;
  String? _error;

  // Tournament role tracking
  String? _currentTournamentId;
  bool _isAdmin = false;
  bool _isParticipant = false;

  AuthState() {
    // Listen to auth state changes
    _authSubscription = _authService.userState.listen((user) {
      _user = user;
      Logger.debug('Auth state changed: ${user?.uid ?? 'null'}',
          tag: 'AuthState');
      // Re-check tournament role when auth changes (e.g. after logout/login)
      if (_currentTournamentId != null) {
        checkTournamentRole(_currentTournamentId!);
      }
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

  /// Whether the current user is the admin (creator) of the current tournament
  bool get isAdmin => _isAdmin;

  /// Whether the current user is a participant of the current tournament
  bool get isParticipant => _isParticipant;

  /// Check the user's role for a given tournament and cache it
  Future<void> checkTournamentRole(String tournamentId) async {
    _currentTournamentId = tournamentId;
    final uid = _user?.uid;
    if (uid == null) {
      _isAdmin = false;
      _isParticipant = false;
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _firestoreService.isCreator(tournamentId, uid),
        _firestoreService.isParticipant(tournamentId, uid),
      ]);
      _isAdmin = results[0];
      _isParticipant = results[1];
      Logger.debug(
          'Tournament role for $tournamentId: admin=$_isAdmin, participant=$_isParticipant',
          tag: 'AuthState');
    } catch (e) {
      Logger.error('Error checking tournament role',
          tag: 'AuthState', error: e);
      _isAdmin = false;
      _isParticipant = false;
    }
    notifyListeners();
  }

  /// Mark the current user as a participant (after successful password entry)
  void markAsParticipant() {
    _isParticipant = true;
    notifyListeners();
  }

  /// Clear tournament role (when leaving a tournament)
  void clearTournamentRole() {
    _currentTournamentId = null;
    _isAdmin = false;
    _isParticipant = false;
    notifyListeners();
  }

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
