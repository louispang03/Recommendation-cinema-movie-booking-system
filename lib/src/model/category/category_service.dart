import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'category.dart';

class CategoryService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  static Future<List<Category>> fetchMovieGenres() async {
    final apiKey = dotenv.env['TMDB_API_KEY'];
    final response = await http.get(
      Uri.parse('$_baseUrl/genre/movie/list?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['genres'] as List)
          .map((genre) => Category(
                id: genre['id'],
                name: genre['name'],
                backdropPath: _getRandomBackdropForGenre(genre['id']),
              ))
          .toList();
    } else {
      throw Exception('Failed to load movie genres');
    }
  }

  // Helper function to get example images for genres
  static String? _getRandomBackdropForGenre(int genreId) {
    final genreImages = {
      28: '/bOGkgRGdhrBYJSLpXaxhXVstddV.jpg', // Action
      12: '/Adrip2Jqzw56KeuV2nAxucKMNXA.jpg', // Adventure
      16: '/7WJjFviFBffEJvkAms4uWwbcVUk.jpg', // Animation
      35: '/a7fDvMjetO73q7kfiD8K6H5QQJw.jpg', // Comedy
      80: '/pIkRyD18kl4FhoCNQuWxWu5cBLM.jpg', // Crime
      18: '/xBHvZcjRiWyobQ9kxBhO6B2dtRI.jpg', // Drama
    };
    return genreImages[genreId];
  }
}