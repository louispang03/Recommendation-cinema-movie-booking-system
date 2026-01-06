// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner_movie.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BannerMovie _$BannerMovieFromJson(Map<String, dynamic> json) => BannerMovie(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      backdropPath: json['backdrop_path'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      releaseDate: json['release_date'] as String,
      isComingSoon: json['isComingSoon'] as bool? ?? false,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      genreIds: (json['genre_ids'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
      isFromTMDB: json['isFromTMDB'] as bool?,
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      categories: (json['categories'] as List<dynamic>?)?.map((e) => e as String).toList(),
      cinemaBrands: (json['cinemaBrands'] as List<dynamic>?)?.map((e) => e as String).toList(),
      showtimes: (json['showtimes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      imageUrl: json['imageUrl'] as String?,
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
      runtime: (json['runtime'] as num?)?.toInt(),
      originalLanguage: json['originalLanguage'] as String?,
      cast: (json['cast'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList(),
    );

Map<String, dynamic> _$BannerMovieToJson(BannerMovie instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'backdrop_path': instance.backdropPath,
      'overview': instance.overview,
      'poster_path': instance.posterPath,
      'release_date': instance.releaseDate,
      'isComingSoon': instance.isComingSoon,
      'vote_average': instance.voteAverage,
      'genre_ids': instance.genreIds,
      'isFromTMDB': instance.isFromTMDB,
      'tmdbId': instance.tmdbId,
      'categories': instance.categories,
      'cinemaBrands': instance.cinemaBrands,
      'showtimes': instance.showtimes,
      'imageUrl': instance.imageUrl,
      'genres': instance.genres,
      'runtime': instance.runtime,
      'originalLanguage': instance.originalLanguage,
      'cast': instance.cast,
    };
