import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecommendationService {
  static const String baseUrl = 'http://10.10.29.156'; // Updated to current IP address
  static const List<String> fallbackUrls = [
    'http://10.10.29.156:3000',
    'http://172.16.61.211:3000', // Current computer IP
    'http://172.16.32.1:3000',   // Previous IP as fallback
    'http://localhost:3000',      // Localhost
    'http://127.0.0.1:3000',      // Loopback
    'http://172.16.61.211:8080',  // Try different port
    'http://172.16.32.1:8080',
    'http://10.10.29.156:8080',    // Previous IP with different port
    'http://172.16.61.211:5000'
    'http://10.10.29.156:5000'   // Try another common port
  ];
  
  // Try multiple URLs to connect to the recommendation server
  Future<http.Response?> _tryConnectToServer(String endpoint, Map<String, dynamic> body) async {
    for (String url in fallbackUrls) {
      try {
        print('[DEBUG] Trying to connect to: $url$endpoint');
        final response = await http.post(
          Uri.parse('$url$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(Duration(seconds: 10)); // Reduced timeout
        
        if (response.statusCode == 200) {
          print('[SUCCESS] Connected to: $url$endpoint');
          return response;
        }
      } catch (e) {
        print('[DEBUG] Failed to connect to $url$endpoint: $e');
        continue;
      }
    }
    print('[ERROR] All connection attempts failed');
    return null;
  }
  
  // Get recommendations for existing users
  Future<Map<String, dynamic>> getRecommendations({String? movieId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    try {
      // Get user's booking history from Flutter/Firebase
      final bookingHistory = await _getUserBookingHistory();
      print('📚 Booking history fetched: ${bookingHistory.length} bookings');
      print('📚 Sample booking data: $bookingHistory');
      
      // Try connecting to Python ML server first
      print('🔗 Attempting to connect to ML recommendation server...');
      
      final response = await _tryConnectToServer('/recommend', {
        'user_id': user.uid,
        'booking_history': bookingHistory,
        if (movieId != null) 'movie_id': movieId,
      });
      
      if (response != null && response.statusCode == 200) {
        print('✅ Connected to ML server successfully!');
        print('📦 Server response: ${response.body}');
        final result = jsonDecode(response.body);
        print('🎬 Parsed result: $result');
        return result;
      }
      
      // Fallback to mock data if server connection fails
      print('🎬 Server unavailable, using fallback logic based on your ${bookingHistory.length} bookings');
      
      // Check if user is new (no booking history) and return appropriate type
      if (bookingHistory.isEmpty) {
        return {
          'type': 'new_user',
          'message': 'No booking history found. Please set your preferences.',
          'available_genres': ['Action', 'Comedy', 'Drama', 'Horror', 'Romance', 'Sci-Fi', 'Thriller', 'Animation', 'Adventure', 'Crime']
        };
      }
      
      // For existing users, return basic fallback recommendations
      return {
        'type': 'existing_user_fallback',
        'recommendations': [
          {
            'id': 634649,
            'title': 'Spider-Man: No Way Home',
            'overview': 'Peter Parker is unmasked and no longer able to separate his normal life from the high-stakes of being a super-hero.',
            'poster_path': '/1g0dhYtq4irTY1GPXvft6k4YLjm.jpg',
            'vote_average': 8.1,
            'release_date': '2021-12-15',
            'recommendation_reason': 'Popular movie - server unavailable'
          },
          {
            'id': 438631,
            'title': 'Dune',
            'overview': 'Paul Atreides, a brilliant and gifted young man born into a great destiny beyond his understanding.',
            'poster_path': '/d5NXSklXo0qyIYkgV94XAgMIckC.jpg',
            'vote_average': 8.0,
            'release_date': '2021-09-15',
            'recommendation_reason': 'Highly rated movie - server unavailable'
          }
        ],
        'message': 'Showing popular movies (recommendation server unavailable)'
      };
    } catch (e) {
      print('Recommendation service error: $e');
      rethrow;
    }
  }
  
  // Get booking history using existing Flutter Firebase connection
  Future<List<Map<String, dynamic>>> _getUserBookingHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .orderBy('bookingDate', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'movieId': data['movieId'],
          'movieTitle': data['movieTitle'],
          'date': data['date'],
          'time': data['time'],
          'seats': data['seats'],
          'cinema': data['cinema'],
          'totalPrice': data['totalPrice'],
          'bookingDate': data['bookingDate'],
          'status': data['status'],
        };
      }).where((booking) => booking['status'] != 'cancelled').toList(); // Filter cancelled bookings in Dart instead of Firestore
    } catch (e) {
      print('Error fetching booking history: $e');
      return [];
    }
  }
  
  // Get recommendations for new users based on preferences
  Future<Map<String, dynamic>> getNewUserRecommendations({
    required List<String> preferredGenres,
    List<String>? preferredActors,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    try {
      print('🎬 Getting new user recommendations for genres: $preferredGenres');
      
      final response = await _tryConnectToServer('/recommend/new-user', {
        'user_id': user.uid,
        'preferred_genres': preferredGenres,
        'preferred_actors': preferredActors ?? [],
      });
      
      if (response != null && response.statusCode == 200) {
        print('✅ New user recommendations received from server!');
        return jsonDecode(response.body);
      }
      
      // If server unavailable, provide basic fallback
      print('🎬 Server unavailable, providing basic recommendations for: $preferredGenres');
      return _generateBasicFallbackRecommendations(preferredGenres, preferredActors);
    } catch (e) {
      print('❌ Error getting new user recommendations: $e');
      // Provide basic fallback recommendations
      return _generateBasicFallbackRecommendations(preferredGenres, preferredActors);
    }
  }

  // Generate basic fallback recommendations for new users when server is unavailable
  Map<String, dynamic> _generateBasicFallbackRecommendations(List<String> genres, List<String>? actors) {
    // Basic popular movies that work as fallback
    final fallbackMovies = [
      {
        'id': 634649,
        'title': 'Spider-Man: No Way Home',
        'overview': 'Peter Parker is unmasked and no longer able to separate his normal life from the high-stakes of being a super-hero.',
        'poster_path': '/1g0dhYtq4irTY1GPXvft6k4YLjm.jpg',
        'vote_average': 8.1,
        'release_date': '2021-12-15',
        'genres': ['Action', 'Adventure', 'Sci-Fi'],
        'recommendation_reason': 'Popular ${genres.isNotEmpty ? genres.first : 'Action'} movie (server unavailable)'
      },
      {
        'id': 438631,
        'title': 'Dune',
        'overview': 'Paul Atreides, a brilliant and gifted young man born into a great destiny beyond his understanding.',
        'poster_path': '/d5NXSklXo0qyIYkgV94XAgMIckC.jpg',
        'vote_average': 8.0,
        'release_date': '2021-09-15',
        'genres': ['Adventure', 'Drama', 'Sci-Fi'],
        'recommendation_reason': 'Highly rated ${genres.isNotEmpty ? genres.first : 'Adventure'} movie (server unavailable)'
      },
      {
        'id': 550988,
        'title': 'Free Guy',
        'overview': 'A bank teller called Guy realizes he is a background character in an open world video game.',
        'poster_path': '/xmbU4JTUm8rsdtn7Y3Fcm30GpeT.jpg',
        'vote_average': 7.8,
        'release_date': '2021-08-11',
        'genres': ['Action', 'Comedy', 'Adventure'],
        'recommendation_reason': 'Popular ${genres.isNotEmpty ? genres.first : 'Comedy'} movie (server unavailable)'
      }
    ];
    
    return {
      'type': 'new_user_fallback',
      'recommendations': fallbackMovies,
      'user_preferences': {
        'genres': genres,
        'actors': actors ?? [],
      },
      'message': 'Basic recommendations (server unavailable)'
    };
  }
  
  // Get available genres from server
  Future<List<String>> getAvailableGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl:3000/genres'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['genres']);
      } else {
        throw Exception('Failed to get genres: ${response.body}');
      }
    } catch (e) {
      print('Error fetching genres: $e');
      // Return default genres if server unavailable
      return ['Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 'Documentary', 'Drama', 'Family', 'Fantasy', 'History', 'Horror', 'Music', 'Mystery', 'Romance', 'Science Fiction', 'Thriller', 'War', 'Western'];
    }
  }
} 