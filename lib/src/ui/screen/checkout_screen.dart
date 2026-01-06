import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/screen/order_confirmation_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/src/services/seat_service.dart';
import 'package:fyp_cinema_app/src/services/booking_service.dart';
import 'package:fyp_cinema_app/src/models/booking.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final double tax;
  final double total;
  final DateTime? pickupDateTime; // Make optional for movie bookings
  final Function()? onOrderComplete;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.pickupDateTime, // Optional for movie bookings
    this.onOrderComplete,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = 'Cash';
  bool _isProcessing = false;

  // Services for movie booking
  final SeatService _seatService = SeatService();
  final BookingService _bookingService = BookingService();

  // No form controllers needed for cash payment

  // Check if this is a movie booking or food order
  bool get _isMovieBooking {
    return widget.cartItems.any((item) => 
      item.containsKey('movieTitle') || 
      item.containsKey('seats') || 
      item.containsKey('selectedDate') ||
      item.containsKey('selectedTime') ||
      item.containsKey('selectedCinema')
    );
  }

  // Get appropriate image for different item types
  ImageProvider _getItemImage(Map<String, dynamic> item) {
    // For movie bookings
    if (item.containsKey('movieTitle')) {
      // Try multiple possible image fields from database/API
      final imageUrl = item['imageUrl'] ?? 
                      item['image'] ?? 
                      item['poster_path'] ?? 
                      item['posterPath'] ?? 
                      item['backdrop_path'] ?? 
                      item['backdropPath'];
      
      print('Movie image URL: $imageUrl'); // Debug log
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        if (imageUrl.startsWith('http')) {
          return NetworkImage(imageUrl);
        } else if (imageUrl.startsWith('https://image.tmdb.org/')) {
          return NetworkImage(imageUrl);
        } else if (imageUrl.startsWith('assets/')) {
          return AssetImage(imageUrl);
        } else {
          // Handle TMDB relative paths
          return NetworkImage('https://image.tmdb.org/t/p/w500$imageUrl');
        }
      }
      
      // Fallback to movie icon
      return const AssetImage('assets/images/food.png'); // Using food.png as fallback since movie_placeholder.png might not exist
    }
    
    // For food items
    if (item.containsKey('image')) {
      final imageUrl = item['image'];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        if (imageUrl.startsWith('http')) {
          return NetworkImage(imageUrl);
        } else if (imageUrl.startsWith('assets/')) {
          return AssetImage(imageUrl);
        }
      }
    }
    
    // Default placeholder
    return const AssetImage('assets/images/food.png');
  }

  @override
  void dispose() {
    // No controllers to dispose for cash payment
    super.dispose();
  }

  Future<void> _processOrder() async {
    // No validation needed for cash payment

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Generate order data
      final orderId = _isMovieBooking 
          ? 'BOOKING${DateTime.now().millisecondsSinceEpoch}'
          : 'ORD${DateTime.now().millisecondsSinceEpoch}';
      final orderDate = DateTime.now();

      final order = <String, dynamic>{
        'orderId': orderId,
        'userId': user.uid,
        'userEmail': user.email,
        'items': widget.cartItems,
        'subtotal': widget.subtotal,
        'tax': widget.tax,
        'total': widget.total,
        'paymentMethod': _selectedPaymentMethod,
        'orderDate': orderDate,
        'status': 'completed', // Order status
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add pickup time only for food orders
      if (!_isMovieBooking && widget.pickupDateTime != null) {
        order['estimatedPickupTime'] = widget.pickupDateTime;
      }

      // For movie bookings, handle seat booking first
      if (_isMovieBooking) {
        final movieItem = widget.cartItems.first; // Should only have one movie item
        final seats = List<String>.from(movieItem['seats']);
        
        // Book seats first
        await _seatService.bookSeats(
          movieItem['movieId'],
          movieItem['selectedDate'],
          movieItem['selectedTime'],
          movieItem['selectedCinema'],
          seats,
        );

        // Then save the booking using the booking service
        final booking = Booking(
          id: '',
          movieId: movieItem['movieId'],
          movieTitle: movieItem['movieTitle'],
          date: movieItem['selectedDate'],
          time: movieItem['selectedTime'],
          seats: seats,
          totalPrice: widget.total,
          bookingDate: DateTime.now(),
          cinema: movieItem['selectedCinema'],
        );

        await _bookingService.saveBooking(booking);
        print('✅ Movie seats booked and booking saved: $orderId');
      }

      // Choose collection based on order type
      final collectionName = _isMovieBooking ? 'movie_bookings' : 'food_orders';
      
      // Save order to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .add(order);

      print('✅ ${_isMovieBooking ? 'Movie booking' : 'Food order'} saved to user subcollection: $orderId');

      setState(() {
        _isProcessing = false;
      });

      // Clear cart after successful order
      if (widget.onOrderComplete != null) {
        widget.onOrderComplete!();
      }

      // Navigate to order confirmation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(order: order),
        ),
        (route) => route.isFirst, // This will keep only the first route (home)
      );
    } catch (e) {
      print('❌ Error saving ${_isMovieBooking ? 'movie booking' : 'food order'}: $e');
      setState(() {
        _isProcessing = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing ${_isMovieBooking ? 'booking' : 'order'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderSummary(),
                  const SizedBox(height: 24),
                  _buildPaymentMethod(),
                ],
              ),
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.cartItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Item image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: _getItemImage(item),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['quantity']}x ${item['title']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item['description'] != null && item['description'].isNotEmpty)
                        Text(
                          item['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Price
                Text(
                  'RM${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ColorApp.primaryDarkColor,
                  ),
                ),
              ],
            ),
          )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:'),
              Text('RM${widget.subtotal.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tax (6%):'),
              Text('RM${widget.tax.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'RM${widget.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColorApp.primaryDarkColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(
                Icons.payments,
                color: ColorApp.primaryDarkColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Cash Payment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorApp.primaryDarkColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Selected',
                  style: TextStyle(
                    color: ColorApp.primaryDarkColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'RM${widget.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorApp.primaryDarkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorApp.primaryDarkColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Place Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
} 