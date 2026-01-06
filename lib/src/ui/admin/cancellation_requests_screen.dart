import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/models/booking.dart';
import 'package:fyp_cinema_app/src/models/cancellation_history.dart';
import 'package:fyp_cinema_app/src/models/food_cancellation_history.dart';
import 'package:fyp_cinema_app/src/services/booking_service.dart';
import 'package:fyp_cinema_app/src/services/seat_service.dart';

class CancellationRequestsScreen extends StatefulWidget {
  const CancellationRequestsScreen({super.key});

  @override
  State<CancellationRequestsScreen> createState() => _CancellationRequestsScreenState();
}

class _CancellationRequestsScreenState extends State<CancellationRequestsScreen> {
  final BookingService _bookingService = BookingService();
  final SeatService _seatService = SeatService();
  List<Booking> _pendingRequests = [];
  List<CancellationHistory> _cancellationHistory = [];
  List<FoodCancellationHistory> _foodCancellationHistory = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0 for movies, 1 for food
  
  // Filter variables
  String _movieFilter = '';
  String _dateFilter = '';
  String _statusFilter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First, load existing cancellation history
      await _loadCancellationHistory();
      await _loadFoodCancellationHistory();
      
      // Then process any pending requests
      await _processPendingRequests();
      await _processPendingFoodRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processPendingRequests() async {
    try {
      // Get all pending cancellation requests
      final allPendingRequests = await _bookingService.getPendingCancellations();
      
      // Process each request automatically based on 30-minute rule
      List<Booking> remainingRequests = [];
      
      for (final booking in allPendingRequests) {
        final isEligible = _isEligibleForAutomaticApproval(booking);
        
        // Get user information
        final userId = booking.path != null ? _extractUserIdFromPath(booking.path!) : '';
        final userInfo = await _bookingService.getUserInfo(userId);
        
        // Get cancellation request time (estimated)
        final cancellationRequestTime = await _bookingService.getCancellationRequestTime(booking.path ?? '');
        
        // Create cancellation history record
        final historyId = '${booking.id}_${DateTime.now().millisecondsSinceEpoch}';
        final cancellationHistory = CancellationHistory(
          id: historyId,
          bookingId: booking.id,
          movieTitle: booking.movieTitle,
          movieId: booking.movieId,
          showDate: booking.date,
          showTime: booking.time,
          cinema: booking.cinema,
          seats: booking.seats,
          totalPrice: booking.totalPrice,
          userId: userId,
          userName: userInfo['name'] ?? 'Unknown User',
          userEmail: userInfo['email'] ?? 'No email',
          cancellationRequestTime: cancellationRequestTime ?? DateTime.now().subtract(const Duration(minutes: 5)),
          processedTime: DateTime.now(),
          systemDecision: isEligible ? 'auto_approved' : 'auto_rejected',
          reason: isEligible ? 'before_30_minutes' : 'within_30_minutes',
          refundProcessed: isEligible, // Auto-refund for approved cancellations
          refundAmount: isEligible ? booking.totalPrice : 0.0,
        );
        
        if (isEligible) {
          // Automatically approve the cancellation
          await _approveCancellation(booking);
          // Show notification for auto-approval
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-approved cancellation for ${booking.movieTitle} (requested before 30-minute deadline)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // Automatically reject the cancellation
          await _rejectCancellation(booking);
          // Show notification for auto-rejection
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-rejected cancellation for ${booking.movieTitle} (requested within 30 minutes of showtime)'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        
        // Log the cancellation history
        await _bookingService.logCancellationHistory(cancellationHistory);
      }
      
      // Since all requests are processed automatically, no manual requests remain
      setState(() {
        _pendingRequests = remainingRequests;
      });
      
      // Reload cancellation history to show newly processed requests
      await _loadCancellationHistory();
    } catch (e) {
      print('Error processing pending requests: $e');
      rethrow; // Let the parent method handle the error display
    }
  }

  Future<void> _approveCancellation(Booking booking) async {
    try {
      // Release the seats first
      await _seatService.releaseSeats(
        booking.movieId,
        booking.date,
        booking.time,
        booking.cinema,
        booking.seats,
      );

      // Update booking status to cancelled
      await _bookingService.approveCancellation(booking);

      // Remove from pending requests
      setState(() {
        _pendingRequests.removeWhere((b) => b.id == booking.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation approved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving cancellation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectCancellation(Booking booking) async {
    try {
      // Update booking status back to active
      await _bookingService.rejectCancellation(booking);

      // Remove from pending requests
      setState(() {
        _pendingRequests.removeWhere((b) => b.id == booking.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting cancellation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isEligibleForAutomaticApproval(Booking booking) {
    try {
      // Parse the date and time from the booking
      final dateParts = booking.date.split(', ');
      final day = int.parse(dateParts[1].split(' ')[0]);
      final month = _getMonthNumber(dateParts[1].split(' ')[1]);
      final year = DateTime.now().year; // Assuming current year
      
      final timeParts = booking.time.split(' ');
      final hourMinute = timeParts[0].split(':');
      final hour = int.parse(hourMinute[0]);
      final minute = int.parse(hourMinute[1]);
      final isAM = timeParts[1] == 'AM';
      
      // Convert to 24-hour format
      int hour24;
      if (isAM) {
        hour24 = hour == 12 ? 0 : hour; // 12 AM = 0, other AM hours stay the same
      } else {
        hour24 = hour == 12 ? 12 : hour + 12; // 12 PM = 12, other PM hours add 12
      }
      
      final showtime = DateTime(year, month, day, hour24, minute);
      final now = DateTime.now();
      
      // Check if the showtime is more than 30 minutes away
      return showtime.difference(now).inMinutes >= 30;
    } catch (e) {
      print('Error parsing booking date/time: $e');
      // If we can't parse the date/time, reject the cancellation for safety
      return false;
    }
  }

  int _getMonthNumber(String month) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };
    return months[month] ?? 1;
  }

  String _extractUserIdFromPath(String path) {
    // Path format: users/{userId}/bookings/{bookingId}
    final parts = path.split('/');
    if (parts.length >= 2) {
      return parts[1];
    }
    return '';
  }

  Future<void> _loadCancellationHistory() async {
    try {
      final history = await _bookingService.getCancellationHistory(
        movieFilter: _movieFilter.isNotEmpty ? _movieFilter : null,
        dateFilter: _dateFilter.isNotEmpty ? _dateFilter : null,
        statusFilter: _statusFilter.isNotEmpty ? _statusFilter : null,
      );
      
      setState(() {
        _cancellationHistory = history;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadFoodCancellationHistory() async {
    try {
      final history = await _bookingService.getFoodCancellationHistory();
      
      setState(() {
        _foodCancellationHistory = history;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading food history: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _processPendingFoodRequests() async {
    try {
      // Get all pending food cancellation requests
      final allPendingRequests = await _bookingService.getPendingFoodCancellations();
      
      // Process each request automatically based on 30-minute rule
      for (final foodOrder in allPendingRequests) {
        final isEligible = _isFoodOrderEligibleForAutomaticApproval(foodOrder);
        
        // Get user information
        final userId = _extractUserIdFromPath(foodOrder['path']);
        final userInfo = await _bookingService.getUserInfo(userId);
        
        // Create food cancellation history record
        final historyId = '${foodOrder['orderId']}_${DateTime.now().millisecondsSinceEpoch}';
        final cancellationHistory = FoodCancellationHistory(
          id: historyId,
          orderId: foodOrder['orderId'],
          userId: userId,
          userName: userInfo['name'] ?? 'Unknown User',
          userEmail: userInfo['email'] ?? 'No email',
          foodItems: List<Map<String, dynamic>>.from(foodOrder['items'] ?? []),
          totalAmount: (foodOrder['total'] ?? 0).toDouble(),
          orderTime: (foodOrder['orderDate'] as Timestamp).toDate(),
          pickupTime: (foodOrder['estimatedPickupTime'] as Timestamp).toDate(),
          cancellationRequestTime: DateTime.now().subtract(const Duration(minutes: 5)),
          processedTime: DateTime.now(),
          systemDecision: isEligible ? 'auto_approved' : 'auto_rejected',
          reason: isEligible ? 'before_30_minutes' : 'within_30_minutes',
          refundProcessed: isEligible,
          refundAmount: isEligible ? (foodOrder['total'] ?? 0).toDouble() : 0.0,
        );
        
        if (isEligible) {
          // Automatically approve the cancellation
          await _bookingService.approveFoodCancellation(foodOrder);
          // Show notification for auto-approval
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-approved food cancellation for Order #${foodOrder['orderId']} (requested before 30-minute deadline)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // Automatically reject the cancellation
          await _bookingService.rejectFoodCancellation(foodOrder);
          // Show notification for auto-rejection
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-rejected food cancellation for Order #${foodOrder['orderId']} (requested within 30 minutes of pickup)'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        
        // Log the food cancellation history
        await _bookingService.logFoodCancellationHistory(cancellationHistory);
      }
      
      // Reload food cancellation history to show newly processed requests
      await _loadFoodCancellationHistory();
    } catch (e) {
      print('Error processing pending food requests: $e');
      rethrow;
    }
  }

  bool _isFoodOrderEligibleForAutomaticApproval(Map<String, dynamic> foodOrder) {
    try {
      final pickupTime = (foodOrder['estimatedPickupTime'] as Timestamp).toDate();
      final now = DateTime.now();
      
      // Check if the pickup time is more than 30 minutes away
      return pickupTime.difference(now).inMinutes >= 30;
    } catch (e) {
      print('Error parsing food order pickup time: $e');
      // If we can't parse the pickup time, reject the cancellation for safety
      return false;
    }
  }

  void _applyFilters() {
    if (_selectedTabIndex == 0) {
      _loadCancellationHistory();
    } else {
      // For food tab, we only need to trigger a UI rebuild since we filter locally
      setState(() {});
    }
  }

  void _clearFilters() {
    setState(() {
      _movieFilter = '';
      _dateFilter = '';
      _statusFilter = '';
      if (_selectedTabIndex == 0) {
        _searchController.clear();
      }
    });
    if (_selectedTabIndex == 0) {
      _loadCancellationHistory();
    } else {
      // For food tab, clearing filters just triggers a UI rebuild
      setState(() {});
    }
  }



  Widget _buildMovieFilters() {
    return Column(
      children: [
        // Search bar for movies
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by movie title...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF047857)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _movieFilter = value;
            });
            _applyFilters();
          },
        ),
        const SizedBox(height: 12),
        // Status filter for movies
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _statusFilter.isEmpty ? null : _statusFilter,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All Status')),
                  DropdownMenuItem(value: 'auto_approved', child: Text('Auto-approved')),
                  DropdownMenuItem(value: 'auto_rejected', child: Text('Auto-rejected')),
                ],
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value ?? '';
                  });
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFoodFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _statusFilter.isEmpty ? null : _statusFilter,
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('All Status')),
              DropdownMenuItem(value: 'auto_approved', child: Text('Auto-approved')),
              DropdownMenuItem(value: 'auto_rejected', child: Text('Auto-rejected')),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value ?? '';
              });
              _applyFilters();
            },
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('Clear'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Cancellation Management',
          style: TextStyle(
            color: Color(0xFF047857),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF9FAFB),
        iconTheme: const IconThemeData(color: Color(0xFF047857)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF047857)),
                  SizedBox(height: 16),
                  Text(
                    'Loading cancellation history...',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Column(
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
                          onTap: () {
                            setState(() {
                              _selectedTabIndex = 0;
                              // Clear food-specific filters when switching to movies
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 0 ? const Color(0xFF047857) : Colors.transparent,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.movie,
                                  color: _selectedTabIndex == 0 ? Colors.white : Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Movies (${_cancellationHistory.length})',
                                  style: TextStyle(
                                    color: _selectedTabIndex == 0 ? Colors.white : Colors.grey[600],
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
                            setState(() {
                              _selectedTabIndex = 1;
                              // Clear movie search when switching to food
                              _movieFilter = '';
                              _searchController.clear();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 1 ? const Color(0xFF047857) : Colors.transparent,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant,
                                  color: _selectedTabIndex == 1 ? Colors.white : Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Food (${_foodCancellationHistory.length})',
                                  style: TextStyle(
                                    color: _selectedTabIndex == 1 ? Colors.white : Colors.grey[600],
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
                
                                 // Filters
                 Container(
                   padding: const EdgeInsets.all(16),
                   color: Colors.white,
                   child: _selectedTabIndex == 0 
                       ? _buildMovieFilters()
                       : _buildFoodFilters(),
                 ),
                                // History list
                Expanded(
                  child: _selectedTabIndex == 0 
                      ? _buildMovieCancellationList()
                      : _buildFoodCancellationList(),
                ),
              ],
            ),
    );
  }

  Widget _buildMovieCancellationList() {
    return _cancellationHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                  Icons.movie_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                  'No movie cancellation history found',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Movie cancellation requests will appear here after processing',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
                    padding: const EdgeInsets.all(16),
              itemCount: _cancellationHistory.length,
              itemBuilder: (context, index) {
                final history = _cancellationHistory[index];
                return _buildCancellationHistoryCard(history);
              },
            ),
          );
  }

  Widget _buildFoodCancellationList() {
    // Apply status filter to food cancellation history
    final filteredHistory = _statusFilter.isEmpty 
        ? _foodCancellationHistory
        : _foodCancellationHistory.where((history) => history.systemDecision == _statusFilter).toList();

    return filteredHistory.isEmpty
        ? Center(
                    child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _statusFilter.isEmpty 
                      ? 'No food cancellation history found'
                      : 'No food cancellations found for selected status',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusFilter.isEmpty
                      ? 'Food cancellation requests will appear here after processing'
                      : 'Try changing the status filter to see more results',
                                        style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredHistory.length,
              itemBuilder: (context, index) {
                final history = filteredHistory[index];
                return _buildFoodCancellationHistoryCard(history);
              },
            ),
          );
  }

  Widget _buildCancellationHistoryCard(CancellationHistory history) {
    final isApproved = history.systemDecision == 'auto_approved';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
        padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
            // Header with movie title and status
                                              Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                    history.movieTitle,
                                                      style: const TextStyle(
                                                        fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isApproved ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isApproved ? Colors.green[300]! : Colors.orange[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        history.statusIcon,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        history.statusText,
                                                      style: TextStyle(
                          color: isApproved ? Colors.green[800] : Colors.orange[800],
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                      ),
                    ],
                                                    ),
                                                  ),
                                                ],
                                              ),
            
                                              const SizedBox(height: 16),
            
            // Booking details section
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                  Text(
                    'Booking Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                                                    ),
                                                    const SizedBox(height: 12),
                  _buildInfoRow(Icons.confirmation_number, 'Booking ID', history.bookingId),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today, 'Show Date', history.showDate),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, 'Show Time', history.showTime),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.movie, 'Cinema', history.cinema),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.chair, 'Seats', history.seats.join(', ')),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.attach_money, 'Total Price', 'RM${history.totalPrice.toStringAsFixed(2)}'),
                                                  ],
                                                ),
                                              ),
            
                                              const SizedBox(height: 16),
            
            // User details section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                  Text(
                    'User Information',
                                                              style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person, 'User Name', history.userName),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.email, 'Email', history.userEmail),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.perm_identity, 'User ID', history.userId),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Processing details section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isApproved ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing Information',
                                                              style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isApproved ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.schedule, 'Request Time', 
                    '${history.cancellationRequestTime.day}/${history.cancellationRequestTime.month}/${history.cancellationRequestTime.year} at ${history.cancellationRequestTime.hour}:${history.cancellationRequestTime.minute.toString().padLeft(2, '0')}'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.auto_awesome, 'System Decision', '${history.statusIcon} ${history.statusText}'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.info_outline, 'Reason', history.reasonText),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.account_balance_wallet, 'Refund Status', history.refundStatusText),
                ],
                          ),
                        ),
                      ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
          style: TextStyle(
            color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodCancellationHistoryCard(FoodCancellationHistory history) {
    final isApproved = history.systemDecision == 'auto_approved';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order ID and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant, color: Color(0xFF047857)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Order #${history.orderId}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isApproved ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isApproved ? Colors.green[300]! : Colors.orange[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        history.statusIcon,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        history.statusText,
                        style: TextStyle(
                          color: isApproved ? Colors.green[800] : Colors.orange[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Order details section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.confirmation_number, 'Order ID', history.orderId),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.restaurant_menu, 'Food Items', history.foodItemsDisplay),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.attach_money, 'Total Amount', 'RM${history.totalAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.schedule, 'Order Time', 
                    '${history.orderTime.day}/${history.orderTime.month}/${history.orderTime.year} at ${history.orderTime.hour}:${history.orderTime.minute.toString().padLeft(2, '0')}'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, 'Pickup Time', 
                    '${history.pickupTime.day}/${history.pickupTime.month}/${history.pickupTime.year} at ${history.pickupTime.hour}:${history.pickupTime.minute.toString().padLeft(2, '0')}'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User details section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person, 'User Name', history.userName),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.email, 'Email', history.userEmail),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.perm_identity, 'User ID', history.userId),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Processing details section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isApproved ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isApproved ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.schedule, 'Request Time', 
                    '${history.cancellationRequestTime.day}/${history.cancellationRequestTime.month}/${history.cancellationRequestTime.year} at ${history.cancellationRequestTime.hour}:${history.cancellationRequestTime.minute.toString().padLeft(2, '0')}'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.auto_awesome, 'System Decision', '${history.statusIcon} ${history.statusText}'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.info_outline, 'Reason', history.reasonText),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.account_balance_wallet, 'Refund Status', history.refundStatusText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 