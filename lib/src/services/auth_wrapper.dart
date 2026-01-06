import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// A wrapper class for Firebase Auth to handle the PigeonUserDetails error
class AuthWrapper {
  static final AuthWrapper _instance = AuthWrapper._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Factory constructor
  factory AuthWrapper() {
    return _instance;
  }
  
  // Private constructor
  AuthWrapper._internal();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Login method that avoids PigeonUserDetails error
  Future<UserCredential?> login(String email, String password) async {
    try {
      // Prevent PigeonUserDetails error by not using complicated return types
      print("Starting login for $email");
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print("Login successful, UID: ${credential.user?.uid}");
      return credential;
    } catch (e) {
      // Check if it's the PigeonUserDetails error
      if (e.toString().contains('PigeonUserDetails') && _auth.currentUser != null) {
        // If the error is just the type casting but user is authenticated,
        // we just log it and allow the authentication to proceed
        print('PigeonUserDetails error occurred but authentication succeeded: $e');
        // Return null as we can't access the credential, but auth state will update
        return null;
      } else {
        // For other errors, rethrow as they might be real auth issues
        print('Login error in wrapper: $e');
        rethrow;
      }
    }
  }
  
  // Register method that avoids PigeonUserDetails error
  Future<UserCredential?> register(String email, String password) async {
    try {
      print("Starting registration for $email");
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print("Registration successful, UID: ${credential.user?.uid}");
      return credential;
    } catch (e) {
      // Check if it's the PigeonUserDetails error
      if (e.toString().contains('PigeonUserDetails') && _auth.currentUser != null) {
        // If the error is just the type casting but user is authenticated,
        // we just log it and allow the authentication to proceed
        print('PigeonUserDetails error occurred but registration succeeded: $e');
        // Return null as we can't access the credential, but auth state will update
        return null;
      } else {
        print('Register error in wrapper: $e');
        rethrow;
      }
    }
  }
  
  // Sign out method
  Future<void> signOut() async {
    try {
      print("Signing out user");
      await _auth.signOut();
      print("Sign out complete");
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }
  
  // Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Update display name
  Future<void> updateDisplayName(User user, String displayName) async {
    try {
      print("Updating display name to: $displayName");
      await user.updateDisplayName(displayName);
      print("Display name updated successfully");
    } catch (e) {
      print('Update display name error: $e');
      // Check if it's the PigeonUserInfo error
      if (e.toString().contains('PigeonUserInfo')) {
        // This is a Flutter platform channel issue, not a real error
        // The display name may still be updated on Firebase servers
        print('PigeonUserInfo error occurred but display name update might have succeeded');
        print('This is a known platform channel issue, not a functional error');
      } else {
        rethrow;
      }
    }
  }
} 