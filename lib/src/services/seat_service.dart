import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/models/booking.dart';

class SeatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _seatsCollection = 'seats';

  Future<bool> isSeatAvailable(String movieId, String date, String time, String cinema, String seat) async {
    try {
      print('Checking seat availability for:');
      print('Movie ID: $movieId');
      print('Date: $date');
      print('Time: $time');
      print('Cinema: $cinema');
      print('Seat: $seat');

      final docId = '${movieId}_${date}_${time}_${cinema}';
      print('Document ID: $docId');

      final doc = await _firestore
          .collection(_seatsCollection)
          .doc(docId)
          .get();

      if (!doc.exists) {
        print('Document does not exist, seat is available');
        return true;
      }

      final data = doc.data();
      if (data == null) {
        print('Document exists but has no data, seat is available');
        return true;
      }

      final bookedSeats = List<String>.from(data['bookedSeats'] ?? []);
      final bookingTimes = Map<String, dynamic>.from(data['bookingTimes'] ?? {});

      print('Booked seats: $bookedSeats');
      print('Booking times: $bookingTimes');

      // If seat is not in bookedSeats, it's available
      if (!bookedSeats.contains(seat)) {
        print('Seat $seat is not in booked seats, it is available');
        return true;
      }

      // If seat is booked, check if the movie has ended
      final bookingTime = DateTime.parse(bookingTimes[seat]);
      final movieEndTime = bookingTime.add(const Duration(hours: 2)); // Assuming 2 hours movie duration
      
      print('Booking time: $bookingTime');
      print('Movie end time: $movieEndTime');
      print('Current time: ${DateTime.now()}');

      // Seat is available if the movie has ended
      final isAvailable = DateTime.now().isAfter(movieEndTime);
      print('Seat $seat availability: $isAvailable');
      
      return isAvailable;
    } catch (e) {
      print('Error checking seat availability: $e');
      return false;
    }
  }

  Future<void> bookSeats(String movieId, String date, String time, String cinema, List<String> seats) async {
    try {
      final docRef = _firestore
          .collection(_seatsCollection)
          .doc('${movieId}_${date}_${time}_${cinema}');

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        final now = DateTime.now();

        if (!doc.exists) {
          // Create new document
          transaction.set(docRef, {
            'bookedSeats': seats,
            'bookingTimes': seats.fold<Map<String, String>>(
              {},
              (map, seat) => {...map, seat: now.toIso8601String()},
            ),
          });
        } else {
          // Update existing document
          final data = doc.data()!;
          final bookedSeats = List<String>.from(data['bookedSeats'] ?? []);
          final bookingTimes = Map<String, dynamic>.from(data['bookingTimes'] ?? {});

          // Add new seats
          transaction.update(docRef, {
            'bookedSeats': [...bookedSeats, ...seats],
            'bookingTimes': {
              ...bookingTimes,
              ...seats.fold<Map<String, String>>(
                {},
                (map, seat) => {...map, seat: now.toIso8601String()},
              ),
            },
          });
        }
      });
    } catch (e) {
      print('Error booking seats: $e');
      rethrow;
    }
  }

  Future<List<String>> getBookedSeats(String movieId, String date, String time, String cinema) async {
    try {
      final doc = await _firestore
          .collection(_seatsCollection)
          .doc('${movieId}_${date}_${time}_${cinema}')
          .get();

      if (!doc.exists) {
        return [];
      }

      final data = doc.data()!;
      final bookedSeats = List<String>.from(data['bookedSeats'] ?? []);
      final bookingTimes = Map<String, dynamic>.from(data['bookingTimes'] ?? {});

      // Filter out seats where movie has ended
      return bookedSeats.where((seat) {
        final bookingTime = DateTime.parse(bookingTimes[seat]);
        final movieEndTime = bookingTime.add(const Duration(hours: 2)); // Assuming 2 hours movie duration
        return !DateTime.now().isAfter(movieEndTime);
      }).toList();
    } catch (e) {
      print('Error getting booked seats: $e');
      return [];
    }
  }

  Future<void> releaseSeats(String movieId, String date, String time, String cinema, List<String> seats) async {
    try {
      final docRef = _firestore
          .collection(_seatsCollection)
          .doc('${movieId}_${date}_${time}_${cinema}');

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;

        final data = doc.data()!;
        final bookedSeats = List<String>.from(data['bookedSeats'] ?? []);
        final bookingTimes = Map<String, dynamic>.from(data['bookingTimes'] ?? {});

        // Remove the seats from bookedSeats
        final updatedBookedSeats = bookedSeats.where((seat) => !seats.contains(seat)).toList();
        
        // Remove the seats from bookingTimes
        final updatedBookingTimes = Map<String, dynamic>.from(bookingTimes);
        for (var seat in seats) {
          updatedBookingTimes.remove(seat);
        }

        // Update the document
        transaction.update(docRef, {
          'bookedSeats': updatedBookedSeats,
          'bookingTimes': updatedBookingTimes,
        });
      });
    } catch (e) {
      print('Error releasing seats: $e');
      rethrow;
    }
  }
} 