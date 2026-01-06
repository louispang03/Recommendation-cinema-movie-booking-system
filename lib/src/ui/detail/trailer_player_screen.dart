import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TrailerPlayerScreen extends StatefulWidget {
  final dynamic movie;

  const TrailerPlayerScreen({super.key, required this.movie});

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _trailerUrl;
  bool _isYoutube = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape for better viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadTrailer();
  }

  @override
  void dispose() {
    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _youtubeController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadTrailer() async {
    try {
      print('🎬 Loading trailer for: ${widget.movie['title']}');
      
      // First try to get trailer from TMDB API
      final movieId = widget.movie['id'];
      if (movieId != null) {
        print('🔍 Trying TMDB API for movie ID: $movieId');
        final trailerUrl = await _getTrailerFromTMDB(movieId);
        if (trailerUrl != null) {
          print('✅ Found TMDB trailer: $trailerUrl');
          await _initializePlayer(trailerUrl);
          return;
        }
      }

      // Fallback: Use sample trailer URLs based on movie data
      print('🔄 Using fallback trailer URLs');
      final fallbackUrl = _getFallbackTrailerUrl();
      if (fallbackUrl != null) {
        print('🎯 Using fallback URL: $fallbackUrl');
        await _initializePlayer(fallbackUrl);
      } else {
        throw Exception('No trailer available for this movie');
      }
    } catch (e) {
      print('❌ Error loading trailer: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<String?> _getTrailerFromTMDB(int movieId) async {
    try {
      // TMDB v4 Access Token (Bearer Token)
      // Get your FREE access token from: https://www.themoviedb.org/settings/api
      // 1. Create an account at themoviedb.org
      // 2. Go to Settings -> API
      // 3. Copy your "Access Token Auth (v4 auth)" - the long JWT token
      final accessToken = dotenv.env['TMDB_ACCESS_TOKEN'] ?? '';
      
      // Skip TMDB if no real access token provided
      if (accessToken.isEmpty || accessToken == 'YOUR_TMDB_ACCESS_TOKEN') {
        print('⚠️ No TMDB access token provided, skipping TMDB lookup');
        return null;
      }
      
      // Using v3 endpoint with v4 authentication (Bearer token)
      final url = 'https://api.themoviedb.org/3/movie/$movieId/videos';
      print('🌐 Calling TMDB API: $url');
      
      // Make request with Bearer token authentication
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json;charset=utf-8',
        },
      );
      
      print('📡 TMDB Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = data['results'] as List;
        print('🎬 Found ${videos.length} videos from TMDB');
        
        // Look for YouTube trailers
        for (var video in videos) {
          print('🔍 Video: ${video['name']} - Type: ${video['type']} - Site: ${video['site']}');
          if (video['site'] == 'YouTube' && 
              (video['type'] == 'Trailer' || video['type'] == 'Teaser')) {
            final youtubeUrl = 'https://www.youtube.com/watch?v=${video['key']}';
            print('✅ Found TMDB trailer: $youtubeUrl');
            return youtubeUrl;
          }
        }
        print('⚠️ No YouTube trailers found in TMDB results');
      } else {
        print('❌ TMDB API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching trailer from TMDB: $e');
    }
    return null;
  }

  String? _getFallbackTrailerUrl() {
    // Working YouTube trailer URLs for demonstration
    final movieTitle = widget.movie['title']?.toString().toLowerCase() ?? '';
    
    print('🔍 Checking movie title: $movieTitle');
    
    // Popular movie trailers that are known to work
    if (movieTitle.contains('avengers') || movieTitle.contains('endgame')) {
      return 'https://www.youtube.com/watch?v=TcMBFSGVi1c'; // Avengers: Endgame
    } else if (movieTitle.contains('spider') || movieTitle.contains('man')) {
      return 'https://www.youtube.com/watch?v=rt-2cxAiPJk'; // Spider-Man trailer
    } else if (movieTitle.contains('batman') || movieTitle.contains('dark')) {
      return 'https://www.youtube.com/watch?v=mqqft2x_Aa4'; // Batman trailer
    } else if (movieTitle.contains('iron') || movieTitle.contains('man')) {
      return 'https://www.youtube.com/watch?v=8ugaeA-nMTc'; // Iron Man trailer
    } else if (movieTitle.contains('wonder') || movieTitle.contains('woman')) {
      return 'https://www.youtube.com/watch?v=1Q8fG0TtVAY'; // Wonder Woman trailer
    } else {
      // Default working trailer - Big Buck Bunny (open source)
      return 'https://www.youtube.com/watch?v=YE7VzlLtp-4'; // Big Buck Bunny trailer
    }
  }

  Future<void> _initializePlayer(String url) async {
    try {
      print('🎮 Initializing player with URL: $url');
      setState(() {
        _trailerUrl = url;
      });

      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        print('📺 Setting up YouTube player');
        // YouTube video
        final videoId = YoutubePlayer.convertUrlToId(url);
        print('🆔 YouTube video ID: $videoId');
        
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false, // Changed to false to prevent auto-start issues
              mute: false,
              enableCaption: true,
              loop: false,
              hideControls: false,
              controlsVisibleAtStart: true,
            ),
          );
          
          // Add listeners for better error handling
          _youtubeController!.addListener(() {
            if (_youtubeController!.value.isReady) {
              print('✅ YouTube player is ready');
              setState(() {
                _isPlaying = _youtubeController!.value.isPlaying;
              });
            }
            if (_youtubeController!.value.hasError) {
              print('❌ YouTube player error: ${_youtubeController!.value.errorCode}');
              setState(() {
                _hasError = true;
                _errorMessage = 'YouTube player error: ${_youtubeController!.value.errorCode}';
              });
            }
          });
          
          _isYoutube = true;
          print('✅ YouTube player configured');
        } else {
          throw Exception('Invalid YouTube URL: Could not extract video ID');
        }
      } else {
        print('🎥 Setting up Video player');
        // Direct video URL
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
        
        // Add listener for video player
        _videoController!.addListener(() {
          setState(() {
            _isPlaying = _videoController!.value.isPlaying;
          });
          
          if (_videoController!.value.hasError) {
            print('❌ Video player error: ${_videoController!.value.errorDescription}');
            setState(() {
              _hasError = true;
              _errorMessage = 'Video player error: ${_videoController!.value.errorDescription}';
            });
          }
        });
        
        await _videoController!.initialize();
        print('✅ Video player initialized');
        _isYoutube = false;
      }

      setState(() {
        _isLoading = false;
      });
      print('🎉 Player setup complete');
      
    } catch (e) {
      print('❌ Error initializing player: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }

  void _togglePlayPause() {
    try {
      if (_isYoutube && _youtubeController != null) {
        if (_youtubeController!.value.isPlaying) {
          _youtubeController!.pause();
        } else {
          _youtubeController!.play();
        }
      } else if (!_isYoutube && _videoController != null) {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      }
    } catch (e) {
      print('❌ Error toggling play/pause: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Playback error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.movie['title'] ?? 'Movie'} - Trailer',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen_exit),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading trailer...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Trailer Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                        _errorMessage = '';
                      });
                      _loadTrailer();
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_isYoutube && _youtubeController != null) {
      return Column(
        children: [
          Expanded(
            child: YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              onReady: () {
                print('✅ YouTube player ready');
              },
              onEnded: (metaData) {
                print('🔚 Video ended');
              },
            ),
          ),
          // Custom controls
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _isPlaying ? 'Playing...' : 'Paused',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (!_isYoutube && _videoController != null) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
          // Custom controls
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _isPlaying ? 'Playing...' : 'Paused',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Text(
        'Unable to load trailer',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}
