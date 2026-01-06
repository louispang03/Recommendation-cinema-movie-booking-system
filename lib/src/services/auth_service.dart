import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/model/admin/admin.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is admin
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get admin details with robust error handling
  Future<Admin?> getAdminDetails(String uid) async {
    try {
      print('🔍 Fetching admin details for UID: $uid');
      final doc = await _firestore.collection('admins').doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        print('📄 Admin document found, processing data...');
        
        try {
          // Convert Timestamp to ISO8601 string if present
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          
          // Create Admin object with error handling
          final admin = Admin.fromJson(data);
          print('✅ Admin details parsed successfully for $uid');
          return admin;
        } catch (parseError) {
          print('❌ Error parsing admin data for $uid: $parseError');
          print('📄 Raw admin data: $data');
          
          // Try to create a minimal admin object with available data
          try {
            final minimalAdmin = Admin(
              id: uid,
              email: data['email']?.toString() ?? 'admin@cinema.com',
              username: data['username']?.toString() ?? data['name']?.toString() ?? 'Admin User',
              role: data['role']?.toString() ?? 'admin',
              createdAt: data['createdAt'] is String 
                  ? DateTime.parse(data['createdAt'])
                  : DateTime.now(),
            );
            print('🔄 Created minimal admin object for $uid');
            return minimalAdmin;
          } catch (minimalError) {
            print('❌ Failed to create minimal admin object: $minimalError');
            return null;
          }
        }
      } else {
        print('⚠️ No admin document found for UID: $uid');
        return null;
      }
    } catch (e) {
      print('❌ Error getting admin details for $uid: $e');
      
      // Handle specific Firebase errors
      if (e.toString().contains('PERMISSION_DENIED')) {
        print('🔒 Permission denied accessing admin collection');
      } else if (e.toString().contains('UNAVAILABLE')) {
        print('🌐 Firebase service unavailable');
      } else if (e.toString().contains('PigeonUserDetails') || 
                 e.toString().contains('type cast')) {
        print('🔄 PigeonUserDetails parsing error detected');
      }
      
      return null;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Directly attempt to sign in without checking email existence first
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      print('Unknown error during sign in: $e');
      throw 'An unexpected error occurred. Please try again later.';
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear conversation IDs before signing out
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('🔄 User ${currentUser.uid} signing out - conversation IDs will be cleared on next login');
        
        // Clear any cached user data if needed
        // This ensures clean state for the next user
      }
      
      // Perform the actual sign out
      await _auth.signOut();
      print('✅ Sign out completed successfully');
      
      // Force a small delay to ensure auth state is properly updated
      await Future.delayed(Duration(milliseconds: 100));
      
    } catch (e) {
      print('❌ Error during sign out: $e');
      // Still try to sign out even if cleanup fails
      await _auth.signOut();
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email & Password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'user-disabled':
        return 'This user has been disabled.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
} 