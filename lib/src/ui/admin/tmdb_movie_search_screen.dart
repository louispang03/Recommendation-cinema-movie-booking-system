import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/services/movie_service.dart';
import 'package:fyp_cinema_app/src/services/admin_service.dart';
import 'package:fyp_cinema_app/src/services/chat_service.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';

class TMDBMovieSearchScreen extends StatefulWidget {
  const TMDBMovieSearchScreen({super.key});

  @override
  State<TMDBMovieSearchScreen> createState() => _TMDBMovieSearchScreenState();
}

class _TMDBMovieSearchScreenState extends State<TMDBMovieSearchScreen> {
  final MovieService _movieService = MovieService();
  final AdminService _adminService = AdminService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _releaseDateController = TextEditingController();
  
  List<dynamic> _searchResults = [];
  List<dynamic> _latestMovies = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isLoadingLatest = false;
  Set<int> _addedMovieIds = {}; // Track which movies have been added
  
  // Category selection for TMDB movies
  List<String> _selectedCategories = [];
  final List<String> _categories = ['banner', 'coming_soon', 'popular', 'now_playing'];
  
  // Cinema and time selection
  List<String> _selectedCinemaBrands = [];
  final List<String> _cinemaBrands = ['LFS', 'GSC', 'mmCineplexes'];
  final List<String> _timeSlots = ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM'];
  Map<String, List<String>> _showtimes = {};

