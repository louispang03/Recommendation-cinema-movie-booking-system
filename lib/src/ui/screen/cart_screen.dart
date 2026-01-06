import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/screen/checkout_screen.dart';
import 'package:intl/intl.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final Function(List<Map<String, dynamic>>) onUpdateCart;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.onUpdateCart,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<Map<String, dynamic>> _cartItems;
  DateTime? _selectedPickupDate;
  TimeOfDay? _selectedPickupTime;

  @override
  void initState() {
    super.initState();
    _cartItems = List.from(widget.cartItems);
    // Set default pickup time to 30 minutes from now
    final now = DateTime.now();
    _selectedPickupDate = DateTime(now.year, now.month, now.day);
    _selectedPickupTime = TimeOfDay(
      hour: now.add(const Duration(minutes: 30)).hour,
      minute: now.add(const Duration(minutes: 30)).minute,
    );
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => 
      sum + (item['price'] * item['quantity']));
  }

  double get _tax {
    return _subtotal * 0.06; // 6% tax
  }

  double get _total {
    return _subtotal + _tax;
  }

  void _updateQuantity(String cartId, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.removeWhere((item) => item['cartId'] == cartId);
      } else {
        final itemIndex = _cartItems.indexWhere((item) => item['cartId'] == cartId);
        if (itemIndex >= 0) {
          _cartItems[itemIndex]['quantity'] = newQuantity;
        }
      }
    });
    widget.onUpdateCart(_cartItems);
  }

  void _removeItem(String cartId) {
    setState(() {
      _cartItems.removeWhere((item) => item['cartId'] == cartId);
    });
    widget.onUpdateCart(_cartItems);
  }

  Future<void> _selectPickupDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPickupDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)), // Allow booking up to 7 days ahead
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorApp.primaryDarkColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPickupDate = picked;
        // If selecting today, ensure pickup time is at least 30 minutes from now
        if (picked.day == now.day && picked.month == now.month && picked.year == now.year) {
          final minTime = now.add(const Duration(minutes: 30));
          if (_selectedPickupTime != null) {
            final selectedDateTime = DateTime(
              picked.year,
              picked.month,
              picked.day,
              _selectedPickupTime!.hour,
              _selectedPickupTime!.minute,
            );
            if (selectedDateTime.isBefore(minTime)) {
              _selectedPickupTime = TimeOfDay(hour: minTime.hour, minute: minTime.minute);
            }
          }
        }
      });
    }
  }

  Future<void> _selectPickupTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedPickupTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorApp.primaryDarkColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final selectedDate = _selectedPickupDate ?? now;
      
      // Check if the selected time is valid
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        picked.hour,
        picked.minute,
      );
      
      final minTime = now.add(const Duration(minutes: 30));
      
      if (selectedDateTime.isBefore(minTime)) {
        // Show error if trying to select a time too soon
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup time must be at least 30 minutes from now'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        _selectedPickupTime = picked;
      });
    }
  }

  String get _formattedPickupDateTime {
    if (_selectedPickupDate == null || _selectedPickupTime == null) {
      return 'Select pickup time';
    }
    
    final date = DateFormat('EEE, MMM d').format(_selectedPickupDate!);
    final time = _selectedPickupTime!.format(context);
    return '$date at $time';
  }

  DateTime? get _pickupDateTime {
    if (_selectedPickupDate == null || _selectedPickupTime == null) {
      return null;
    }
    
    return DateTime(
      _selectedPickupDate!.year,
      _selectedPickupDate!.month,
      _selectedPickupDate!.day,
      _selectedPickupTime!.hour,
      _selectedPickupTime!.minute,
    );
  }

  // Check if this is a movie booking or food order
  bool get _isMovieBooking {
    return _cartItems.any((item) => 
      item.containsKey('movieTitle') || 
      item.containsKey('seats') || 
      item.containsKey('selectedDate') ||
      item.containsKey('selectedTime') ||
      item.containsKey('selectedCinema')
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cartItems.isEmpty 
        ? _buildEmptyCart()
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return _buildCartItem(item);
                  },
                ),
              ),
              // Only show pickup time selector for food orders
              if (!_isMovieBooking) _buildPickupTimeSelector(),
              _buildOrderSummary(),
            ],
          ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some delicious items to get started!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorApp.primaryDarkColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Continue Shopping',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (item['image'] ?? '').startsWith('http')
                ? Image.network(
                    item['image'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  )
                : Image.asset(
                    item['image'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 12),
          
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RM${item['price'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: ColorApp.primaryDarkColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item['selectedOptions'] != null && 
                    (item['selectedOptions'] as List).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Options: ${(item['selectedOptions'] as List).join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Quantity controls
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _updateQuantity(
                        item['cartId'], 
                        item['quantity'] - 1
                      ),
                      icon: const Icon(Icons.remove, size: 16),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 30,
                    alignment: Alignment.center,
                    child: Text(
                      item['quantity'].toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _updateQuantity(
                        item['cartId'], 
                        item['quantity'] + 1
                      ),
                      icon: const Icon(Icons.add, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _removeItem(item['cartId']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupTimeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule,
                color: ColorApp.primaryDarkColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Pickup Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Date and Time Selection Buttons
          Row(
            children: [
              // Date Selection
              Expanded(
                child: GestureDetector(
                  onTap: _selectPickupDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: ColorApp.primaryDarkColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedPickupDate != null 
                                ? DateFormat('EEE, MMM d').format(_selectedPickupDate!)
                                : 'Select Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedPickupDate != null ? Colors.black87 : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Time Selection
              Expanded(
                child: GestureDetector(
                  onTap: _selectPickupTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 18, color: ColorApp.primaryDarkColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedPickupTime != null 
                                ? _selectedPickupTime!.format(context)
                                : 'Select Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedPickupTime != null ? Colors.black87 : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Display selected pickup time
          if (_selectedPickupDate != null && _selectedPickupTime != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: ColorApp.primaryDarkColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ColorApp.primaryDarkColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: ColorApp.primaryDarkColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pickup: $_formattedPickupDateTime',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColorApp.primaryDarkColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Instruction text
          const SizedBox(height: 8),
          Text(
            'Please select when you would like to pick up your order. Minimum 30 minutes from now.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
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
              const Text('Subtotal:', style: TextStyle(fontSize: 16)),
              Text('RM${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tax (6%):', style: TextStyle(fontSize: 16)),
              Text('RM${_tax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'RM${_total.toStringAsFixed(2)}',
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
              onPressed: _cartItems.isEmpty ? null : () {
                // Validate pickup time is selected only for food orders
                if (!_isMovieBooking && _pickupDateTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a pickup date and time'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      cartItems: _cartItems,
                      subtotal: _subtotal,
                      tax: _tax,
                      total: _total,
                      pickupDateTime: _pickupDateTime, // Pass pickup time (can be null for movie bookings)
                      onOrderComplete: () {
                        // Clear cart after successful order
                        setState(() {
                          _cartItems.clear();
                        });
                        widget.onUpdateCart(_cartItems);
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorApp.primaryDarkColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Proceed to Checkout',
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