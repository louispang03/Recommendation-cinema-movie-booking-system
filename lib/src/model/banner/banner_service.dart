import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'banner_movie.dart';

class BannerService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  static Future<List<BannerMovie>> searchMovies(String query) async {
    if (query.isEmpty) return [];
    
    final apiKey = dotenv.env['TMDB_API_KEY'];
    final response = await http.get(
      Uri.parse('$_baseUrl/search/movie?api_key=$apiKey&query=${Uri.encodeComponent(query)}'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['results'] as List)
          .map((movie) => BannerMovie.fromJson(movie))
          .toList();
    } else {
      throw Exception('Failed to search movies');
    }
  }

  static Future<List<BannerMovie>> fetchNowPlayingMovies() async {
    final apiKey = dotenv.env['TMDB_API_KEY'];
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/now_playing?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['results'] as List)
          .map((movie) => BannerMovie.fromJson(movie))
          .toList();
    } else {
      throw Exception('Failed to load now playing movies');
    }
  }

  static Future<List<BannerMovie>> fetchPopularMovies() async {
    final apiKey = dotenv.env['TMDB_API_KEY'];
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/popular?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['results'] as List)
          .map((movie) => BannerMovie.fromJson(movie))
          .toList();
    } else {
      throw Exception('Failed to load popular movies');
    }
  }
}