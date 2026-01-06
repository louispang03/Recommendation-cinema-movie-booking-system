import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/booking/showtime_selection_screen.dart';
import 'package:fyp_cinema_app/src/ui/detail/trailer_player_screen.dart';

class DetailScreen extends StatelessWidget {
  final dynamic movie;

  const DetailScreen(this.movie, {super.key});

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: mediaQuery.size.height / 2,
            pinned: true,
            automaticallyImplyLeading: false, // Remove default back button
            flexibleSpace: Stack(
              children: <Widget>[
                _buildBackdropImage(mediaQuery),
                _buildWidgetAppBar(mediaQuery, context),
                _buildWidgetFloatingActionButton(mediaQuery, context),
                _buildWidgetIconBuyAndShare(mediaQuery),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: mediaQuery.padding.bottom == 0 ? 16.0 : mediaQuery.padding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildWidgetTitleMovie(context),
                const SizedBox(height: 16.0),
                _buildMovieInfo(context),
                const SizedBox(height: 16.0),
                _buildWidgetSynopsisMovie(context),
                const SizedBox(height: 24.0),
                // Coming soon info card
                if (_isComingSoonMovie()) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This movie is not yet available for booking. Stay tuned for the release!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Only show booking button for non-coming soon movies
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56.0,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShowtimeSelectionScreen(
                                movie: movie,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorApp.primaryDarkColor,
                          elevation: 4,
                          shadowColor: ColorApp.primaryDarkColor.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Book Now',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropImage(MediaQueryData mediaQuery) {
    // Try multiple image fields from different data sources
    String imageUrl = '';
    
    // Priority order: backdrop_path, poster_path, imageUrl
    if (movie['backdrop_path'] != null && movie['backdrop_path'].toString().isNotEmpty) {
      String backdropPath = movie['backdrop_path'].toString();
      imageUrl = backdropPath.startsWith('http') 
          ? backdropPath 
          : 'https://image.tmdb.org/t/p/w500$backdropPath';
    } else if (movie['poster_path'] != null && movie['poster_path'].toString().isNotEmpty) {
      String posterPath = movie['poster_path'].toString();
      imageUrl = posterPath.startsWith('http') 
          ? posterPath 
          : 'https://image.tmdb.org/t/p/w500$posterPath';
    } else if (movie['imageUrl'] != null && movie['imageUrl'].toString().isNotEmpty) {
      imageUrl = movie['imageUrl'].toString();
    }

    return ClipPath(
      clipper: BottomWaveClipper(),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              height: mediaQuery.size.height / 2,
              width: mediaQuery.size.width,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: mediaQuery.size.height / 2,
                  width: mediaQuery.size.width,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                );
              },
            )
          : Container(
              height: mediaQuery.size.height / 2,
              width: mediaQuery.size.width,
              color: Colors.grey[300],
              child: const Icon(Icons.movie),
            ),
    );
  }

  Widget _buildWidgetAppBar(MediaQueryData mediaQuery, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        top: mediaQuery.padding.top == 0 ? 16.0 : mediaQuery.padding.top + 8.0,
        right: 16.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Icon(
              Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const Expanded(
            child: SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetFloatingActionButton(MediaQueryData mediaQuery, BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrailerPlayerScreen(movie: movie),
              ),
            );
          },
          backgroundColor: Colors.white,
          child: Icon(
            Icons.play_arrow,
            color: ColorApp.primaryDarkColor,
            size: 32.0,
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetIconBuyAndShare(MediaQueryData mediaQuery) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(Icons.add, color: Colors.white),
          Icon(Icons.share, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildWidgetTitleMovie(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Center(
        child: Text(
          movie['title'] ?? 'No Title',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMovieInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genres with label
          if (movie['genres'] != null && (movie['genres'] as List).isNotEmpty) ...[
            _buildInfoSection(context, 'Genres', (movie['genres'] as List).join(', ')),
            const SizedBox(height: 12),
          ],
          
          // Duration with label
          if (movie['runtime'] != null && movie['runtime'] > 0) ...[
            _buildInfoSection(context, 'Duration', '${movie['runtime']} minutes'),
            const SizedBox(height: 12),
          ],
          
          // Language with label
          if (movie['originalLanguage'] != null && movie['originalLanguage'].isNotEmpty) ...[
            _buildInfoSection(context, 'Language', _formatLanguage(movie['originalLanguage'])),
            const SizedBox(height: 16),
          ],
          
          // Cast (limited to 10 actors)
          if (movie['cast'] != null && (movie['cast'] as List).isNotEmpty) ...[
            _buildCastSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCastSection(BuildContext context) {
    final cast = movie['cast'] as List;
    final topCast = cast.take(10).toList(); // Limit to 10 most important actors
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cast',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: topCast.map((actor) {
            // Handle both string format (from recommendation engine) and object format (from TMDB)
            String actorName;
            if (actor is String) {
              actorName = actor;
            } else if (actor is Map && actor['name'] != null) {
              actorName = actor['name'].toString();
            } else {
              actorName = 'Unknown';
            }
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                actorName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
        if (cast.length > 10) ...[
          const SizedBox(height: 8),
          Text(
            'and ${cast.length - 10} more...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  String _formatLanguage(String languageCode) {
    final languageMap = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'hi': 'Hindi',
      'ar': 'Arabic',
    };
    return languageMap[languageCode.toLowerCase()] ?? languageCode.toUpperCase();
  }


  Widget _buildWidgetSynopsisMovie(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            movie['overview'] ?? 'No overview available.',
            textAlign: TextAlign.justify,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  bool _isComingSoonMovie() {
    // Check if this movie has the isComingSoon field set to true
    // This field is present in Firestore movies (admin-added coming soon movies)
    return movie['isComingSoon'] == true;
  }
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0.0, size.height - 70.0);

    var firstControlPoint = Offset(size.width / 2, size.height);
    var firstEndPoint = Offset(size.width, size.height - 70.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    path.lineTo(size.width, size.height - 70.0);
    path.lineTo(size.width, 0.0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return true;
  }
}
