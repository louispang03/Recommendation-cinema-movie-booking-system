import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/detail/detail_screen.dart';

class RecommendationScreen extends StatefulWidget {
  final Map<String, dynamic> recommendations;
  final bool isFirstTime;

  const RecommendationScreen({
    super.key,
    required this.recommendations,
    this.isFirstTime = false,
  });

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  late String recommendationType;
  late List<dynamic> movieList;
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? userPreferences;

  @override
  void initState() {
    super.initState();
    recommendationType = widget.recommendations['type'] ?? 'unknown';
    movieList = widget.recommendations['recommendations'] ?? [];
    userProfile = widget.recommendations['user_profile'];
    userPreferences = widget.recommendations['user_preferences'];
    
    // Debug: Print basic info
    print('🎯 Recommendation type: $recommendationType');
    print('🎬 Movie list length: ${movieList.length}');
    print('👤 User preferences: $userPreferences');
  }

  String _getRecommendationTitle() {
    switch (recommendationType) {
      case 'new_user_preferences':
        return 'Movies You Might Love';
      case 'personalized':
        return 'Recommended For You';
      case 'similar_movies':
        return 'Similar Movies';
      default:
        return 'Movie Recommendations';
    }
  }

  String _getRecommendationSubtitle() {
    if (widget.isFirstTime) {
      return 'Based on your selected preferences';
    }
    switch (recommendationType) {
      case 'personalized':
        return 'Based on your viewing history and preferences';
      case 'similar_movies':
        return 'Movies similar to your interests';
      default:
        return 'Curated just for you';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Recommendations'),
        backgroundColor: ColorApp.primaryDarkColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showRecommendationInfo();
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ColorApp.primaryDarkColor.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: ColorApp.primaryDarkColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getRecommendationTitle(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRecommendationSubtitle(),
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${movieList.length} movies found',
                    style: TextStyle(
                      color: ColorApp.primaryDarkColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User preferences section (for new users)
          if (userPreferences != null && widget.isFirstTime)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          color: ColorApp.primaryDarkColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Selected Preferences :',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildUserPreferences(),
                  ],
                ),
              ),
            ),

          // User profile summary (for returning users)
          if (userProfile != null && !widget.isFirstTime)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: ColorApp.primaryDarkColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildProfileInfo(),
                  ],
                ),
              ),
            ),

          // Movie recommendations list
          movieList.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.movie_outlined,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recommendations found',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your preferences',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final movie = movieList[index];
                        return _buildMovieCard(movie, index);
                      },
                      childCount: movieList.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildUserPreferences() {
    if (userPreferences == null) return const SizedBox();

    final selectedGenres = userPreferences!['genres'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Genres
        if (selectedGenres.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selectedGenres.map((genre) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ColorApp.primaryDarkColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ColorApp.primaryDarkColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                genre.toString(),
                style: TextStyle(
                  color: ColorApp.primaryDarkColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ],
        
        // Summary text
        const SizedBox(height: 12),
        Text(
          'Based on ${selectedGenres.length} genre${selectedGenres.length != 1 ? 's' : ''}',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    if (userProfile == null) return const SizedBox();

    final totalBookings = userProfile!['total_bookings'] ?? 0;
    final topGenres = (userProfile!['preferred_genres'] as Map<String, dynamic>?)
            ?.entries
            .toList()
          ?..sort((a, b) => b.value.compareTo(a.value));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movies watched: $totalBookings',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 14,
          ),
        ),
        if (topGenres != null && topGenres.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Favorite genres: ${topGenres.take(3).map((e) => e.key).join(', ')}',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailScreen(movie),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Movie rank
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorApp.primaryDarkColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Movie poster
              Container(
                width: 90,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _getMovieImageUrl(movie) != null
                      ? Builder(
                          builder: (context) {
                            final imageUrl = _getMovieImageUrl(movie)!;
                            print('🖼️ Loading image: $imageUrl');
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 120,
                              errorBuilder: (context, error, stackTrace) {
                                print('❌ Image load error: $error');
                                return _buildPlaceholderImage();
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        ColorApp.primaryDarkColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : _buildPlaceholderImage(),
                ),
              ),
              const SizedBox(width: 16),
              
              // Movie details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie['title'] ?? 'Unknown Title',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Genres
                    if (movie['genres'] != null && movie['genres'].isNotEmpty)
                      Text(
                        (movie['genres'] as List).take(3).join(' • '),
                        style: TextStyle(
                          color: ColorApp.primaryDarkColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    
                    // Recommendation reason
                    if (movie['recommendation_reason'] != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ColorApp.primaryDarkColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          movie['recommendation_reason'],
                          style: TextStyle(
                            color: ColorApp.primaryDarkColor,
                            fontSize: 11,
                            height: 1.3,
                          ),
                          softWrap: true,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Action button
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailScreen(movie),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getMovieImageUrl(Map<String, dynamic> movie) {
    // Debug logging
    print('🎬 Getting image URL for: ${movie['title']}');
    print('📋 Available image fields: imageUrl=${movie['imageUrl']}, poster_path=${movie['poster_path']}');
    
    // Check for admin-uploaded image first (from database)
    if (movie['imageUrl'] != null && movie['imageUrl'].toString().isNotEmpty) {
      print('✅ Using imageUrl: ${movie['imageUrl']}');
      return movie['imageUrl'];
    }
    
    // Check for poster_path (from TMDB or database)
    if (movie['poster_path'] != null && movie['poster_path'].toString().isNotEmpty) {
      final posterPath = movie['poster_path'].toString();
      print('📸 Using poster_path: $posterPath');
      // If it's already a full URL, return as is
      if (posterPath.startsWith('http')) {
        return posterPath;
      }
      // If it's a TMDB path, construct the full URL
      return 'https://image.tmdb.org/t/p/w500$posterPath';
    }
    
    print('❌ No image URL found for: ${movie['title']}');
    return null;
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 120,
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie,
            color: Colors.grey[600],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'No Image',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showRecommendationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'How Recommendations Work',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our AI analyzes your movie preferences and viewing history to suggest movies you\'ll love.',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text(
              'Factors considered:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Your favorite genres',
              style: TextStyle(color: Colors.grey[300]),
            ),
            Text(
              '• Preferred actors and directors',
              style: TextStyle(color: Colors.grey[300]),
            ),
            Text(
              '• Past booking history',
              style: TextStyle(color: Colors.grey[300]),
            ),
            Text(
              '• Movie ratings and popularity',
              style: TextStyle(color: Colors.grey[300]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(color: ColorApp.primaryDarkColor),
            ),
          ),
        ],
      ),
    );
  }
} 