import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/src/services/movie_service.dart';
import 'package:fyp_cinema_app/src/services/admin_service.dart';
import 'package:fyp_cinema_app/src/ui/detail/detail_screen.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';

// Renamed from ComingSoonScreen
class DiscoverMoviesScreen extends StatefulWidget {
  const DiscoverMoviesScreen({super.key});

  @override
  State<DiscoverMoviesScreen> createState() => _DiscoverMoviesScreenState();
}

// Renamed from _ComingSoonScreenState
class _DiscoverMoviesScreenState extends State<DiscoverMoviesScreen> {
  final MovieService _movieService = MovieService();
  final AdminService _adminService = AdminService();
  List<BannerMovie> _allMovies = []; // Store all movies from database
  List<BannerMovie> _filteredMovies = []; // Store filtered movies
  bool _isLoading = true;
  List<dynamic> _genres = []; // To store fetched genres

  // Filter state variables
  Set<int> _selectedGenreIds = {}; // Changed from single genreId to Set of IDs
  String? _selectedLanguage; // e.g., 'en', 'es'

  // Predefined language options (can be expanded)
  final Map<String, String> _languageOptions = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ja': 'Japanese',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadGenres(); // Load genres first for the filter modal
    await _loadMoviesFromDatabase(); // Load movies from database
  }

  Future<void> _loadGenres() async {
    try {
      final response = await _movieService.getGenres();
      if (mounted && response['genres'] is List) {
        setState(() {
          _genres = response['genres'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading genres: $e')),
        );
      }
    }
  }

  // Load movies from database
  Future<void> _loadMoviesFromDatabase() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final movies = await _adminService.getAllMovies();
      if (mounted) {
        setState(() {
          _allMovies = movies;
          _applyFilters(); // Apply current filters
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading movies: $e')),
        );
      }
    }
  }

  // Apply filters to the movie list
  void _applyFilters() {
    List<BannerMovie> filtered = List.from(_allMovies);

    // Filter by genres (if any selected)
    if (_selectedGenreIds.isNotEmpty) {
      filtered = filtered.where((movie) {
        if (movie.genreIds == null) return false;
        return _selectedGenreIds.any((genreId) => movie.genreIds!.contains(genreId));
      }).toList();
    }

    // Sort movies by popularity (default)
    filtered.sort((a, b) {
      return (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0);
    });

    setState(() {
      _filteredMovies = filtered;
    });
  }

  void _showFilterModal() {
    // Store temporary filter values for the modal
    Set<int> tempGenreIds = Set.from(_selectedGenreIds); // Create a copy of selected genres
    String? tempLanguage = _selectedLanguage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Check if any filters are active
            bool hasActiveFilters = tempGenreIds.isNotEmpty || 
                                   tempLanguage != null;
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 20 // Adjust for keyboard
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with drag indicator
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // Title with filter count badge and back button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Filter Movies', 
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const Divider(height: 30, thickness: 1),
                    
                    // Genre Filter Section
                    _buildFilterSectionHeader(
                      context, 
                      'Genres', 
                      tempGenreIds.isNotEmpty ? '${tempGenreIds.length} selected' : null
                    ),
                    const SizedBox(height: 10),
                    _buildGenreFilter(tempGenreIds, setModalState, (ids) => tempGenreIds = ids),
                    const SizedBox(height: 24),
                    
                    // Language Filter Section
                    _buildFilterSectionHeader(
                      context, 
                      'Language', 
                      tempLanguage != null ? _languageOptions[tempLanguage] : null
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownFilter<String?>(
                      value: tempLanguage,
                      items: _languageOptions,
                      hint: 'Any Language',
                      onChanged: (value) => setModalState(() => tempLanguage = value),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: hasActiveFilters ? () {
                              // Clear Filters
                              setModalState(() {
                                tempGenreIds.clear();
                                tempLanguage = null;
                              });
                            } : null,
                            icon: const Icon(Icons.clear_all, color: Colors.black),
                            label: const Text('Clear All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Apply filters and reload data
                              setState(() {
                                _selectedGenreIds = tempGenreIds;
                                _selectedLanguage = tempLanguage;
                              });
                              Navigator.pop(context);
                              _applyFilters();
                            },
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('Apply'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorApp.primaryDarkColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper to build filter section headers with optional active filter indicator
  Widget _buildFilterSectionHeader(BuildContext context, String title, String? activeValue) {
    return Row(
      children: [
        Text(
          title, 
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (activeValue != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ColorApp.primaryDarkColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorApp.primaryDarkColor.withOpacity(0.3)),
            ),
            child: Text(
              activeValue,
              style: const TextStyle(
                color: ColorApp.primaryDarkColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Enhanced Genre Chips with multiple selection support
  Widget _buildGenreFilter(Set<int> selectedGenreIds, StateSetter setModalState, ValueChanged<Set<int>> onSelected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _genres.map((genre) {
        final bool isSelected = selectedGenreIds.contains(genre['id']);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: FilterChip(
            label: Text(
              genre['name'] ?? '',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              setModalState(() {
                final newSelectedIds = Set<int>.from(selectedGenreIds);
                if (selected) {
                  newSelectedIds.add(genre['id']);
                } else {
                  newSelectedIds.remove(genre['id']);
                }
                onSelected(newSelectedIds);
              });
            },
            selectedColor: ColorApp.primaryDarkColor,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey[300]!,
                width: 1,
              ),
            ),
            elevation: isSelected ? 2 : 0,
            pressElevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }).toList(),
    );
  }

  // Enhanced dropdown with better styling
  Widget _buildDropdownFilter<T>({ 
    required T value, 
    required Map<String, String> items, 
    required String hint, 
    required ValueChanged<T?> onChanged
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
        items: items.entries.map((entry) {
          return DropdownMenuItem<T>(
            value: entry.key as T,
            child: Text(
              entry.value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: ColorApp.primaryDarkColor, width: 1.5),
          ),
          enabledBorder: InputBorder.none,
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
        title: const Text(
          'Movies', // Changed title
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0, // Remove shadow
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredMovies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No movies found',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _loadMoviesFromDatabase, child: const Text('Retry'))
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadMoviesFromDatabase,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredMovies.length,
                    itemBuilder: (context, index) {
                      final movie = _filteredMovies[index];
                      // Convert BannerMovie to Map format for DetailScreen compatibility
                      final movieMap = {
                        'id': movie.id,
                        'title': movie.title,
                        'overview': movie.overview ?? '',
                        'release_date': movie.releaseDate,
                        'poster_path': movie.posterPath,
                        'backdrop_path': movie.backdropPath,
                        'vote_average': movie.voteAverage ?? 0.0,
                        'genre_ids': movie.genreIds ?? [],
                        'isComingSoon': movie.isComingSoon,
                      };
                      
                      final posterPath = movie.posterPath;
                      final title = movie.title;
                      
                      final imageUrl = posterPath != null && posterPath.isNotEmpty
                          ? posterPath.startsWith('http')
                              ? posterPath
                              : 'https://image.tmdb.org/t/p/w500$posterPath'
                          : null;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailScreen(movieMap),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white, // Card background
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (imageUrl != null)
                                  Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    // Loading indicator for image
                                    loadingBuilder: (context, child, loadingProgress) {
                                       if (loadingProgress == null) return child;
                                       return Center(
                                         child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      // More informative error placeholder
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                            SizedBox(height: 4),
                                            Text('No Image', style: TextStyle(color: Colors.grey))
                                          ],
                                        )
                                      );
                                    },
                                  )
                                else
                                  // Placeholder if no image URL
                                  Container(
                                    color: Colors.grey[200],
                                    child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.movie_creation_outlined, size: 40, color: Colors.grey),
                                            SizedBox(height: 4),
                                            Text('No Image', style: TextStyle(color: Colors.grey))
                                          ],
                                        )
                                  ),
                                // Gradient overlay for text
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.85),
                                        ],
                                        stops: const [0.0, 0.6] // Adjust gradient sharpness
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showFilterModal,
          backgroundColor: ColorApp.primaryDarkColor,
          child: const Icon(Icons.filter_list, color: Colors.white),
        ),
    );
  }
}