  @override
  void initState() {
    super.initState();
    _loadLatestMovies();
    _loadAddedMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _releaseDateController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestMovies() async {
    setState(() {
      _isLoadingLatest = true;
    });

    try {
      // Load movies from multiple categories for more options
      final nowPlayingResponse = await _movieService.getNowPlayingMovies();
      final popularResponse = await _movieService.getPopularMovies();
      final topRatedResponse = await _movieService.getTopRatedMovies();
      final upcomingResponse = await _movieService.getUpcomingMovies();
      
      final nowPlayingMovies = nowPlayingResponse['results'] ?? [];
      final popularMovies = popularResponse['results'] ?? [];
      final topRatedMovies = topRatedResponse['results'] ?? [];
      final upcomingMovies = upcomingResponse['results'] ?? [];
      
      // Combine all movies for more variety
      final allMovies = [
        ...nowPlayingMovies,
        ...popularMovies,
        ...topRatedMovies,
        ...upcomingMovies,
      ];
      
      final uniqueMovies = <Map<String, dynamic>>[];
      final seenIds = <int>{};
      
      for (var movie in allMovies) {
        if (movie['id'] != null && !seenIds.contains(movie['id'])) {
          uniqueMovies.add(movie);
          seenIds.add(movie['id']);
        }
      }
      
      // Sort by release date (latest first) and take more movies (50 instead of 20)
      uniqueMovies.sort((a, b) {
        final dateAStr = a['release_date'] as String? ?? '';
        final dateBStr = b['release_date'] as String? ?? '';
        
        // Handle empty dates by putting them at the end
        if (dateAStr.isEmpty && dateBStr.isEmpty) return 0;
        if (dateAStr.isEmpty) return 1;
        if (dateBStr.isEmpty) return -1;
        
        try {
          // Parse dates for proper chronological comparison
          final dateA = DateTime.parse(dateAStr);
          final dateB = DateTime.parse(dateBStr);
          
          // Compare dates (latest first)
          return dateB.compareTo(dateA);
        } catch (e) {
          // If date parsing fails, fall back to string comparison
          return dateBStr.compareTo(dateAStr);
        }
      });
      
      setState(() {
        _latestMovies = uniqueMovies.take(50).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading latest movies: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingLatest = false;
      });
    }
  }

  Future<void> _loadAddedMovies() async {
    try {
      final movies = await _adminService.getAllMovies();
      final addedIds = movies
          .where((movie) => (movie.isFromTMDB ?? false) && movie.tmdbId != null)
          .map((movie) => movie.tmdbId!)
          .toSet();
      
      setState(() {
        _addedMovieIds = addedIds;
      });
    } catch (e) {
      print('Error loading added movies: $e');
    }
  }

  List<String> _getGenreNames(List<int> genreIds) {
    const genreMap = {
      28: 'Action',
      12: 'Adventure',
      16: 'Animation',
      35: 'Comedy',
      80: 'Crime',
      99: 'Documentary',
      18: 'Drama',
      10751: 'Family',
      14: 'Fantasy',
      36: 'History',
      27: 'Horror',
      10402: 'Music',
      9648: 'Mystery',
      10749: 'Romance',
      878: 'Science Fiction',
      10770: 'TV Movie',
      53: 'Thriller',
      10752: 'War',
      37: 'Western',
    };
    
    return genreIds.map((id) => genreMap[id] ?? 'Unknown').toList();
  }

  List<String> _getGenreNamesFromDetails(List<dynamic> genres) {
    if (genres.isEmpty) return [];
    
    try {
      return genres.map((genre) {
        if (genre is Map<String, dynamic> && genre['name'] != null) {
          return genre['name'] as String;
        }
        return 'Unknown';
      }).toList();
    } catch (e) {
      print('Error parsing genres: $e');
      return ['Unknown'];
    }
  }

  List<Map<String, dynamic>>? _getCastFromDetails(dynamic castData) {
    if (castData == null) return null;
    
    try {
      if (castData is List) {
        return castData.map((actor) {
          if (actor is Map<String, dynamic>) {
            return actor;
          }
          return <String, dynamic>{};
        }).toList();
      }
      return null;
    } catch (e) {
      print('Error parsing cast: $e');
      return null;
    }
  }

  Future<void> _selectReleaseDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF047857),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _releaseDateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _searchMovies(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _movieService.searchMovies(query);
      setState(() {
        _searchResults = results['results'] ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching movies: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addMovieToDatabase(Map<String, dynamic> tmdbMovie) async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category to determine where this movie will appear on the homepage'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Check if coming soon is selected and release date is required
    final isComingSoonSelected = _selectedCategories.contains('coming_soon');
    if (isComingSoonSelected && _releaseDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a release date for Coming Soon movies'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Check if cinema selection is required (not for coming soon only)
    final isComingSoonOnly = _selectedCategories.length == 1 && _selectedCategories.contains('coming_soon');
    if (!isComingSoonOnly && _selectedCinemaBrands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one cinema brand for bookable movies'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Fetching complete details for ${tmdbMovie['title']}...',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          duration: const Duration(seconds: 3),
        ),
      );

      // Fetch complete movie details from TMDB API
      final completeDetails = await _movieService.getMovieDetails(tmdbMovie['id']);
      print('Complete details fetched: ${completeDetails.keys}');
      
      // Convert TMDB movie to BannerMovie format with complete details
      final bannerMovie = BannerMovie(
        id: tmdbMovie['id'],
        title: tmdbMovie['title'],
        overview: tmdbMovie['overview'] ?? '',
        releaseDate: isComingSoonSelected ? _releaseDateController.text.trim() : (tmdbMovie['release_date'] ?? ''),
        voteAverage: (tmdbMovie['vote_average'] ?? 0.0).toDouble(),
        posterPath: tmdbMovie['poster_path'],
        backdropPath: tmdbMovie['backdrop_path'],
        genreIds: List<int>.from(tmdbMovie['genre_ids'] ?? []),
        isFromTMDB: true,
        tmdbId: tmdbMovie['id'],
        isComingSoon: _selectedCategories.contains('coming_soon'),
        categories: _selectedCategories,
        cinemaBrands: isComingSoonOnly ? [] : _selectedCinemaBrands,
        showtimes: isComingSoonOnly ? {} : _showtimes,
        // Add new fields for detail screen from complete details
        genres: _getGenreNamesFromDetails(completeDetails['genres'] ?? []),
        runtime: completeDetails['runtime'] is int ? completeDetails['runtime'] : null,
        originalLanguage: completeDetails['original_language'] is String ? completeDetails['original_language'] : null,
        cast: _getCastFromDetails(completeDetails['credits']?['cast']),
      );

      print('BannerMovie created successfully: ${bannerMovie.title}');
      print('Genres: ${bannerMovie.genres}');
      print('Runtime: ${bannerMovie.runtime}');
      print('Language: ${bannerMovie.originalLanguage}');
      print('Cast count: ${bannerMovie.cast?.length ?? 0}');

      await _adminService.addMovie(bannerMovie);
      
      // Refresh chat service with new movie data
      try {
        await _chatService.refreshMovieData();
        print('Chat service refreshed with new movie: ${tmdbMovie['title']}');
      } catch (e) {
        print('Error refreshing chat service: $e');
        // Don't show error to user as this is a background operation
      }
      
      // Add movie ID to the added set
      setState(() {
        _addedMovieIds.add(tmdbMovie['id']);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tmdbMovie['title']} added to database with complete details',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding movie: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error adding movie: ${e.toString()}',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildMovieList(List<dynamic> movies) {
    if (movies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.movie,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No movies available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: movies.asMap().entries.map((entry) {
          final movie = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Movie Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: movie['poster_path'] != null
                        ? Image.network(
                            'https://image.tmdb.org/t/p/w200${movie['poster_path']}',
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 90,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 60,
                            height: 90,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.movie,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Movie Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie['title'] ?? 'Unknown Title',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          movie['release_date'] ?? 'Unknown Date',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(movie['vote_average'] ?? 0.0).toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Add Button
                  IconButton(
                    icon: Icon(
                      _addedMovieIds.contains(movie['id']) 
                          ? Icons.check_circle 
                          : Icons.add_circle,
                      color: _addedMovieIds.contains(movie['id']) 
                          ? Colors.green 
                          : const Color(0xFF047857),
                      size: 32,
                    ),
                    onPressed: _addedMovieIds.contains(movie['id']) 
                        ? null 
                        : () {
                            // Pre-populate release date if coming soon is selected
                            if (_selectedCategories.contains('coming_soon') && 
                                movie['release_date'] != null && 
                                movie['release_date'].toString().isNotEmpty) {
                              _releaseDateController.text = movie['release_date'];
                            }
                            _addMovieToDatabase(movie);
                          },
                    tooltip: _addedMovieIds.contains(movie['id']) 
                        ? 'Already Added' 
                        : 'Add to Database',
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Movies',
          style: TextStyle(
            color: Color(0xFF047857),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF9FAFB),
        iconTheme: const IconThemeData(color: Color(0xFF047857)),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for movies...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: _searchMovies,
              onChanged: (value) {
                setState(() {}); // Rebuild to show/hide clear button
              },
            ),
          ),
          
          // Search Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _searchMovies(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Search Movies',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Category Selection
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: const Text(
                        'Select Categories for Movies:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                    if (_selectedCategories.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _categories.map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    final isComingSoon = category == 'coming_soon';
                    final isDisabled = isComingSoon && _selectedCategories.isNotEmpty && !_selectedCategories.contains('coming_soon') ||
                                     !isComingSoon && _selectedCategories.contains('coming_soon');
                    
                    return FilterChip(
                      label: Text(category.replaceAll('_', ' ').toUpperCase()),
                      selected: isSelected,
                      onSelected: isDisabled ? null : (selected) {
                        setState(() {
                          if (selected) {
                            if (isComingSoon) {
                              // If selecting coming soon, clear all other categories
                              _selectedCategories = ['coming_soon'];
                            } else {
                              // If selecting other category, remove coming soon if it exists
                              _selectedCategories.remove('coming_soon');
                              _selectedCategories.add(category);
                              // Clear release date when removing coming soon
                              _releaseDateController.clear();
                            }
                          } else {
                            _selectedCategories.remove(category);
                            // Clear release date when removing coming soon
                            if (category == 'coming_soon') {
                              _releaseDateController.clear();
                            }
                          }
                        });
                      },
                      backgroundColor: isDisabled ? Colors.grey[300] : null,
                      selectedColor: isComingSoon ? Colors.orange[600] : const Color(0xFF047857).withOpacity(0.2),
                      checkmarkColor: isComingSoon ? Colors.white : const Color(0xFF047857),
                    );
                  }).toList(),
                ),
                if (_selectedCategories.contains('coming_soon'))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Note: Coming Soon movies cannot be assigned to other categories',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (_selectedCategories.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Please select at least one category to determine where the movie will appear on the homepage.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Release Date Input (only if coming soon is selected)
          if (_selectedCategories.contains('coming_soon')) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Release Date for Coming Soon Movies:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _selectReleaseDate,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _releaseDateController,
                        decoration: const InputDecoration(
                          labelText: 'Release Date',
                          hintText: 'Tap to select date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the release date for this Coming Soon movie. This will be displayed to users.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Cinema and Time Selection (only if not coming soon only)
          if (!(_selectedCategories.length == 1 && _selectedCategories.contains('coming_soon'))) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: const Text(
                          'Select Cinema Brands:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                      if (_selectedCinemaBrands.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _cinemaBrands.map((brand) {
                      final isSelected = _selectedCinemaBrands.contains(brand);
                      return FilterChip(
                        label: Text(brand),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCinemaBrands.add(brand);
                              _showtimes[brand] = [];
                            } else {
                              _selectedCinemaBrands.remove(brand);
                              _showtimes.remove(brand);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF047857).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF047857),
                      );
                    }).toList(),
                  ),
                  
                  // Showtimes for selected cinema brands
                  if (_selectedCinemaBrands.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Select Showtimes:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._selectedCinemaBrands.map((brand) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brand,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _timeSlots.map((time) {
                                  final isSelected = _showtimes[brand]?.contains(time) ?? false;
                                  return FilterChip(
                                    label: Text(time),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _showtimes[brand] ??= [];
                                        if (selected) {
                                          _showtimes[brand]!.add(time);
                                        } else {
                                          _showtimes[brand]!.remove(time);
                                        }
                                      });
                                    },
                                    selectedColor: const Color(0xFF047857).withOpacity(0.2),
                                    checkmarkColor: const Color(0xFF047857),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _hasSearched = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_hasSearched ? const Color(0xFF047857) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Latest Movies',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_hasSearched ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _hasSearched = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _hasSearched ? const Color(0xFF047857) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Search Results',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _hasSearched ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Content
          _isLoading || _isLoadingLatest
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF047857),
                    ),
                  ),
                )
              : _hasSearched
                  ? _searchResults.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No movies found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try a different search term',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildMovieList(_searchResults)
                  : _buildMovieList(_latestMovies),
          ],
        ),
      ),
    );
  }
}
