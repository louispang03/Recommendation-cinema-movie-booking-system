import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/src/models/booking.dart';
import 'package:fyp_cinema_app/src/models/cancellation_history.dart';
import 'package:fyp_cinema_app/src/models/food_cancellation_history.dart';
import 'package:fyp_cinema_app/src/services/notification_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Getter for Firestore instance
  FirebaseFirestore get firestore => _firestore;

  Future<void> saveBooking(Booking booking) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Create a new document reference to get an auto-generated ID
    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookings')
        .doc();

    // Create the booking with the generated ID
    final bookingWithId = Booking(
      id: docRef.id,
      movieId: booking.movieId,
      movieTitle: booking.movieTitle,
      date: booking.date,
      time: booking.time,
      seats: booking.seats,
      totalPrice: booking.totalPrice,
      bookingDate: booking.bookingDate,
      cinema: booking.cinema,
      status: 'active', // New bookings are always active
    );

    // Save the booking
    await docRef.set(bookingWithId.toMap());
    
    // Schedule notification reminders for the movie
    try {
      await _notificationService.scheduleMultipleReminders(bookingWithId);
      print('✅ Notifications scheduled for booking: ${bookingWithId.id}');
    } catch (e) {
      print('⚠️ Failed to schedule notifications: $e');
      // Don't fail the booking if notification scheduling fails
    }
  }

  Future<List<Booking>> getBookings() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookings')
        .orderBy('bookingDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Booking.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<void> requestCancellation(Booking booking) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Update the booking status to pending cancellation
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookings')
        .doc(booking.id)
        .update({
          'status': 'pending_cancellation',
        });
  }

  Future<void> approveCancellation(Booking booking) async {
    try {
      // Check if the current user is an admin
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) {
        throw Exception('Only admins can approve cancellations');
      }

      // Check if we have the document path
      if (booking.toMap().containsKey('path')) {
        // Use the stored path to directly update the document
        await _firestore.doc(booking.toMap()['path']).update({
          'status': 'cancelled',
        });
      } else {
        // If we don't have the path, fall back to searching through users
        final usersSnapshot = await _firestore.collection('users').get();
        
        // Search through each user's bookings
        for (var userDoc in usersSnapshot.docs) {
          final bookingDoc = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('bookings')
              .doc(booking.id)
              .get();

          if (bookingDoc.exists) {
            // Update the booking status to cancelled
            await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('bookings')
                .doc(booking.id)
                .update({
                  'status': 'cancelled',
                });
            break;
          }
        }
      }
      
      // Cancel the scheduled notifications
      try {
        await _notificationService.cancelMovieReminder(booking.id);
        print('✅ Notifications cancelled for booking: ${booking.id}');
      } catch (e) {
        print('⚠️ Failed to cancel notifications: $e');
        // Don't fail the cancellation if notification cancellation fails
      }
    } catch (e) {
      print('Error approving cancellation: $e');
      rethrow;
    }
  }

  Future<void> rejectCancellation(Booking booking) async {
    try {
      // Check if the current user is an admin
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) {
        throw Exception('Only admins can reject cancellations');
      }

      // Check if we have the document path
      if (booking.toMap().containsKey('path')) {
        // Use the stored path to directly update the document
        await _firestore.doc(booking.toMap()['path']).update({
          'status': 'active',
        });
        return;
      }
      
      // If we don't have the path, fall back to searching through users
      final usersSnapshot = await _firestore.collection('users').get();
      
      // Search through each user's bookings
      for (var userDoc in usersSnapshot.docs) {
        final bookingDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('bookings')
            .doc(booking.id)
            .get();

        if (bookingDoc.exists) {
          // Update the booking status back to active
          await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('bookings')
              .doc(booking.id)
              .update({
                'status': 'active',
              });
          return;
        }
      }
      
      throw Exception('Booking not found');
    } catch (e) {
      print('Error rejecting cancellation: $e');
      rethrow;
    }
  }

  Future<List<Booking>> getPendingCancellations() async {
    final snapshot = await _firestore
        .collectionGroup('bookings')
        .where('status', isEqualTo: 'pending_cancellation')
        .get();

    return snapshot.docs
        .map((doc) => Booking.fromMap({
              ...doc.data(), 
              'id': doc.id,
              'path': doc.reference.path, // Store the document path for later use
            }))
        .toList();
  }

  Future<void> logCancellationHistory(CancellationHistory history) async {
    try {
      print('📝 Logging cancellation history for booking: ${history.bookingId}');
      print('📄 History ID: ${history.id}');
      print('🎬 Movie: ${history.movieTitle}');
      print('👤 User: ${history.userName}');
      print('✅❌ Decision: ${history.systemDecision}');
      
      final data = history.toMap();
      print('📦 Data to save: ${data.keys.join(', ')}');
      
      // Try to save to cancellation_history collection first
      try {
        await _firestore
            .collection('cancellation_history')
            .doc(history.id)
            .set(data);
        print('✅ Cancellation history logged successfully: ${history.id}');
      } catch (permissionError) {
        print('⚠️ Permission denied for cancellation_history, trying fallback...');
        
        // Fallback: Save to admin collection with a subcollection
        // First ensure the system admin document exists
        await _firestore
            .collection('admins')
            .doc('system')
            .set({
              'role': 'system',
              'createdAt': DateTime.now().toIso8601String(),
              'description': 'System admin for cancellation history storage'
            }, SetOptions(merge: true));
            
        await _firestore
            .collection('admins')
            .doc('system')
            .collection('cancellation_history')
            .doc(history.id)
            .set(data);
        print('✅ Cancellation history logged to admin/system/cancellation_history: ${history.id}');
      }
    } catch (e) {
      print('❌ Failed to log cancellation history: $e');
      print('📄 History object: ${history.toMap()}');
      // Don't fail the cancellation process if logging fails
    }
  }

  Future<List<CancellationHistory>> getCancellationHistory({
    String? movieFilter,
    String? dateFilter,
    String? statusFilter,
  }) async {
    try {
      print('🔍 Querying cancellation history from multiple sources...');
      List<CancellationHistory> histories = [];
      
      // Try to get from main cancellation_history collection first
      try {
        print('📦 Trying main cancellation_history collection...');
        Query query = _firestore.collection('cancellation_history');

        // Apply filters if provided
        if (statusFilter != null && statusFilter.isNotEmpty) {
          print('📋 Filtering by status: $statusFilter');
          query = query.where('systemDecision', isEqualTo: statusFilter);
        }

        final snapshot = await query.get();
        print('📦 Found ${snapshot.docs.length} documents in cancellation_history');

        histories.addAll(snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          print('📄 Document ${doc.id}: ${data.keys.join(', ')}');
          return CancellationHistory.fromMap({
            ...data,
            'id': doc.id,
          });
        }));
      } catch (permissionError) {
        print('⚠️ Permission denied for main collection, trying fallback...');
        
        // Fallback: Try to get from admin/system/cancellation_history
        try {
          print('📦 Trying admin/system/cancellation_history fallback...');
          Query fallbackQuery = _firestore
              .collection('admins')
              .doc('system')
              .collection('cancellation_history');

          if (statusFilter != null && statusFilter.isNotEmpty) {
            fallbackQuery = fallbackQuery.where('systemDecision', isEqualTo: statusFilter);
          }

          final fallbackSnapshot = await fallbackQuery.get();
          print('📦 Found ${fallbackSnapshot.docs.length} documents in fallback location');

          histories.addAll(fallbackSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return CancellationHistory.fromMap({
              ...data,
              'id': doc.id,
            });
          }));
        } catch (fallbackError) {
          print('❌ Fallback also failed: $fallbackError');
        }
      }

      print('📊 Total parsed ${histories.length} cancellation history objects');

      // Apply client-side filters for movie and date
      if (movieFilter != null && movieFilter.isNotEmpty) {
        print('🎬 Filtering by movie: $movieFilter');
        histories = histories.where((h) => 
          h.movieTitle.toLowerCase().contains(movieFilter.toLowerCase())).toList();
      }

      if (dateFilter != null && dateFilter.isNotEmpty) {
        print('📅 Filtering by date: $dateFilter');
        histories = histories.where((h) => h.showDate.contains(dateFilter)).toList();
      }

      // Sort by processed time (newest first)
      histories.sort((a, b) => b.processedTime.compareTo(a.processedTime));

      print('✅ Returning ${histories.length} filtered and sorted records');
      return histories;
    } catch (e) {
      print('❌ Error getting cancellation history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'name': data['name'] ?? 'Unknown User',
          'email': data['email'] ?? 'No email',
        };
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
    return {
      'name': 'Unknown User',
      'email': 'No email',
    };
  }

  String _extractUserIdFromPath(String path) {
    // Path format: users/{userId}/bookings/{bookingId}
    final parts = path.split('/');
    if (parts.length >= 2) {
      return parts[1];
    }
    return '';
  }

  Future<DateTime?> getCancellationRequestTime(String bookingPath) async {
    try {
      // This would need to be implemented based on when the user requested cancellation
      // For now, we'll estimate it as a recent time before processing
      return DateTime.now().subtract(const Duration(minutes: 5));
    } catch (e) {
      print('Error getting cancellation request time: $e');
      return DateTime.now().subtract(const Duration(minutes: 5));
    }
  }

  // Test method to create sample cancellation history (for debugging)
  Future<void> createTestCancellationHistory() async {
    try {
      final testHistory = CancellationHistory(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        bookingId: 'test_booking_123',
        movieTitle: 'Test Movie',
        movieId: 'test_movie_id',
        showDate: 'Sat, 14 Dec',
        showTime: '7:30 PM',
        cinema: 'GSC',
        seats: ['A1', 'A2'],
        totalPrice: 24.00,
        userId: 'test_user_id',
        userName: 'Test User',
        userEmail: 'test@example.com',
        cancellationRequestTime: DateTime.now().subtract(const Duration(minutes: 10)),
        processedTime: DateTime.now(),
        systemDecision: 'auto_approved',
        reason: 'before_30_minutes',
        refundProcessed: true,
        refundAmount: 24.00,
      );
      
      await logCancellationHistory(testHistory);
      print('✅ Test cancellation history created');
    } catch (e) {
      print('❌ Error creating test data: $e');
    }
  }

  // Food Order Cancellation Methods
  Future<void> requestFoodCancellation(String orderId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Update the food order status to pending cancellation
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('food_orders')
          .doc(orderId)
          .update({
            'status': 'pending_cancellation',
          });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingFoodCancellations() async {
    try {
      // First try collection group query (requires index)
      try {
        final snapshot = await _firestore
            .collectionGroup('food_orders')
            .where('status', isEqualTo: 'pending_cancellation')
            .get();

        final results = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            ...data,
            'docId': doc.id,
            'path': doc.reference.path,
          };
        }).toList();
        
        return results;
      } catch (indexError) {
        // Fallback: Get all users and check their food orders
        return await _getPendingFoodCancellationsFallback();
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingFoodCancellationsFallback() async {
    try {
      List<Map<String, dynamic>> pendingCancellations = [];
      
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          // Check each user's food orders
          final foodOrdersSnapshot = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('food_orders')
              .where('status', isEqualTo: 'pending_cancellation')
              .get();
          
          for (final orderDoc in foodOrdersSnapshot.docs) {
            final data = orderDoc.data();
            pendingCancellations.add({
              ...data,
              'docId': orderDoc.id,
              'path': orderDoc.reference.path,
            });
          }
        } catch (e) {
          // Continue checking other users if one fails
          continue;
        }
      }
      
      return pendingCancellations;
    } catch (e) {
      return [];
    }
  }

  Future<void> approveFoodCancellation(Map<String, dynamic> foodOrder) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Update the food order status to cancelled
      await _firestore.doc(foodOrder['path']).update({
        'status': 'cancelled',
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectFoodCancellation(Map<String, dynamic> foodOrder) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Update the food order status back to completed
      await _firestore.doc(foodOrder['path']).update({
        'status': 'completed',
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logFoodCancellationHistory(FoodCancellationHistory history) async {
    try {
      final data = history.toMap();
      
      // Try to save to food_cancellation_history collection first
      try {
        await _firestore
            .collection('food_cancellation_history')
            .doc(history.id)
            .set(data);
      } catch (permissionError) {
        // Fallback: Save to admin collection with a subcollection
        await _firestore
            .collection('admins')
            .doc('system')
            .set({
              'role': 'system',
              'createdAt': DateTime.now().toIso8601String(),
              'description': 'System admin for cancellation history storage'
            }, SetOptions(merge: true));
            
        await _firestore
            .collection('admins')
            .doc('system')
            .collection('food_cancellation_history')
            .doc(history.id)
            .set(data);
      }
    } catch (e) {
      // Silent fail for logging
    }
  }

  Future<List<FoodCancellationHistory>> getFoodCancellationHistory() async {
    try {
      List<FoodCancellationHistory> histories = [];
      
      // Try to get from main food_cancellation_history collection first
      try {
        final snapshot = await _firestore.collection('food_cancellation_history').get();

        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final history = FoodCancellationHistory.fromMap({
              ...data,
              'id': doc.id,
            });
            histories.add(history);
          } catch (e) {
            // Skip invalid documents
            continue;
          }
        }
      } catch (permissionError) {
        // Fallback: Try to get from admin/system/food_cancellation_history
        try {
          final fallbackSnapshot = await _firestore
              .collection('admins')
              .doc('system')
              .collection('food_cancellation_history')
              .get();

          for (final doc in fallbackSnapshot.docs) {
            try {
              final data = doc.data();
              final history = FoodCancellationHistory.fromMap({
                ...data,
                'id': doc.id,
              });
              histories.add(history);
            } catch (e) {
              // Skip invalid documents
              continue;
            }
          }
        } catch (fallbackError) {
          // Both sources failed, return empty list
          return [];
        }
      }

      // Sort by processed time (newest first)
      if (histories.isNotEmpty) {
        histories.sort((a, b) => b.processedTime.compareTo(a.processedTime));
      }

      return histories;
    } catch (e) {
      return [];
    }
  }

} 