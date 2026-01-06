import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/models/booking.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_cinema_app/src/services/booking_service.dart';
import 'package:fyp_cinema_app/src/services/seat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingHistoryScreen extends StatefulWidget {
  final List<Booking> bookings;

  const BookingHistoryScreen({
    super.key,
    required this.bookings,
  });

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final BookingService _bookingService = BookingService();
  final SeatService _seatService = SeatService();
  late List<Booking> _movieBookings;
  List<Map<String, dynamic>> _foodOrders = [];
  int _selectedIndex = 0; // 0 for movies, 1 for food
  bool _isLoadingFoodOrders = true;

  @override
  void initState() {
    super.initState();
    _movieBookings = _filterRecentBookings(widget.bookings);
    _loadFoodOrders();
    _cleanupOldBookings(); // Clean up old bookings on screen load
  }

  /// Filters bookings to show only those from the last month
  List<Booking> _filterRecentBookings(List<Booking> bookings) {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    return bookings.where((booking) {
      return booking.bookingDate.isAfter(oneMonthAgo);
    }).toList();
  }

  /// Checks if a movie has ended and updates the booking status accordingly
  Booking _updateBookingStatus(Booking booking) {
    if (booking.status != 'active') return booking; // Only update active bookings
    
    final showtime = _parseShowtime(booking.date, booking.time);
    final now = DateTime.now();
    
    // Consider movie ended if showtime was more than 3 hours ago (typical movie length)
    if (showtime != null && now.difference(showtime).inHours >= 3) {
      return Booking(
        id: booking.id,
        movieId: booking.movieId,
        movieTitle: booking.movieTitle,
        date: booking.date,
        time: booking.time,
        seats: booking.seats,
        totalPrice: booking.totalPrice,
        bookingDate: booking.bookingDate,
        cinema: booking.cinema,
        isPaid: booking.isPaid,
        status: 'completed', // Mark as completed after movie ends
      );
    }
    
    return booking;
  }

  /// Parses the showtime from date and time strings
  DateTime? _parseShowtime(String dateStr, String timeStr) {
    try {
      // Parse date (format: "Monday, 15 Jan")
      final dateParts = dateStr.split(', ');
      final day = int.parse(dateParts[1].split(' ')[0]);
      final month = _getMonthNumber(dateParts[1].split(' ')[1]);
      final year = DateTime.now().year; // Assuming current year
      
      // Parse time (format: "2:30 PM")
      final timeParts = timeStr.split(' ');
      final hourMinute = timeParts[0].split(':');
      final hour = int.parse(hourMinute[0]);
      final minute = int.parse(hourMinute[1]);
      final isPM = timeParts[1] == 'PM' && hour != 12;
      
      return DateTime(year, month, day, isPM ? hour + 12 : hour, minute);
    } catch (e) {
      print('Error parsing showtime: $e');
      return null;
    }
  }

  /// Cleans up old bookings (older than one month) from the database
  Future<void> _cleanupOldBookings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      
      // Get all bookings older than one month
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .where('bookingDate', isLessThan: Timestamp.fromDate(oneMonthAgo))
          .get();
      
      // Delete old bookings
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      if (querySnapshot.docs.isNotEmpty) {
        await batch.commit();
        print('Cleaned up ${querySnapshot.docs.length} old bookings');
      }
    } catch (e) {
      print('Error cleaning up old bookings: $e');
    }
  }

  Future<void> _loadFoodOrders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // Load food orders from user's subcollection: users/{userId}/food_orders
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('food_orders')
          .orderBy('orderDate', descending: true)
          .get();

      setState(() {
        _foodOrders = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'orderDate': (data['orderDate'] as Timestamp).toDate(),
            'estimatedPickupTime': (data['estimatedPickupTime'] as Timestamp).toDate(),
          };
        }).toList();
        _isLoadingFoodOrders = false;
      });
    } catch (e) {
      print('Error loading food orders: $e');
      setState(() {
        _isLoadingFoodOrders = false;
      });
    }
  }

  bool _isCancellable(Booking booking) {
    // Parse the date and time from the booking
    final dateParts = booking.date.split(', ');
    final day = int.parse(dateParts[1].split(' ')[0]);
    final month = _getMonthNumber(dateParts[1].split(' ')[1]);
    final year = DateTime.now().year; // Assuming current year
    
    final timeParts = booking.time.split(' ');
    final hourMinute = timeParts[0].split(':');
    final hour = int.parse(hourMinute[0]);
    final minute = int.parse(hourMinute[1]);
    final isPM = timeParts[1] == 'PM' && hour != 12;
    
    final showtime = DateTime(year, month, day, isPM ? hour + 12 : hour, minute);
    final now = DateTime.now();
    
    // Check if the showtime is more than 1 hour away
    return showtime.difference(now).inHours >= 1;
  }

  int _getMonthNumber(String month) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };
    return months[month] ?? 1;
  }

  bool _isFoodOrderCancellable(Map<String, dynamic> order) {
    try {
      // Only allow cancellation if order is completed (not already cancelled or pending)
      if (order['status'] != 'completed') return false;
      
      final pickupTime = order['estimatedPickupTime'] as DateTime;
      final now = DateTime.now();
      
      // Check if the pickup time is more than 30 minutes away
      return pickupTime.difference(now).inMinutes >= 30;
    } catch (e) {
      print('Error checking food order cancellability: $e');
      return false;
    }
  }

  Future<void> _cancelFoodOrder(Map<String, dynamic> order) async {
    try {
      // Request cancellation
      await _bookingService.requestFoodCancellation(order['id']);

      // Update the local state
      setState(() {
        final index = _foodOrders.indexWhere((o) => o['id'] == order['id']);
        if (index != -1) {
          _foodOrders[index]['status'] = 'pending_cancellation';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food order cancellation requested. Processing automatically...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Reload food orders to show updated status
      await _loadFoodOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting food cancellation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    try {
      // Request cancellation instead of deleting
      await _bookingService.requestCancellation(booking);

      // Update the local state
      setState(() {
        final index = _movieBookings.indexWhere((b) => b.id == booking.id);
        if (index != -1) {
          _movieBookings[index] = Booking(
            id: booking.id,
            movieId: booking.movieId,
            movieTitle: booking.movieTitle,
            date: booking.date,
            time: booking.time,
            seats: booking.seats,
            totalPrice: booking.totalPrice,
            bookingDate: booking.bookingDate,
            cinema: booking.cinema,
            isPaid: booking.isPaid,
            status: 'pending_cancellation',
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancellation requested. Waiting for admin approval.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting cancellation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQRCode(BuildContext context, Booking booking) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Show this QR code at the cinema counter',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: booking.getQRData(),
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 16),
              Text(
                booking.isPaid ? 'PAID' : 'UNPAID',
                style: TextStyle(
                  color: booking.isPaid ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'active':
        color = Colors.green;
        text = 'ACTIVE';
        break;
      case 'completed':
        color = Colors.blue;
        text = 'COMPLETED';
        break;
      case 'pending_cancellation':
        color = Colors.orange;
        text = 'PENDING CANCELLATION';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: ColorApp.primaryDarkColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (_selectedIndex == 0) {
                // Refresh movie bookings and clean up old ones
                await _cleanupOldBookings();
                setState(() {
                  _movieBookings = _filterRecentBookings(widget.bookings);
                });
              } else {
                _loadFoodOrders();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab buttons
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 0 ? ColorApp.primaryDarkColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie,
                            color: _selectedIndex == 0 ? Colors.white : Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Movies (${_movieBookings.length})',
                            style: TextStyle(
                              color: _selectedIndex == 0 ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      _loadFoodOrders(); // Refresh food orders when switching to food tab
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 1 ? ColorApp.primaryDarkColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant,
                            color: _selectedIndex == 1 ? Colors.white : Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Food (${_foodOrders.length})',
                            style: TextStyle(
                              color: _selectedIndex == 1 ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (_selectedIndex == 0) {
                  // Refresh movie bookings and clean up old ones
                  await _cleanupOldBookings();
                  setState(() {
                    _movieBookings = _filterRecentBookings(widget.bookings);
                  });
                } else {
                  await _loadFoodOrders();
                }
              },
              child: (_selectedIndex == 0 && _movieBookings.isEmpty) || 
                     (_selectedIndex == 1 && _foodOrders.isEmpty)
                  ? _buildEmptyState()
                  : _selectedIndex == 0
                      ? _buildMovieBookings()
                      : _buildFoodOrders(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedIndex == 0 ? Icons.movie_outlined : Icons.restaurant_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedIndex == 0 ? 'No movie bookings yet' : 'No food orders yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedIndex == 0 
                ? 'Book your first movie to see it here!'
                : 'Order some delicious food to see it here!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieBookings() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _movieBookings.length,
      itemBuilder: (context, index) {
        final booking = _updateBookingStatus(_movieBookings[index]);
        final isCancellable = _isCancellable(booking) && booking.status == 'active';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showQRCode(context, booking),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          booking.movieTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(booking.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(booking.date),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(booking.time),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.movie_creation, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Cinema: ${booking.cinema}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.chair, size: 16),
                      const SizedBox(width: 4),
                      Text('Seats: ${booking.seats.join(", ")}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Total: RM${booking.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 155, 13, 3),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _showQRCode(context, booking),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('QR'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Booked on: ${_formatDate(booking.bookingDate)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (isCancellable)
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel Booking'),
                                content: const Text(
                                  'Are you sure you want to request cancellation for this booking?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _cancelBooking(booking);
                                    },
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Request\nCancellation', style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFoodOrders() {
    if (_isLoadingFoodOrders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _foodOrders.length,
      itemBuilder: (context, index) {
        final order = _foodOrders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showFoodOrderQR(context, order),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant, color: ColorApp.primaryDarkColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Order #${order['orderId']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildOrderStatusBadge(order['status'] ?? 'completed'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Order items
                  ...List.generate(
                    (order['items'] as List).length,
                    (itemIndex) {
                      final item = order['items'][itemIndex];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: (item['image'] ?? '').startsWith('http')
                                  ? Image.network(
                                      item['image'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image_not_supported, size: 16),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.restaurant, size: 16),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['quantity']}x ${item['title']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item['selectedOptions'] != null && 
                                      (item['selectedOptions'] as List).isNotEmpty)
                                    Text(
                                      (item['selectedOptions'] as List).join(', '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              'RM${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ColorApp.primaryDarkColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const Divider(height: 20),
                  
                  // Order summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Total: RM${order['total'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 155, 13, 3),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _showFoodOrderQR(context, order),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('QR'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Order details
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Ordered: ${_formatDate(order['orderDate'])}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Pickup: ${_formatTime(order['estimatedPickupTime'])}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payment, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Payment: ${order['paymentMethod']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Add cancel button if order is cancellable
                      if (_isFoodOrderCancellable(order))
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel Food Order'),
                                content: const Text(
                                  'Are you sure you want to cancel this food order?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _cancelFoodOrder(order);
                                    },
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Cancel\nOrder', style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderStatusBadge(String status) {
    Color color;
    String text;

    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.blue;
        text = 'COMPLETED';
        break;
      case 'preparing':
        color = Colors.orange;
        text = 'PREPARING';
        break;
      case 'ready':
        color = Colors.green;
        text = 'READY';
        break;
      case 'picked_up':
        color = Colors.purple;
        text = 'PICKED UP';
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showFoodOrderQR(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Food Order #${order['orderId']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Show this QR code at the concession stand',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: _generateFoodOrderQRData(order),
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 16),
              Text(
                'Total: RM${order['total'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColorApp.primaryDarkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pickup Time: ${_formatDateTime(order['estimatedPickupTime'])}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateFoodOrderQRData(Map<String, dynamic> order) {
    return '''
Order ID: ${order['orderId']}
Total: RM${order['total'].toStringAsFixed(2)}
Pickup Time: ${_formatDateTime(order['estimatedPickupTime'])}
Items: ${(order['items'] as List).map((item) => '${item['quantity']}x ${item['title']}').join(', ')}
''';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 