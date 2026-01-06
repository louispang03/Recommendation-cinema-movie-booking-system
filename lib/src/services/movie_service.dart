import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';

class MovieService {
  static const String baseUrl = 'https://api.themoviedb.org/3';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? 'b30842ad71c84c6e4f4928037489d1e2';
  
  Future<Map<String, dynamic>> getPopularMovies() async {
    try {
      print('[MovieService] Fetching popular movies...');
      final response = await http.get(
        Uri.parse('$baseUrl/movie/popular?api_key=$_apiKey'),
      );
      
      print('[MovieService] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[MovieService] Successfully fetched ${data['results']?.length ?? 0} movies');
        return data;
      } else {
        print('[MovieService] Error response: ${response.body}');
        throw Exception('Failed to load popular movies: ${response.statusCode}');
      }
    } catch (e) {
      print('[MovieService] Exception in getPopularMovies: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getNowPlayingMovies() async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/now_playing?api_key=$_apiKey'),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load now playing movies');
    }
  }
  
  Future<Map<String, dynamic>> getUpcomingMovies() async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/upcoming?api_key=$_apiKey'),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load upcoming movies');
    }
  }
  
  Future<Map<String, dynamic>> getTopRatedMovies() async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/top_rated?api_key=$_apiKey'),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load top rated movies');
    }
  }
  
  Future<Map<String, dynamic>> getGenres() async {
    final response = await http.get(
      Uri.parse('$baseUrl/genre/movie/list?api_key=$_apiKey'),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load genres');
    }
  }
  
  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/$movieId?api_key=$_apiKey&append_to_response=credits'),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load movie details');
    }
  }
  
  Future<Map<String, dynamic>> searchMovies(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/search/movie?api_key=$_apiKey&query=$query'),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to search movies');
    }
  }
  
  Future<Map<String, dynamic>> getMoviesByGenre(int genreId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/discover/movie?api_key=$_apiKey&with_genres=$genreId&sort_by=popularity.desc'),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load movies by genre');
    }
  }
  
  Future<List<BannerMovie>> getFirestoreMovies() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('movies').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return BannerMovie.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching Firestore movies: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> discoverMovies({
    List<int>? genreIds,
    String? language,
    double? minRating,
    String? sortBy,
    int page = 1,
  }) async {
    var url = '$baseUrl/discover/movie?api_key=$_apiKey&page=$page';

    if (genreIds != null && genreIds.isNotEmpty) {
      url += '&with_genres=${genreIds.join(",")}';
    }
    if (language != null && language.isNotEmpty) {
      url += '&language=$language&with_original_language=$language';
    }
    if (minRating != null && minRating > 0) {
      url += '&vote_average.gte=${minRating.toStringAsFixed(1)}';
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      url += '&sort_by=$sortBy';
    }
    
    print('Discover API URL: $url');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
       print('Failed to load discover movies: ${response.statusCode}');
       print('Response body: ${response.body}');
      throw Exception('Failed to load discovered movies (Status code: ${response.statusCode})');
    }
  }
} 