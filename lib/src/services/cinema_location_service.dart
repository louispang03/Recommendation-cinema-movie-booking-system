import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class CinemaLocationService {
  // Google Places API configuration
  static const String _placesApiKey = '';
  static const String _placesBaseUrl = '';
  
  // Cinema search terms for Malaysian cinema chains - focused on the 3 main chains
  static const List<String> _cinemaSearchTerms = [
    'GSC cinema Malaysia',
    'Golden Screen Cinemas',
    'LFS cinema Malaysia', 
    'Lotus Five Star cinema',
    'mmCineplexes Malaysia',
    'MM Cineplexes',
    'mm cinemas Malaysia',
  ];

  // Comprehensive brand patterns for better detection
  static const Map<String, List<String>> _brandPatterns = {
    'GSC': [
      'gsc',
      'golden screen',
      'golden screen cinemas',
      'golden screen cinema',
    ],
    'LFS': [
      'lfs',
      'lotus five star',
      'lotus 5 star',
      'lotus cinema',
    ],
    'mmCineplexes': [
      'mmcineplexes',
      'mm cineplexes',
      'mm cinema',
      'mm cinemas',
      'mmcp',
    ],
  };

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Find cinemas using Google Places API - focused on GSC, LFS, and mmCineplexes
  Future<List<CinemaWithDistance>> findNearbyCinemas(Position userLocation, {int radius = 15000}) async {
    try {
      print('🔍 Searching for GSC, LFS, and mmCineplexes cinemas near ${userLocation.latitude}, ${userLocation.longitude}');
      
      Set<Cinema> allCinemas = {};
      
      // Search using Places Nearby Search for movie theaters
      final nearbyResults = await _searchNearbyMovieTheaters(userLocation, radius);
      allCinemas.addAll(nearbyResults);
      
      // Search for specific cinema brands using Text Search
      for (String searchTerm in _cinemaSearchTerms) {
        final textResults = await _searchCinemasByText(userLocation, searchTerm, radius);
        allCinemas.addAll(textResults);
      }
      
      // Filter to only include our target cinema brands
      final filteredCinemas = allCinemas.where((cinema) {
        final brand = cinema.brand.toLowerCase();
        return brand == 'gsc' || brand == 'lfs' || brand == 'mmcineplexes' || 
               cinema.name.toLowerCase().contains('gsc') ||
               cinema.name.toLowerCase().contains('lfs') ||
               cinema.name.toLowerCase().contains('lotus') ||
               cinema.name.toLowerCase().contains('golden screen') ||
               cinema.name.toLowerCase().contains('mm cinema') ||
               cinema.name.toLowerCase().contains('mmcineplexes');
      }).toSet();
      
      print('🎯 After filtering: ${filteredCinemas.length} cinemas from target brands');
      
      // Convert to CinemaWithDistance and calculate distances
      List<CinemaWithDistance> cinemasWithDistance = filteredCinemas.map((cinema) {
        double distance = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          cinema.latitude,
          cinema.longitude,
        );
        return CinemaWithDistance(cinema: cinema, distance: distance);
      }).toList();

      // Sort by distance and remove duplicates
      cinemasWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
      
      // Remove duplicates based on location proximity (within 50m for better accuracy)
      List<CinemaWithDistance> uniqueCinemas = [];
      for (var cinema in cinemasWithDistance) {
        bool isDuplicate = uniqueCinemas.any((existing) => 
          Geolocator.distanceBetween(
            existing.cinema.latitude, 
            existing.cinema.longitude,
            cinema.cinema.latitude, 
            cinema.cinema.longitude
          ) < 50
        );
        if (!isDuplicate) {
          uniqueCinemas.add(cinema);
        }
      }
      
      print('✅ Found ${uniqueCinemas.length} unique GSC, LFS, and mmCineplexes cinemas');
      
      // Group by brand for better results
      final Map<String, List<CinemaWithDistance>> groupedByBrand = {};
      for (var cinema in uniqueCinemas) {
        final brand = cinema.cinema.brand;
        if (!groupedByBrand.containsKey(brand)) {
          groupedByBrand[brand] = [];
        }
        groupedByBrand[brand]!.add(cinema);
      }
      
      print('📊 Results by brand:');
      groupedByBrand.forEach((brand, cinemas) {
        print('   $brand: ${cinemas.length} locations');
      });
      
      return uniqueCinemas.take(30).toList(); // Increased limit for better coverage
      
    } catch (e) {
      print('❌ Error finding cinemas: $e');
      throw Exception('Failed to find nearby cinemas: $e');
    }
  }

  // Search for movie theaters using Places Nearby Search
  Future<List<Cinema>> _searchNearbyMovieTheaters(Position location, int radius) async {
    final url = '$_placesBaseUrl/nearbysearch/json?'
        'location=${location.latitude},${location.longitude}&'
        'radius=$radius&'
        'type=movie_theater&'
        'key=$_placesApiKey';
    
    return await _makePlacesRequest(url, 'movie theaters');
  }

  // Search for cinemas using text search
  Future<List<Cinema>> _searchCinemasByText(Position location, String query, int radius) async {
    final url = '$_placesBaseUrl/textsearch/json?'
        'query=$query&'
        'location=${location.latitude},${location.longitude}&'
        'radius=$radius&'
        'key=$_placesApiKey';
    
    return await _makePlacesRequest(url, query);
  }

  // Make API request to Google Places
  Future<List<Cinema>> _makePlacesRequest(String url, String searchType) async {
    try {
      print('📡 Searching for: $searchType');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        print('❌ Places API error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        print('❌ Places API status: ${data['status']}');
        return [];
      }

      final results = data['results'] as List;
      print('📍 Found ${results.length} results for $searchType');
      
      return results.map<Cinema>((place) {
        return Cinema(
          name: place['name'] ?? 'Unknown Cinema',
          brand: _extractBrand(place['name'] ?? ''),
          address: place['formatted_address'] ?? place['vicinity'] ?? 'Address not available',
          latitude: place['geometry']['location']['lat'].toDouble(),
          longitude: place['geometry']['location']['lng'].toDouble(),
          phone: _getPhoneNumber(place),
          placeId: place['place_id'],
          rating: place['rating']?.toDouble(),
          isOpen: _getOpenStatus(place),
        );
      }).toList();
      
    } catch (e) {
      print('❌ Error in Places request: $e');
      return [];
    }
  }

  // Extract cinema brand from name
  String _extractBrand(String name) {
    final nameLower = name.toLowerCase();
    for (var brand in _brandPatterns.keys) {
      for (var pattern in _brandPatterns[brand]!) {
        if (nameLower.contains(pattern)) {
          return brand;
        }
      }
    }
    return 'Cinema'; // Generic brand
  }

  // Get phone number from place details
  String _getPhoneNumber(Map<String, dynamic> place) {
    return place['formatted_phone_number'] ?? 
           place['international_phone_number'] ?? 
           'Phone not available';
  }

  // Get open status
  bool? _getOpenStatus(Map<String, dynamic> place) {
    return place['opening_hours']?['open_now'];
  }

  // Filter cinemas by brand
  List<CinemaWithDistance> filterCinemasByBrand(List<CinemaWithDistance> cinemas, String brand) {
    if (brand == 'All') return cinemas;
    
    return cinemas.where((cinema) => 
      cinema.cinema.brand.toLowerCase() == brand.toLowerCase()
    ).toList();
  }

  // Get available brands from cinema list
  List<String> getAvailableBrands(List<CinemaWithDistance> cinemas) {
    Set<String> brands = cinemas.map((c) => c.cinema.brand).toSet();
    List<String> sortedBrands = brands.toList()..sort();
    return ['All', ...sortedBrands];
  }

  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters == 0) {
      return 'N/A';
    } else if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }
}

class Cinema {
  final String name;
  final String brand;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final String? placeId;
  final double? rating;
  final bool? isOpen;

  const Cinema({
    required this.name,
    required this.brand,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.placeId,
    this.rating,
    this.isOpen,
  });
}

class CinemaWithDistance {
  final Cinema cinema;
  final double distance; // in meters

  CinemaWithDistance({
    required this.cinema,
    required this.distance,
  });

  String get formattedDistance => CinemaLocationService.formatDistance(distance);
} 
