import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// AuthService handles Firebase authentication.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (error) {
      debugPrint(error.toString());
      return Future.error(error);
    }
  }

  /// Signs in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (error) {
      debugPrint(error.toString());
      return Future.error(error);
    }
  }

  /// Creates a new user with email and password
  Future<User?> createUserWithEmail(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (error) {
      debugPrint(error.toString());
      return Future.error(error);
    }
  }

  /// Signs the current user out. Might complete with error.
  Future signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      debugPrint(error.toString());
      return Future.error(error);
    }
  }

  /// Sends a password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (error) {
      debugPrint(error.toString());
      return Future.error(error);
    }
  }

  //! use this to save the chosen Team of a user
  //! team will be null wihle not chosen
  //! upon login the user will be prompted to choose a team
  /// Sets the displayname of the current user, representing the chosen team.
  void setTeam(String team) async {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(team);
      debugPrint('updated user team to $team');
    } else {
      debugPrint('no user logged in');
    }
  }
}
