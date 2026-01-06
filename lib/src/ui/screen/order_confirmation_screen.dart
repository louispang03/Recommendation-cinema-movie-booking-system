import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class OrderConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderConfirmationScreen({
    super.key,
    required this.order,
  });

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Check if this is a movie booking or food order
  bool get _isMovieBooking {
    return order['items'].any((item) => 
      item.containsKey('movieTitle') || 
      item.containsKey('seats') || 
      item.containsKey('selectedDate') ||
      item.containsKey('selectedTime') ||
      item.containsKey('selectedCinema')
    );
  }

  String _generateQRData() {
    final qrData = {
      'orderId': order['orderId'],
      'total': order['total'],
      'items': order['items'].map((item) => {
        'title': item['title'],
        'quantity': item['quantity'],
        'selectedOptions': item['selectedOptions'] ?? [],
      }).toList(),
    };

    // Only add pickup time for food orders
    if (!_isMovieBooking && order['estimatedPickupTime'] != null) {
      qrData['estimatedPickupTime'] = order['estimatedPickupTime'].toIso8601String();
    }

    return jsonEncode(qrData);
  }

  Widget _buildItemImage(Map<String, dynamic> item) {
    final imageUrl = item['image'] ?? item['imageUrl'] ?? item['poster_path'];
    
    // If no image URL is provided, show a default icon
    if (imageUrl == null || imageUrl.toString().isEmpty) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey[200],
        child: Icon(
          _isMovieBooking ? Icons.movie : Icons.restaurant,
          size: 20,
          color: Colors.grey[600],
        ),
      );
    }

    // Handle different image URL formats
    String finalImageUrl = imageUrl.toString();
    
    // If it's a relative path or doesn't start with http, try to construct full URL
    if (!finalImageUrl.startsWith('http')) {
      // For TMDB images
      if (finalImageUrl.startsWith('/')) {
        finalImageUrl = 'https://image.tmdb.org/t/p/w500$finalImageUrl';
      } else {
        // For local assets or other relative paths
        finalImageUrl = 'https://via.placeholder.com/100x100?text=${item['title'] ?? 'Item'}';
      }
    }

    return Image.network(
      finalImageUrl,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 50,
          height: 50,
          color: Colors.grey[200],
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 50,
          height: 50,
          color: Colors.grey[200],
          child: Icon(
            _isMovieBooking ? Icons.movie : Icons.restaurant,
            size: 20,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Confirmed',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSuccessHeader(),
            const SizedBox(height: 24),
            _buildOrderDetails(),
            const SizedBox(height: 24),
            _buildPickupQRCode(),
            const SizedBox(height: 24),
            _buildETicket(),
            const SizedBox(height: 24),
            _buildInstructions(),
            const SizedBox(height: 32),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Order Confirmed!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order #${order['orderId']}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your food will be ready for pickup in approximately 15 minutes',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...order['items'].map<Widget>((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildItemImage(item),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['quantity']}x ${item['title']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item['selectedOptions'] != null && 
                          (item['selectedOptions'] as List).isNotEmpty)
                        Text(
                          'Options: ${(item['selectedOptions'] as List).join(', ')}',
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
          )),
          const Divider(),
          _buildPriceSummary(),
          const SizedBox(height: 16),
          _buildCustomerInfo(),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:'),
            Text('RM${order['subtotal'].toStringAsFixed(2)}'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tax (6%):'),
            Text('RM${order['tax'].toStringAsFixed(2)}'),
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
              'RM${order['total'].toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ColorApp.primaryDarkColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isMovieBooking ? 'Booking Information' : 'Order Information',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text('Payment: ${order['paymentMethod']}'),
        Text('${_isMovieBooking ? 'Booking' : 'Order'} Date: ${_formatDateTime(order['orderDate'])}'),
        // Only show pickup time for food orders
        if (!_isMovieBooking && order['estimatedPickupTime'] != null)
          Text('Estimated Pickup: ${_formatDateTime(order['estimatedPickupTime'])}'),
      ],
    );
  }

  Widget _buildPickupQRCode() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code,
                color: ColorApp.primaryDarkColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isMovieBooking ? 'Movie Ticket QR Code' : 'Food Pickup QR Code',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: _generateQRData(),
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Show this QR code at the concession stand for pickup',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildETicket() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorApp.primaryDarkColor.withOpacity(0.8),
            ColorApp.primaryDarkColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_activity,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'E-Ticket',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'CINELOOK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ColorApp.primaryDarkColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isMovieBooking ? 'Movie Ticket' : 'Food & Beverage Order',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_isMovieBooking ? 'Booking ID:' : 'Order ID:'),
                    Text(
                      order['orderId'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:'),
                    Text(
                      'RM${order['total'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorApp.primaryDarkColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Show different details based on booking type
                if (_isMovieBooking)
                  _buildMovieDetails()
                else if (order['estimatedPickupTime'] != null)
                  _buildPickupTimeDetails(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieDetails() {
    if (order['items'].isEmpty) return const SizedBox.shrink();
    
    final movieItem = order['items'][0];
    return Column(
      children: [
        if (movieItem['movieTitle'] != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Movie:'),
              Flexible(
                child: Text(
                  movieItem['movieTitle'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (movieItem['selectedDate'] != null && movieItem['selectedTime'] != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Date & Time:'),
              Text(
                '${movieItem['selectedDate']} • ${movieItem['selectedTime']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (movieItem['selectedCinema'] != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cinema:'),
              Flexible(
                child: Text(
                  movieItem['selectedCinema'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (movieItem['seats'] != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Seats:'),
              Text(
                (movieItem['seats'] as List).join(', '),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPickupTimeDetails() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Pickup Time:'),
        Text(
          _formatDateTime(order['estimatedPickupTime']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isMovieBooking ? 'Movie Entry Instructions' : 'Pickup Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isMovieBooking) ...[
            const Text('1. Arrive at the cinema 15-20 minutes before showtime'),
            const SizedBox(height: 4),
            const Text('2. Show your QR code at the entrance or ticket counter'),
            const SizedBox(height: 4),
            const Text('3. Proceed to your designated theater and seat'),
            const SizedBox(height: 4),
            const Text('4. Enjoy your movie!'),
            const SizedBox(height: 12),
            Text(
              'Note: Please keep your QR code accessible for entry verification.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.blue[600],
              ),
            ),
          ] else ...[
            const Text('1. Go to the concession stand in the cinema lobby'),
            const SizedBox(height: 4),
            const Text('2. Show your QR code to the staff'),
            const SizedBox(height: 4),
            const Text('3. Present your e-ticket for verification'),
            const SizedBox(height: 4),
            const Text('4. Collect your food and enjoy!'),
            const SizedBox(height: 12),
            if (order['estimatedPickupTime'] != null)
              Text(
                'Note: Please arrive at your estimated pickup time to ensure food freshness.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.blue[600],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        icon: const Icon(Icons.home),
        label: const Text(
          'Back to Home',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorApp.primaryDarkColor,
          side: const BorderSide(color: ColorApp.primaryDarkColor),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
} 