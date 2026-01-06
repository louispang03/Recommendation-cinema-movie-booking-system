import 'package:json_annotation/json_annotation.dart';

part 'banner_movie.g.dart';

@JsonSerializable()
class BannerMovie {
  final int id;  // Added movie ID
  final String title;
  @JsonKey(name: 'backdrop_path')  // Matches TMDB's JSON key
  final String? backdropPath;  // Nullable as some movies might not have backdrop
  final String? overview;  // Added for movie description
  @JsonKey(name: 'poster_path')
  final String? posterPath;  // Added for poster image
  @JsonKey(name: 'release_date')
  final String releaseDate;  // Added release date field
  final bool isComingSoon;  // Added field to identify coming soon movies
  @JsonKey(name: 'vote_average')
  final double? voteAverage;  // Added for movie rating
  @JsonKey(name: 'genre_ids')
  final List<int>? genreIds;  // Added for movie genres
  final bool? isFromTMDB;  // Added to identify TMDB movies
  final int? tmdbId;  // Added to store original TMDB ID
  final List<String>? categories;  // Added for movie categories (banner, coming_soon, popular, now_playing)
  final List<String>? cinemaBrands;  // Added for cinema brands that show this movie
  final Map<String, List<String>>? showtimes;  // Added for showtimes per cinema brand
  final String? imageUrl;  // Added for uploaded image URL
  final List<String>? genres;  // Added for genre names
  final int? runtime;  // Added for movie duration in minutes
  final String? originalLanguage;  // Added for original language
  final List<Map<String, dynamic>>? cast;  // Added for cast information

  BannerMovie({
    required this.id,
    required this.title,
    this.backdropPath,
    this.overview,
    this.posterPath,
    required this.releaseDate,
    this.isComingSoon = false,  // Default to false, will be determined by categories
    this.voteAverage,
    this.genreIds,
    this.isFromTMDB = false,
    this.tmdbId,
    this.categories,
    this.cinemaBrands,
    this.showtimes,
    this.imageUrl,
    this.genres,
    this.runtime,
    this.originalLanguage,
    this.cast,
  });

  factory BannerMovie.fromJson(Map<String, dynamic> json) => 
      _$BannerMovieFromJson(json);

  Map<String, dynamic> toJson() => _$BannerMovieToJson(this);

  // Full image URL getters
  String get backdropUrl => backdropPath != null 
      ? backdropPath!.startsWith('http') 
          ? backdropPath! 
          : 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : '';

  String get posterUrl => posterPath != null
      ? posterPath!.startsWith('http') 
          ? posterPath!
          : 'https://image.tmdb.org/t/p/w500$posterPath'
      : '';

  // Helper method to check if this is a coming soon movie
  bool get isComingSoonMovie => categories?.contains('coming_soon') ?? isComingSoon;

  // Helper method to determine if movie is bookable
  bool get isBookable => !isComingSoonMovie;

  @override
  String toString() {
    return 'BannerMovie{id: $id, title: $title, isComingSoon: $isComingSoon}';
  }
}