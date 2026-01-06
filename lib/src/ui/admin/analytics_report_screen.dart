import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_cinema_app/res/color_app.dart';

class AnalyticsReportScreen extends StatefulWidget {
  const AnalyticsReportScreen({super.key});

  @override
  State<AnalyticsReportScreen> createState() => _AnalyticsReportScreenState();
}

class _AnalyticsReportScreenState extends State<AnalyticsReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};
  String _selectedPeriod = '7d'; // 7d, 30d, 1y

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() => _isLoading = true);

      final now = DateTime.now();
      DateTime startDate;
      
      switch (_selectedPeriod) {
        case '7d':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '1y':
          startDate = now.subtract(const Duration(days: 365));
          break;
        default:
          startDate = now.subtract(const Duration(days: 7)); // Default to 7 days
      }

      // Get all users and query their subcollections directly
      final usersSnapshot = await _firestore.collection('users').get();
      
      List<Map<String, dynamic>> allBookings = [];
      List<Map<String, dynamic>> allFoodOrders = [];
      List<Map<String, dynamic>> allCancellations = [];
      List<Map<String, dynamic>> allFoodCancellations = [];

      print('Found ${usersSnapshot.docs.length} users in database');

      for (var userDoc in usersSnapshot.docs) {
        try {
          // Get bookings for this user (without date filter first, then filter in code)
          final userBookings = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('bookings')
              .get();
          
          for (var bookingDoc in userBookings.docs) {
            final bookingData = bookingDoc.data();
            final bookingDateStr = bookingData['bookingDate'] as String?;
            
            if (bookingDateStr != null) {
              try {
                final bookingDate = DateTime.parse(bookingDateStr);
                if (bookingDate.isAfter(startDate) || bookingDate.isAtSameMomentAs(startDate)) {
                  allBookings.add({...bookingData, 'id': bookingDoc.id});
                }
              } catch (e) {
                print('Error parsing booking date: $bookingDateStr - $e');
              }
            }
          }

          // Get food orders for this user (without date filter first, then filter in code)
          final userFoodOrders = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('food_orders')
              .get();
          
          for (var orderDoc in userFoodOrders.docs) {
            final orderData = orderDoc.data();
            DateTime? orderDate;
            
            // Handle both Timestamp and String dates
            if (orderData['orderDate'] is Timestamp) {
              orderDate = (orderData['orderDate'] as Timestamp).toDate();
            } else if (orderData['createdAt'] is Timestamp) {
              orderDate = (orderData['createdAt'] as Timestamp).toDate();
            } else if (orderData['orderDate'] is String) {
              try {
                orderDate = DateTime.parse(orderData['orderDate'] as String);
              } catch (e) {
                print('Error parsing order date string: ${orderData['orderDate']} - $e');
              }
            } else if (orderData['createdAt'] is String) {
              try {
                orderDate = DateTime.parse(orderData['createdAt'] as String);
              } catch (e) {
                print('Error parsing createdAt string: ${orderData['createdAt']} - $e');
              }
            }
            
            if (orderDate != null) {
              if (orderDate.isAfter(startDate) || orderDate.isAtSameMomentAs(startDate)) {
                allFoodOrders.add({...orderData, 'id': orderDoc.id});
              }
            }
          }

          print('User ${userDoc.id}: ${allBookings.length} filtered bookings, ${allFoodOrders.length} filtered food orders');
        } catch (userError) {
          print('Error loading data for user ${userDoc.id}: $userError');
        }
      }

      // Get cancellation data from the main collections
      try {
        // Get movie booking cancellations
        final cancellationsSnapshot = await _firestore
            .collection('cancellation_history')
            .get();
        
        for (var cancellationDoc in cancellationsSnapshot.docs) {
          final cancellationData = cancellationDoc.data();
          final cancellationDateStr = cancellationData['cancellationRequestTime'] as String?;
          
          if (cancellationDateStr != null) {
            try {
              final cancellationDate = DateTime.parse(cancellationDateStr);
              if (cancellationDate.isAfter(startDate) || cancellationDate.isAtSameMomentAs(startDate)) {
                allCancellations.add({...cancellationData, 'id': cancellationDoc.id});
              }
            } catch (e) {
              print('Error parsing cancellation date: $cancellationDateStr - $e');
            }
          }
        }

        // Get food order cancellations
        final foodCancellationsSnapshot = await _firestore
            .collection('food_cancellation_history')
          .get();
        
        for (var foodCancellationDoc in foodCancellationsSnapshot.docs) {
          final foodCancellationData = foodCancellationDoc.data();
          final foodCancellationDateStr = foodCancellationData['cancellationRequestTime'] as String?;
          
          if (foodCancellationDateStr != null) {
            try {
              final foodCancellationDate = DateTime.parse(foodCancellationDateStr);
              if (foodCancellationDate.isAfter(startDate) || foodCancellationDate.isAtSameMomentAs(startDate)) {
                allFoodCancellations.add({...foodCancellationData, 'id': foodCancellationDoc.id});
              }
            } catch (e) {
              print('Error parsing food cancellation date: $foodCancellationDateStr - $e');
            }
          }
        }

        print('Found ${allCancellations.length} movie cancellations, ${allFoodCancellations.length} food cancellations');
      } catch (cancellationError) {
        print('Error loading cancellation data: $cancellationError');
      }

      // Process the collected data
      final movieBookings = allBookings;
      final foodOrders = allFoodOrders;
      final cancellations = allCancellations;
      final foodCancellations = allFoodCancellations;

      // Debug logging
      print('📊 Analytics Debug:');
      print('Movie bookings found: ${movieBookings.length}');
      print('Food orders found: ${foodOrders.length}');
      print('Cancellations found: ${cancellations.length}');
      print('Food cancellations found: ${foodCancellations.length}');
      print('Date range: ${startDate.toIso8601String()} to ${now.toIso8601String()}');
      
      // Debug sample data
      if (movieBookings.isNotEmpty) {
        print('Sample booking: ${movieBookings.first}');
        print('Sample booking date: ${movieBookings.first['bookingDate']}');
      }
      if (foodOrders.isNotEmpty) {
        print('Sample food order: ${foodOrders.first}');
        print('Sample food order date: ${foodOrders.first['orderDate'] ?? foodOrders.first['createdAt']}');
        print('Sample food order total: ${foodOrders.first['total']}');
      }
      if (cancellations.isNotEmpty) {
        print('Sample cancellation: ${cancellations.first}');
        print('Sample cancellation date: ${cancellations.first['cancellationRequestTime']}');
        print('Sample refund amount: ${cancellations.first['refundAmount']}');
      }

      // Calculate key metrics
      final totalMovieBookings = movieBookings.length;
      final totalFoodOrders = foodOrders.length;
      
      double totalMovieRevenue = 0;
      double totalFoodRevenue = 0;
      double totalRefunds = 0;

      // Movie revenue
      for (var booking in movieBookings) {
        if (booking['totalPrice'] != null) {
          totalMovieRevenue += (booking['totalPrice'] as num).toDouble();
        }
      }

      // Food revenue
      for (var order in foodOrders) {
        if (order['total'] != null) {
          totalFoodRevenue += (order['total'] as num).toDouble();
        }
      }

      // Refunds from cancellations
      for (var cancellation in cancellations) {
        if (cancellation['refundAmount'] != null) {
          totalRefunds += (cancellation['refundAmount'] as num).toDouble();
        }
      }

      for (var cancellation in foodCancellations) {
        if (cancellation['refundAmount'] != null) {
          totalRefunds += (cancellation['refundAmount'] as num).toDouble();
        }
      }

      // Revenue by cinema brand (extract brand from cinema location)
      final revenueByCinema = <String, double>{};
      for (var booking in movieBookings) {
        final cinema = booking['cinema'] ?? 'Unknown';
        final price = (booking['totalPrice'] as num?)?.toDouble() ?? 0.0;
        
        // Extract cinema brand from location (e.g., "GSC 1Utama" -> "GSC")
        String cinemaBrand = cinema;
        if (cinema.contains('GSC')) {
          cinemaBrand = 'GSC';
        } else if (cinema.contains('LFS')) {
          cinemaBrand = 'LFS';
        } else if (cinema.contains('mmCineplexes')) {
          cinemaBrand = 'mmCineplexes';
        } else if (cinema.contains('TGV')) {
          cinemaBrand = 'TGV';
        } else if (cinema.contains('MBO')) {
          cinemaBrand = 'MBO';
        }
        
        revenueByCinema[cinemaBrand] = (revenueByCinema[cinemaBrand] ?? 0.0) + price;
      }

      // Debug cinema brand extraction
      print('Cinema brand revenue: $revenueByCinema');

      // Popular showtimes
      final showtimeCounts = <String, int>{};
      for (var booking in movieBookings) {
        final time = booking['time'] ?? 'Unknown';
        showtimeCounts[time] = (showtimeCounts[time] ?? 0) + 1;
      }

      // Popular food items
      final foodItemCounts = <String, int>{};
      for (var order in foodOrders) {
        final items = order['items'] as List? ?? [];
        for (var item in items) {
          final title = item['title'] ?? 'Unknown';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          foodItemCounts[title] = (foodItemCounts[title] ?? 0) + quantity;
        }
      }

      // Popular movies (most booked movies)
      final movieBookingCounts = <String, int>{};
      for (var booking in movieBookings) {
        final movieTitle = booking['movieTitle'] ?? 'Unknown Movie';
        movieBookingCounts[movieTitle] = (movieBookingCounts[movieTitle] ?? 0) + 1;
      }

      // Daily revenue trend based on selected period
      final dailyRevenue = <String, double>{};
      int daysToShow = 7; // Default to 7 days
      
      switch (_selectedPeriod) {
        case '7d':
          daysToShow = 7;
          break;
        case '30d':
          daysToShow = 30;
          break;
        case '1y':
          daysToShow = 12; // Show monthly data for yearly view
          break;
      }
      
      if (_selectedPeriod == '1y') {
        // For yearly view, show monthly data
        for (int i = 11; i >= 0; i--) {
          final date = now.subtract(Duration(days: i * 30));
          final dateStr = '${date.month}/${date.year}';
          dailyRevenue[dateStr] = 0.0;
        }
      } else {
        // For daily view (7d or 30d)
        for (int i = daysToShow - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = '${date.day}/${date.month}';
        dailyRevenue[dateStr] = 0.0;
        }
      }

      for (var booking in movieBookings) {
        try {
          DateTime bookingDate;
          if (booking['bookingDate'] is Timestamp) {
            bookingDate = (booking['bookingDate'] as Timestamp).toDate();
          } else {
            bookingDate = DateTime.parse(booking['bookingDate'] as String);
          }
          
          String dateStr;
          if (_selectedPeriod == '1y') {
            // For yearly view, group by month
            dateStr = '${bookingDate.month}/${bookingDate.year}';
          } else {
            // For daily view, group by day
            dateStr = '${bookingDate.day}/${bookingDate.month}';
          }
          
          if (dailyRevenue.containsKey(dateStr)) {
            dailyRevenue[dateStr] = (dailyRevenue[dateStr] ?? 0.0) + 
                ((booking['totalPrice'] as num?)?.toDouble() ?? 0.0);
          }
        } catch (e) {
          print('Error processing booking date: ${booking['bookingDate']} - $e');
        }
      }

      for (var order in foodOrders) {
        try {
          DateTime? orderDate;
          
          // Handle both Timestamp and String dates for food orders
          if (order['orderDate'] is Timestamp) {
            orderDate = (order['orderDate'] as Timestamp).toDate();
          } else if (order['createdAt'] is Timestamp) {
            orderDate = (order['createdAt'] as Timestamp).toDate();
          } else if (order['orderDate'] is String) {
            orderDate = DateTime.parse(order['orderDate'] as String);
          } else if (order['createdAt'] is String) {
            orderDate = DateTime.parse(order['createdAt'] as String);
          } else if (order['orderTime'] is String) {
            orderDate = DateTime.parse(order['orderTime'] as String);
          }
          
          if (orderDate != null) {
            String dateStr;
            if (_selectedPeriod == '1y') {
              // For yearly view, group by month
              dateStr = '${orderDate.month}/${orderDate.year}';
            } else {
              // For daily view, group by day
              dateStr = '${orderDate.day}/${orderDate.month}';
            }
            
            if (dailyRevenue.containsKey(dateStr)) {
              dailyRevenue[dateStr] = (dailyRevenue[dateStr] ?? 0.0) + 
                  ((order['total'] as num?)?.toDouble() ?? 0.0);
            }
          }
        } catch (e) {
          print('Error processing food order date: ${order['orderDate'] ?? order['createdAt']} - $e');
        }
      }

      // Cancellation rates
      final totalCancellations = cancellations.length + foodCancellations.length;
      final totalOrders = totalMovieBookings + totalFoodOrders;
      final cancellationRate = totalOrders > 0 ? (totalCancellations / totalOrders) * 100 : 0.0;

      // Average order values
      final avgMovieOrderValue = totalMovieBookings > 0 ? totalMovieRevenue / totalMovieBookings : 0.0;
      final avgFoodOrderValue = totalFoodOrders > 0 ? totalFoodRevenue / totalFoodOrders : 0.0;

      // Check if we have any data, if not show sample data for demo
      final hasData = totalMovieBookings > 0 || totalFoodOrders > 0;

      setState(() {
        if (hasData) {
          _analytics = {
            'period': _selectedPeriod,
            'totalMovieBookings': totalMovieBookings,
            'totalFoodOrders': totalFoodOrders,
            'totalMovieRevenue': totalMovieRevenue,
            'totalFoodRevenue': totalFoodRevenue,
            'totalRefunds': totalRefunds,
            'netRevenue': totalMovieRevenue + totalFoodRevenue - totalRefunds,
            'revenueByCinema': revenueByCinema,
            'showtimeCounts': showtimeCounts,
            'foodItemCounts': foodItemCounts,
            'movieBookingCounts': movieBookingCounts,
            'dailyRevenue': dailyRevenue,
            'cancellationRate': cancellationRate,
            'avgMovieOrderValue': avgMovieOrderValue,
            'avgFoodOrderValue': avgFoodOrderValue,
            'totalOrders': totalOrders,
            'totalCancellations': totalCancellations,
          };
        } else {
          // Show sample data for demo purposes
        _analytics = {
            'period': _selectedPeriod,
            'totalMovieBookings': 0,
            'totalFoodOrders': 0,
            'totalMovieRevenue': 0.0,
            'totalFoodRevenue': 0.0,
            'totalRefunds': 0.0,
            'netRevenue': 0.0,
            'revenueByCinema': <String, double>{},
            'showtimeCounts': <String, int>{},
            'foodItemCounts': <String, int>{},
            'movieBookingCounts': <String, int>{},
            'dailyRevenue': <String, double>{},
            'cancellationRate': 0.0,
            'avgMovieOrderValue': 0.0,
            'avgFoodOrderValue': 0.0,
            'totalOrders': 0,
            'totalCancellations': 0,
            'isSampleData': true,
          };
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          // Sticky Header
          SliverAppBar(
        title: const Text(
              'Analytics',
          style: TextStyle(
            color: Color(0xFF047857),
                fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF9FAFB),
        iconTheme: const IconThemeData(color: Color(0xFF047857)),
        elevation: 0,
            floating: true,
            pinned: true,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  setState(() {
                    _selectedPeriod = value;
                  });
                  _loadAnalytics();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: '7d', child: Text('Last 7 Days')),
                  const PopupMenuItem(value: '30d', child: Text('Last 30 Days')),
                  const PopupMenuItem(value: '1y', child: Text('Last Year')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: ColorApp.primaryDarkColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _getPeriodText(_selectedPeriod),
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  if (_analytics['isSampleData'] == true) ...[
                    _buildNoDataCard(),
                    const SizedBox(height: 24),
                  ],
                  _buildKeyMetricsCard(),
                  const SizedBox(height: 24),
                  _buildRevenueTrendCard(),
                  const SizedBox(height: 24),
                  _buildAnalyticsGrid(),
                  const SizedBox(height: 24),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodText(String period) {
    switch (period) {
      case '7d': return 'Last 7 Days';
      case '30d': return 'Last 30 Days';
      case '1y': return 'Last Year';
      default: return 'Last 7 Days';
    }
  }


  Widget _buildNoDataCard() {
    return Card(
      color: Colors.orange[50],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.orange[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No bookings or orders found for the selected period. Data will appear here once users start making bookings and orders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 16),
                                Container(
              padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                  Text(
                    'To see analytics data:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                                        ),
                                      ),
                  const SizedBox(height: 8),
                                      Text(
                    '• Make some movie bookings as a user\n• Place food orders\n• Try different time periods\n• Check if data exists in Firestore',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
    );
  }

  Widget _buildKeyMetricsCard() {
    return Card(
                              color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
              'Key Metrics',
                                        style: TextStyle(
                color: Color(0xFF047857),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Revenue',
                    'RM${(_analytics['netRevenue'] ?? 0).toStringAsFixed(0)}',
                    Icons.attach_money,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    'Bookings',
                    '${_analytics['totalMovieBookings'] ?? 0}',
                    Icons.movie,
                    const Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Food Orders',
                    '${_analytics['totalFoodOrders'] ?? 0}',
                    Icons.restaurant,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    'Cancel Rate',
                    '${(_analytics['cancellationRate'] ?? 0).toStringAsFixed(1)}%',
                    Icons.cancel,
                    const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTrendCard() {
    final revenueByCinema = _analytics['revenueByCinema'] as Map<String, double>? ?? {};
    final revenueData = revenueByCinema.entries.toList();
    
    // Calculate total revenue for percentage calculations
    final totalRevenue = revenueData.fold(0.0, (sum, entry) => sum + entry.value);
    
    // Define colors for pie chart segments
    final colors = [
      const Color(0xFF10B981), // Green
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF84CC16), // Lime
      const Color(0xFFF97316), // Orange
    ];

    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Distribution by Cinema Brand',
              style: TextStyle(
                color: Color(0xFF047857),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: revenueData.isEmpty || totalRevenue == 0
                  ? const Center(
                      child: Text(
                        'No revenue data available',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // Pie Chart
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: revenueData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final data = entry.value;
                                final percentage = (data.value / totalRevenue) * 100;
                                
                                return PieChartSectionData(
                                  color: colors[index % colors.length],
                                  value: data.value,
                                  title: '${percentage.toStringAsFixed(1)}%',
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Legend
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: revenueData.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              final percentage = (data.value / totalRevenue) * 100;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: colors[index % colors.length],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data.key,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'RM${data.value.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            ),
                          ),
                        ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsGrid() {
    return _buildCombinedAnalyticsCard();
  }

  Widget _buildCombinedAnalyticsCard() {
    final revenueByCinema = _analytics['revenueByCinema'] as Map<String, double>? ?? {};
    final sortedCinemas = revenueByCinema.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final showtimeCounts = _analytics['showtimeCounts'] as Map<String, int>? ?? {};
    final sortedShowtimes = showtimeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final foodItemCounts = _analytics['foodItemCounts'] as Map<String, int>? ?? {};
    final sortedFoodItems = foodItemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final movieBookingCounts = _analytics['movieBookingCounts'] as Map<String, int>? ?? {};
    final sortedMovies = movieBookingCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cancellationRate = _analytics['cancellationRate'] ?? 0.0;
    final totalCancellations = _analytics['totalCancellations'] ?? 0;
    final totalRefunds = _analytics['totalRefunds'] ?? 0.0;

    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Insights',
              style: TextStyle(
                color: Color(0xFF047857),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            
            // Popular Movies Section
            _buildInsightSection(
              'Popular Movies',
              Icons.movie,
              const Color(0xFF8B5CF6),
              sortedMovies.isEmpty
                  ? const Text('No data', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : Column(
                      children: sortedMovies.take(3).map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B5CF6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${entry.value} bookings',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Cancellations Section
            _buildInsightSection(
              'Cancellations',
              Icons.cancel,
              const Color(0xFFEF4444),
              Column(
                children: [
                  _buildInfoRow('Cancel Rate', '${cancellationRate.toStringAsFixed(1)}%'),
                  const SizedBox(height: 4),
                  _buildInfoRow('Total Cancels', '$totalCancellations'),
                  const SizedBox(height: 4),
                  _buildInfoRow('Refunds', 'RM${totalRefunds.toStringAsFixed(0)}'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Popular Times Section
            _buildInsightSection(
              'Popular Times',
              Icons.schedule,
              const Color(0xFF3B82F6),
              sortedShowtimes.isEmpty
                  ? const Text('No data', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : Column(
                      children: sortedShowtimes.take(3).map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  entry.key,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                                Text(
                              '${entry.value}',
                                  style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                        ),
                      )).toList(),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Popular Food Section
            _buildInsightSection(
              'Popular Food',
              Icons.restaurant,
              const Color(0xFFF59E0B),
              sortedFoodItems.isEmpty
                  ? const Text('No data', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : Column(
                      children: sortedFoodItems.take(3).map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightSection(String title, IconData icon, Color color, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }


  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
} 