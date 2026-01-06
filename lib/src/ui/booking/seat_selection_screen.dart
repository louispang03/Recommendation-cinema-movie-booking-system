import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/models/booking.dart';
import 'package:fyp_cinema_app/src/services/booking_service.dart';
import 'package:fyp_cinema_app/src/services/seat_service.dart';
import 'package:fyp_cinema_app/src/ui/screen/checkout_screen.dart';

class Cinema {
  final String name;
  final double basePrice;
  final List<String> availableTimes;
  final List<List<bool>> occupiedSeats;

  Cinema({
    required this.name,
    required this.basePrice,
    required this.availableTimes,
    required this.occupiedSeats,
  });
}

class SeatSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  final String selectedDate;
  final String selectedTime;
  final String selectedCinema;
  final double basePrice;

  const SeatSelectionScreen({
    super.key,
    required this.movie,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedCinema,
    required this.basePrice,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final BookingService _bookingService = BookingService();
  final SeatService _seatService = SeatService();
  List<List<bool>> _selectedSeats = List.generate(8, (i) => List.generate(10, (j) => false));
  List<List<bool>> _occupiedSeats = List.generate(8, (i) => List.generate(10, (j) => false));
  int _totalPrice = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOccupiedSeats();
  }

  Future<void> _loadOccupiedSeats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Loading occupied seats for:');
      print('Movie ID: ${widget.movie['id']}');
      print('Date: ${widget.selectedDate}');
      print('Time: ${widget.selectedTime}');
      print('Cinema: ${widget.selectedCinema}');

      final bookedSeats = await _seatService.getBookedSeats(
        widget.movie['id'].toString(),
        widget.selectedDate,
        widget.selectedTime,
        widget.selectedCinema,
      );

      print('Booked seats: $bookedSeats');

      // Reset occupied seats
      _occupiedSeats = List.generate(8, (i) => List.generate(10, (j) => false));

      // Mark booked seats as occupied
      for (var seat in bookedSeats) {
        final row = seat.codeUnitAt(0) - 65; // Convert A to 0, B to 1, etc.
        final col = int.parse(seat.substring(1)) - 1;
        if (row >= 0 && row < 8 && col >= 0 && col < 10) {
          _occupiedSeats[row][col] = true;
          print('Marking seat $seat as occupied (row: $row, col: $col)');
        }
      }
    } catch (e) {
      print('Error loading occupied seats: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading seat availability: ${e.toString()}'),
          backgroundColor: const Color(0xFF1A1C1E),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSeat(int row, int col) async {
    if (!_occupiedSeats[row][col]) {
      final seat = '${String.fromCharCode(65 + row)}${col + 1}';
      print('Checking availability for seat: $seat');
      
      try {
        final isAvailable = await _seatService.isSeatAvailable(
          widget.movie['id'].toString(),
          widget.selectedDate,
          widget.selectedTime,
          widget.selectedCinema,
          seat,
        );

        print('Seat $seat availability: $isAvailable');

        if (isAvailable) {
          setState(() {
            _selectedSeats[row][col] = !_selectedSeats[row][col];
            _totalPrice = _calculateTotalPrice();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This seat is no longer available'),
              backgroundColor: Color(0xFF1A1C1E),
            ),
          );
        }
      } catch (e) {
        print('Error checking seat availability: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking seat availability: ${e.toString()}'),
            backgroundColor: const Color(0xFF1A1C1E),
          ),
        );
      }
    }
  }

  int _calculateTotalPrice() {
    int selectedSeatsCount = 0;
    for (var row in _selectedSeats) {
      selectedSeatsCount += row.where((seat) => seat).length;
    }
    return (selectedSeatsCount * widget.basePrice).toInt();
  }

  /// Validates business rules for seat selection
  /// Returns a list of validation error messages
  List<String> _validateSeatSelection() {
    List<String> errors = [];
    
    // Get all selected seats
    List<Map<String, int>> selectedSeats = [];
    for (int i = 0; i < _selectedSeats.length; i++) {
      for (int j = 0; j < _selectedSeats[i].length; j++) {
        if (_selectedSeats[i][j]) {
          selectedSeats.add({'row': i, 'col': j});
        }
      }
    }

    if (selectedSeats.isEmpty) {
      return errors; // No seats selected, no validation needed
    }

    // Group selected seats by row
    Map<int, List<int>> seatsByRow = {};
    for (var seat in selectedSeats) {
      seatsByRow.putIfAbsent(seat['row']!, () => []).add(seat['col']!);
    }

    // Validate each row
    for (var row in seatsByRow.keys) {
      List<int> cols = seatsByRow[row]!..sort();
      
      // Check for gaps in seat selection (no single-seat gap rule)
      for (int i = 0; i < cols.length - 1; i++) {
        if (cols[i + 1] - cols[i] > 1) {
          // Check if the gap is a single seat
          if (cols[i + 1] - cols[i] == 2) {
            int gapSeat = cols[i] + 1;
            // Check if the gap seat is not occupied
            if (!_occupiedSeats[row][gapSeat]) {
              errors.add('Cannot leave single-seat gaps. Please select seat ${String.fromCharCode(65 + row)}${gapSeat + 1} or choose different seats.');
            }
          } else {
            // Multiple seat gap
            errors.add('Seats must be contiguous. Please select seats in the same row without gaps.');
          }
        }
      }

      // Check for contiguous seat rule (seats must be adjacent)
      if (cols.length > 1) {
        bool isContiguous = true;
        for (int i = 0; i < cols.length - 1; i++) {
          if (cols[i + 1] - cols[i] != 1) {
            isContiguous = false;
            break;
          }
        }
        if (!isContiguous) {
          errors.add('All selected seats must be adjacent to each other in the same row.');
        }
      }
    }

    return errors;
  }

  /// Checks if the current seat selection is valid according to business rules
  bool _isSeatSelectionValid() {
    return _validateSeatSelection().isEmpty;
  }

  void _proceedToCheckout() {
    // Validate seat selection according to business rules
    List<String> validationErrors = _validateSeatSelection();
    
    if (validationErrors.isNotEmpty) {
      // Show validation errors to user
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Seat Selection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please fix the following issues:'),
              const SizedBox(height: 8),
              ...validationErrors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $error', style: const TextStyle(fontSize: 14)),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; // Prevent proceeding to checkout
    }

    final selectedSeats = <String>[];
    for (int i = 0; i < _selectedSeats.length; i++) {
      for (int j = 0; j < _selectedSeats[i].length; j++) {
        if (_selectedSeats[i][j]) {
          selectedSeats.add('${String.fromCharCode(65 + i)}${j + 1}');
        }
      }
    }

    // Create movie ticket item(s) for checkout
    final movieTicketItem = {
      'id': 'ticket_${widget.movie['id']}_${DateTime.now().millisecondsSinceEpoch}',
      'cartId': 'ticket_${DateTime.now().millisecondsSinceEpoch}',
      'title': '${widget.movie['title']} - ${selectedSeats.join(', ')}',
      'movieTitle': widget.movie['title'],
      'movieId': widget.movie['id'].toString(),
      'selectedDate': widget.selectedDate,
      'selectedTime': widget.selectedTime,
      'selectedCinema': widget.selectedCinema,
      'seats': selectedSeats,
      'price': widget.basePrice,
      'quantity': selectedSeats.length,
      'image': widget.movie['imageUrl'] ?? widget.movie['poster_path'] ?? widget.movie['posterPath'] ?? 'assets/images/food.png',
      'imageUrl': widget.movie['imageUrl'],
      'poster_path': widget.movie['poster_path'],
      'posterPath': widget.movie['posterPath'],
      'backdrop_path': widget.movie['backdrop_path'],
      'backdropPath': widget.movie['backdropPath'],
      'description': '${widget.selectedCinema} • ${widget.selectedDate} • ${widget.selectedTime}',
    };

    final cartItems = [movieTicketItem];
    final subtotal = _totalPrice.toDouble();
    final tax = subtotal * 0.06; // 6% tax
    final total = subtotal + tax;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: cartItems,
          subtotal: subtotal,
          tax: tax,
          total: total,
          // No pickup time for movie bookings
          onOrderComplete: () {
            // Navigate back to home after successful booking
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    final selectedSeats = <String>[];
    for (int i = 0; i < _selectedSeats.length; i++) {
      for (int j = 0; j < _selectedSeats[i].length; j++) {
        if (_selectedSeats[i][j]) {
          selectedSeats.add('${String.fromCharCode(65 + i)}${j + 1}');
        }
      }
    }

    try {
      // Book seats first
      await _seatService.bookSeats(
        widget.movie['id'].toString(),
        widget.selectedDate,
        widget.selectedTime,
        widget.selectedCinema,
        selectedSeats,
      );

      // Then save the booking
      final booking = Booking(
        id: '',
        movieId: widget.movie['id'].toString(),
        movieTitle: widget.movie['title'],
        date: widget.selectedDate,
        time: widget.selectedTime,
        seats: selectedSeats,
        totalPrice: _totalPrice.toDouble(),
        bookingDate: DateTime.now(),
        cinema: widget.selectedCinema,
      );

      await _bookingService.saveBooking(booking);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Seats'),
        backgroundColor: ColorApp.primaryDarkColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Movie and Cinema Info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movie['title'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.selectedCinema,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ColorApp.primaryDarkColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(RM ${widget.basePrice.toStringAsFixed(2)} per seat)',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.selectedDate} | ${widget.selectedTime}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Screen Area
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey[300]!, Colors.grey[100]!],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'SCREEN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Seats Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 10,
                      childAspectRatio: 1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 80,
                    itemBuilder: (context, index) {
                      int row = index ~/ 10;
                      int col = index % 10;
                      bool isBooked = _occupiedSeats[row][col];
                      bool isSelected = _selectedSeats[row][col];

                      return GestureDetector(
                        onTap: () => _toggleSeat(row, col),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isBooked
                                ? Colors.grey[400]
                                : isSelected
                                    ? ColorApp.primaryDarkColor
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isBooked ? Colors.grey[600]! : Colors.grey[400]!,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${String.fromCharCode(65 + row)}${col + 1}',
                              style: TextStyle(
                                color: isBooked || isSelected ? Colors.white : Colors.black,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Legend and Price
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildLegendItem('Available', Colors.grey[200]!),
                          _buildLegendItem('Selected', ColorApp.primaryDarkColor),
                          _buildLegendItem('Booked', Colors.grey[400]!),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Price:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'RM ${_totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56.0,
                        child: ElevatedButton(
                          onPressed: _totalPrice > 0
                              ? () {
                                  // Validate seat selection before showing confirmation dialog
                                  List<String> validationErrors = _validateSeatSelection();
                                  
                                  if (validationErrors.isNotEmpty) {
                                    // Show validation errors to user
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Invalid Seat Selection'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Please fix the following issues:'),
                                            const SizedBox(height: 8),
                                            ...validationErrors.map((error) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text('• $error', style: const TextStyle(fontSize: 14)),
                                            )),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return; // Prevent showing confirmation dialog
                                  }

                                  // Show confirmation dialog if validation passes
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Booking'),
                                      content: Text(
                                        'Confirm booking for ${_selectedSeats.fold(0, (sum, row) => sum + row.where((seat) => seat).length)} seats at ${widget.selectedCinema}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context); // Close the dialog
                                            _proceedToCheckout();
                                          },
                                          child: const Text('Proceed to Checkout'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorApp.primaryDarkColor,
                            elevation: 4,
                            shadowColor: ColorApp.primaryDarkColor.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Book Now',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[400]!),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
} 