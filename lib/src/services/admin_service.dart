import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/model/admin/admin.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';
import 'package:fyp_cinema_app/src/services/notification_service.dart';

class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final String adminCollection = 'admins';
  final String movieCollection = 'movies';

  // Getter for Firestore instance
  FirebaseFirestore get firestore => _firestore;

  // Movie Management
  Future<void> addMovie(BannerMovie movie) async {
    try {
      await _firestore.collection(movieCollection).doc(movie.id.toString()).set(movie.toJson());
      
      // Send notification to all users about the new coming soon movie
      await _notificationService.broadcastSystemNotification(
        title: '🎬 New Movie Coming Soon!',
        message: '${movie.title} has been added to our upcoming releases. Check it out now!',
        details: 'Release Date: ${movie.releaseDate}\n\n${movie.overview ?? 'Get ready for an amazing cinematic experience!'}',
        additionalData: {
          'type': 'new_movie',
          'movieId': movie.id.toString(),
          'movieTitle': movie.title,
          'releaseDate': movie.releaseDate,
        },
      );
      
      print('✅ Movie added and notification sent: ${movie.title}');
    } catch (e) {
      print('Error adding movie: $e');
      rethrow;
    }
  }

  Future<void> updateMovie(BannerMovie movie) async {
    try {
      await _firestore.collection(movieCollection).doc(movie.id.toString()).update(movie.toJson());
    } catch (e) {
      print('Error updating movie: $e');
      rethrow;
    }
  }

  Future<void> deleteMovie(String movieId) async {
    try {
      await _firestore.collection(movieCollection).doc(movieId).delete();
    } catch (e) {
      print('Error deleting movie: $e');
      rethrow;
    }
  }

  Future<List<BannerMovie>> getAllMovies() async {
    try {
      final snapshot = await _firestore.collection(movieCollection).get();
      return snapshot.docs
          .map((doc) => BannerMovie.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting movies: $e');
      return [];
    }
  }

  // Check if user is admin
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _firestore.collection(adminCollection).doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking admin status: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        print('Permission denied when checking admin status. Check Firestore rules.');
        print('Security rules should allow any authenticated user to read from admins collection.');
      }
      return false;
    }
  }

  // Get admin details
  Future<Admin?> getAdminDetails(String uid) async {
    try {
      final doc = await _firestore.collection(adminCollection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Convert Timestamp to ISO8601 string
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return Admin.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting admin details: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        print('Permission denied when getting admin details. Check Firestore rules.');
        print('Security rules should allow any authenticated user to read from admins collection.');
      }
      return null;
    }
  }

  // Get count of pending cancellation requests
  Future<int> getPendingCancellationCount() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('bookings')
          .where('status', isEqualTo: 'pending_cancellation')
          .get();
      return snapshot.docs.length;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        print('Index not created yet. Please create the required index in Firebase Console.');
        print('Index details: Collection Group: bookings, Field: status (Ascending)');
        return 0; // Return 0 while waiting for index creation
      }
      print('Error getting pending cancellation count: $e');
      return 0;
    } catch (e) {
      print('Error getting pending cancellation count: $e');
      return 0;
    }
  }
} 