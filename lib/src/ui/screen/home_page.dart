import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/src/services/movie_service.dart';
import 'package:fyp_cinema_app/src/ui/detail/detail_screen.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/booking/booking_history_screen.dart';
import 'package:fyp_cinema_app/src/services/booking_service.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';
import 'package:fyp_cinema_app/src/ui/screen/food_beverage_screen.dart';
import 'package:fyp_cinema_app/src/ui/screen/notifications_screen.dart';
import 'package:fyp_cinema_app/src/ui/screen/profile_screen.dart';
import 'package:fyp_cinema_app/src/ui/screen/movie_screen.dart';
import 'package:fyp_cinema_app/src/ui/screen/cinema_locator_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/services/recommendation_service.dart';
import 'package:fyp_cinema_app/src/ui/recommendation/user_preference_screen.dart';
import 'package:fyp_cinema_app/src/ui/recommendation/recommendation_screen.dart';
import 'package:fyp_cinema_app/src/ui/widgets/custom_bottom_nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MovieService _movieService = MovieService();
  final BookingService _bookingService = BookingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RecommendationService _recommendationService = RecommendationService();
  List<dynamic> _bannerMovies = [];
  List<dynamic> _popularMovies = [];
  List<dynamic> _nowPlayingMovies = [];
  List<dynamic> _comingSoonMovies = [];
  List<dynamic> _genres = [];
  List<dynamic> _genreMovies = [];
  List<BannerMovie> _firestoreMovies = [];
  int? _selectedGenreId;
  bool _isLoading = true;
  int _selectedIndex = 0;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserProfile();
  }


  Future<void> _loadData() async {
    try {
      // Load movies from database instead of TMDB API
      final firestoreMovies = await _movieService.getFirestoreMovies();
      
      if (mounted) {
        setState(() {
          // Categorize movies from database
          _firestoreMovies = firestoreMovies;
          _bannerMovies = _categorizeMovies(firestoreMovies, 'banner');
          _popularMovies = _categorizeMovies(firestoreMovies, 'popular');
          _nowPlayingMovies = _categorizeMovies(firestoreMovies, 'now_playing');
          _comingSoonMovies = _categorizeMovies(firestoreMovies, 'coming_soon');
          _genres = []; // Not needed for database movies
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  List<dynamic> _categorizeMovies(List<BannerMovie> movies, String category) {
    // Filter movies by category and convert to Map format for compatibility with existing UI
    return movies
        .where((movie) => movie.categories?.contains(category) ?? false)
        .map((movie) => {
      'id': movie.id,
      'title': movie.title,
      'overview': movie.overview ?? '',
      'release_date': movie.releaseDate,
      'poster_path': movie.imageUrl ?? movie.posterPath, // Prioritize uploaded image
      'backdrop_path': movie.imageUrl ?? movie.backdropPath, // Use uploaded image for backdrop too
      'vote_average': movie.voteAverage ?? 0.0,
      'genre_ids': movie.genreIds ?? [],
      'isComingSoon': movie.isComingSoonMovie,
      'categories': movie.categories ?? [],
      'cinemaBrands': movie.cinemaBrands ?? [],
      'showtimes': movie.showtimes ?? {},
      'genres': movie.genres ?? [],
      'runtime': movie.runtime,
      'originalLanguage': movie.originalLanguage,
      'cast': movie.cast ?? [],
    }).toList();
  }

  String _formatReleaseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'TBA';
    
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  Future<void> _loadMoviesByGenre(int genreId) async {
    try {
      setState(() {
        _isLoading = true;
        _selectedGenreId = genreId;
      });
      
      final response = await _movieService.getMoviesByGenre(genreId);
      
      if (mounted) {
        setState(() {
          _genreMovies = response['results'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading genre movies: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      // No need to navigate, StreamBuilder in App will handle it
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  Future<void> _showBookingHistory() async {
    final bookings = await _bookingService.getBookings();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingHistoryScreen(bookings: bookings),
        ),
      );
    }
  }

  Future<void> _showRecommendations() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ColorApp.primaryDarkColor),
          ),
        ),
      );

      // Get recommendations
      final recommendations = await _recommendationService.getRecommendations();
      
      // Close loading dialog
      Navigator.pop(context);

      if (recommendations['type'] == 'new_user') {
        // First-time user - show preference selection
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserPreferenceScreen(),
          ),
        );
      } else {
        // Existing user - show recommendations
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecommendationScreen(
              recommendations: recommendations,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load recommendations: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _showRecommendations,
          ),
        ),
      );
    }
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userProfile = doc.data();
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    final user = _auth.currentUser;
    
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: ColorApp.primaryDarkColor,
              ),
              accountName: Text(
                _userProfile?['name'] ?? user?.displayName ?? 'User',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                _userProfile?['email'] ?? user?.email ?? '',
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (_userProfile?['name']?.isNotEmpty ?? false) 
                      ? _userProfile!['name'][0].toUpperCase()
                      : (user?.displayName?.isNotEmpty ?? false) 
                          ? user!.displayName![0].toUpperCase()
                          : 'U',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: ColorApp.primaryDarkColor,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Booking History'),
              onTap: () {
                Navigator.pop(context);
                _showBookingHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Recommendations'),
              onTap: () {
                Navigator.pop(context);
                _showRecommendations();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Cinema Locator'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CinemaLocatorScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Update Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      onProfileUpdated: () {
                        // Refresh user profile when profile is updated
                        _loadUserProfile();
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notfications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            _handleLogout();
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            // Home Page
            Padding(
              padding: EdgeInsets.only(
                top: mediaQuery.padding.top == 0 ? 16.0 : 16.0,
                bottom: mediaQuery.padding.bottom == 0 ? 16.0 : 0,
              ),
              child: Column(
                children: <Widget>[
                  _buildAppBar(),
                  const SizedBox(height: 24.0),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView(
                              children: [
                                _buildBanner(mediaQuery),
                                const SizedBox(height: 24.0),
                                _buildRecommendationsSection(mediaQuery),
                                const SizedBox(height: 24.0),
                                _buildAdminMovies(mediaQuery),
                                const SizedBox(height: 24.0),
                                _buildSection('Popular Movies', _popularMovies, mediaQuery),
                                const SizedBox(height: 24.0),
                                _buildSection('Now Playing', _nowPlayingMovies, mediaQuery),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // Movie Page
            const DiscoverMoviesScreen(),
            // Food & Beverage Page
            const FoodBeverageScreen(),
            // Profile Page
            ProfileScreen(
              onProfileUpdated: () {
                // Refresh user profile when profile is updated
                _loadUserProfile();
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          Text(
            'CINELOOK',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ColorApp.primaryDarkColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(MediaQueryData mediaQuery) {
    if (_bannerMovies.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200.0,
      child: PageView.builder(
        itemBuilder: (BuildContext context, int index) {
          var movie = _bannerMovies[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) => DetailScreen(movie),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  image: DecorationImage(
                    image: NetworkImage(
                      movie['backdrop_path'] != null && movie['backdrop_path'].isNotEmpty
                          ? movie['backdrop_path'].startsWith('http')
                              ? movie['backdrop_path']
                              : 'https://image.tmdb.org/t/p/w500${movie['backdrop_path']}'
                          : 'https://via.placeholder.com/500x200?text=No+Image',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        itemCount: _bannerMovies.length.clamp(0, 5),
      ),
    );
  }

  Widget _buildRecommendationsSection(MediaQueryData mediaQuery) {
    // Responsive sizing based on screen width
    final isSmallScreen = mediaQuery.size.width < 400;
    final isMediumScreen = mediaQuery.size.width >= 400 && mediaQuery.size.width < 600;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12.0 : 16.0,
        vertical: 8.0,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorApp.primaryDarkColor.withOpacity(0.1),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorApp.primaryDarkColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: isSmallScreen 
        ? _buildSmallScreenLayout(mediaQuery)
        : _buildLargeScreenLayout(mediaQuery),
    );
  }

  Widget _buildSmallScreenLayout(MediaQueryData mediaQuery) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorApp.primaryDarkColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personalized for You',
                    style: TextStyle(
                      fontSize: mediaQuery.size.width < 350 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: mediaQuery.size.width < 350 ? 2 : 4),
                  Text(
                    'Discover movies tailored to your taste',
                    style: TextStyle(
                      fontSize: mediaQuery.size.width < 350 ? 12 : 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _showRecommendations,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorApp.primaryDarkColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Get Recommendations',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeScreenLayout(MediaQueryData mediaQuery) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ColorApp.primaryDarkColor,
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personalized for You',
                style: TextStyle(
                  fontSize: mediaQuery.size.width > 600 ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: mediaQuery.size.width > 600 ? 10 : 8),
              Text(
                'Discover movies tailored to your taste',
                style: TextStyle(
                  fontSize: mediaQuery.size.width > 600 ? 15 : 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        ElevatedButton(
          onPressed: _showRecommendations,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorApp.primaryDarkColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
          ),
          child: const Text(
            'Get Recommendations',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminMovies(MediaQueryData mediaQuery) {
    if (_comingSoonMovies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 155, 13, 3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        SizedBox(
          height: 200.0,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) {
              var movie = _comingSoonMovies[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: index == _comingSoonMovies.length - 1 ? 16.0 : 0.0,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (BuildContext context) => DetailScreen(movie),
                      ),
                    );
                  },
                  child: Container(
                    width: mediaQuery.size.width * 0.8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      image: DecorationImage(
                        image: NetworkImage(
                          movie['backdrop_path'] != null && movie['backdrop_path'].isNotEmpty
                              ? movie['backdrop_path'].startsWith('http')
                                  ? movie['backdrop_path']
                                  : 'https://image.tmdb.org/t/p/w1280${movie['backdrop_path']}'
                              : 'https://via.placeholder.com/500x200?text=No+Image',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie['title'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Release: ${_formatReleaseDate(movie['release_date'])}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Coming Soon badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'COMING SOON',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            itemCount: _comingSoonMovies.length,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<dynamic> movies, MediaQueryData mediaQuery) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16.0),
        SizedBox(
          height: 200.0,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) {
              var movie = movies[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: index == movies.length - 1 ? 16.0 : 0.0,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (BuildContext context) => DetailScreen(movie),
                      ),
                    );
                  },
                  child: Container(
                    width: 120.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      image: DecorationImage(
                        image: NetworkImage(
                          movie['poster_path'] != null && movie['poster_path'].isNotEmpty
                              ? movie['poster_path'].startsWith('http')
                                  ? movie['poster_path']
                                  : 'https://image.tmdb.org/t/p/w500${movie['poster_path']}'
                              : 'https://via.placeholder.com/120x180?text=No+Image',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            },
            itemCount: movies.length,
          ),
        ),
      ],
    );
  }
} 