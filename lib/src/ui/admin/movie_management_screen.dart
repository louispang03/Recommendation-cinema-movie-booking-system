import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';
import 'package:fyp_cinema_app/src/services/admin_service.dart';
import 'package:fyp_cinema_app/src/services/movie_service.dart';
import 'package:fyp_cinema_app/src/ui/admin/movie_form_screen.dart';
import 'package:fyp_cinema_app/src/ui/admin/tmdb_movie_search_screen.dart';

class MovieManagementScreen extends StatefulWidget {
  const MovieManagementScreen({super.key});

  @override
  State<MovieManagementScreen> createState() => _MovieManagementScreenState();
}

class _MovieManagementScreenState extends State<MovieManagementScreen> {
  final AdminService _adminService = AdminService();
  final MovieService _movieService = MovieService();
  List<BannerMovie> _movies = [];
  List<BannerMovie> _filteredMovies = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final movies = await _adminService.getAllMovies();
      setState(() {
        _movies = movies;
        _filteredMovies = movies;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading movies: ${e.toString()}'),
          backgroundColor: const Color(0xFF1A1C1E),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterMovies(String category) {
    setState(() {
      _selectedFilter = category;
      if (category == 'All') {
        _filteredMovies = _movies;
      } else {
        _filteredMovies = _movies.where((movie) {
          return movie.categories?.contains(category.toLowerCase()) ?? false;
        }).toList();
      }
    });
  }

  Future<void> _deleteMovie(String movieId) async {
    try {
      await _adminService.deleteMovie(movieId);
      await _loadMovies();
      // Reapply current filter after loading movies
      _filterMovies(_selectedFilter);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movie deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting movie: ${e.toString()}'),
          backgroundColor: const Color(0xFF1A1C1E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Movie Management',
          style: TextStyle(
            color: Color(0xFF047857),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF9FAFB),
        iconTheme: const IconThemeData(color: Color(0xFF047857)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Search TMDB Movies',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TMDBMovieSearchScreen(),
                ),
              ).then((_) {
                _loadMovies().then((_) {
                  // Reapply current filter after loading movies
                  _filterMovies(_selectedFilter);
                });
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF047857)))
          : Column(
              children: [
                _buildFilterSection(),
                Expanded(
                  child: ListView.builder(
              padding: const EdgeInsets.all(16),
                    itemCount: _filteredMovies.length,
              itemBuilder: (context, index) {
                      final movie = _filteredMovies[index];
                return Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: movie.posterPath != null
                              ? Image.network(
                                  movie.posterUrl,
                                  width: 80,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 80,
                                  height: 120,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.title,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              _buildCategoriesChips(movie.categories),
                              const SizedBox(height: 4),
                              _buildCinemaBrandsChips(movie.cinemaBrands),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF047857)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MovieFormScreen(movie: movie),
                              ),
                            ).then((_) {
                              _loadMovies().then((_) {
                                // Reapply current filter after loading movies
                                _filterMovies(_selectedFilter);
                              });
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(movie),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Category:',
            style: TextStyle(
              color: Color(0xFF047857),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', _selectedFilter == 'All'),
              _buildFilterChip('Banner', _selectedFilter == 'banner'),
              _buildFilterChip('Coming Soon', _selectedFilter == 'coming_soon'),
              _buildFilterChip('Now Playing', _selectedFilter == 'now_playing'),
              _buildFilterChip('Popular', _selectedFilter == 'popular'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF047857),
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        String filterValue = label == 'All' ? 'All' : label.toLowerCase().replaceAll(' ', '_');
        _filterMovies(filterValue);
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF047857),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF047857) : Colors.grey[300]!,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildCategoriesChips(List<String>? categories) {
    if (categories == null || categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: categories.map((category) {
        return Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getCategoryColor(category),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatCategoryName(category),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCinemaBrandsChips(List<String>? cinemaBrands) {
    if (cinemaBrands == null || cinemaBrands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: cinemaBrands.map((brand) {
        return Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              brand,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'banner':
        return Colors.purple[600]!;
      case 'coming_soon':
        return Colors.orange[600]!;
      case 'now_playing':
        return Colors.green[600]!;
      case 'popular':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _formatCategoryName(String category) {
    switch (category) {
      case 'banner':
        return 'Banner';
      case 'coming_soon':
        return 'Coming Soon';
      case 'now_playing':
        return 'Now Playing';
      case 'popular':
        return 'Popular';
      default:
        return category.toUpperCase();
    }
  }

  Future<void> _showDeleteConfirmation(BannerMovie movie) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Delete Movie'),
          content: Text('Are you sure you want to delete "${movie.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color:Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteMovie(movie.id.toString());
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
} 