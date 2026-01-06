import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/services/chat_service.dart';
import 'package:fyp_cinema_app/src/services/movie_service.dart';
import 'package:fyp_cinema_app/src/model/chat/chat_message.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';
import 'package:fyp_cinema_app/src/ui/booking/showtime_selection_screen.dart';
import 'package:fyp_cinema_app/src/ui/screen/movie_screen.dart';
import 'package:fyp_cinema_app/src/ui/screen/cinema_locator_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  Timer? _resetTimer;
  static const Duration _chatResetDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadChatHistory();
    _startResetTimer();
    
    // Listen for auth state changes to handle user switching
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        // User changed, reload chat history for new user
        _loadChatHistory();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _resetTimer?.cancel();
    _saveChatHistory();
    super.dispose();
  }

  void _addWelcomeMessage() async {
    // Send welcome message through ChatService to get Dify response
    try {
      final response = await _chatService.sendMessage('welcome');
      final welcomeMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        messageType: response.messageType,
        actionData: response.actionData,
      );
      
      setState(() {
        _messages.add(welcomeMessage);
      });
    } catch (e) {
      // Fallback welcome message
      final welcomeMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "👋 Hi! I'm your cinema assistant. I can help you with:\n\n🎬 Finding movies and showtimes\n🎫 Booking tickets\n📍 Cinema locations\n❓ General questions\n\nHow can I help you today?",
        isUser: false,
        timestamp: DateTime.now(),
        messageType: ChatMessageType.welcome,
      );
      
      setState(() {
        _messages.add(welcomeMessage);
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _messageController.text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _chatService.sendMessage(userMessage.text);
      
      final botMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        messageType: response.messageType,
        actionData: response.actionData,
      );

      setState(() {
        _messages.add(botMessage);
        _isLoading = false;
      });
      
      // Save chat history after each message
      _saveChatHistory();
    } catch (e) {
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Sorry, I'm having trouble right now. Please try again later.",
        isUser: false,
        timestamp: DateTime.now(),
        messageType: ChatMessageType.error,
      );

      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
      
      // Save chat history even for error messages
      _saveChatHistory();
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ColorApp.primaryDarkColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cinelook Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _addWelcomeMessage();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildQuickActions(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ColorApp.primaryDarkColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? ColorApp.primaryDarkColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  if (message.actionData != null) ...[
                    const SizedBox(height: 12),
                    _buildActionButtons(message.actionData!),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isUser ? Colors.white70 : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.grey,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> actionData) {
    final String actionType = actionData['type'] ?? '';
    
    switch (actionType) {
      case 'movie_booking':
        return _buildMovieBookingActions(actionData);
      case 'cinema_locations':
        // Directly navigate to cinema locator for location queries
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToCinemaLocations();
        });
        return const SizedBox.shrink();
      case 'quick_replies':
        final replies = actionData['replies'] as List<dynamic>? ?? [];
        return _buildQuickReplies(replies.map((e) => e.toString()).toList());
      case 'movie_info':
        return _buildMovieInfoActions(actionData);
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleQuickReplyAction(String reply) {
    switch (reply.toLowerCase()) {
      case 'book tickets':
      case 'book now':
        _navigateToMovieBooking();
        break;
      case 'show movies':
      case 'show current movies':
      case 'popular movies':
      case 'view all movies':
        _navigateToMovieScreen();
        break;
      case 'find cinemas':
      case 'cinema locations':
      case 'find locations':
      case 'nearest location':
        _navigateToCinemaLocations();
        break;
      case 'pricing':
      case 'price':
      case 'cost':
      case 'ticket price':
        _messageController.text = 'What are the ticket prices?';
        _sendMessage();
        break;
      case 'faq':
      case 'help':
      case 'more help':
        _messageController.text = 'FAQ';
        _sendMessage();
        break;
      default:
        // For other replies, send as message
        _messageController.text = reply;
        _sendMessage();
    }
  }

  void _navigateToMovieBooking() {
    // Don't close chat, just navigate to movies
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DiscoverMoviesScreen(),
      ),
    );
  }

  void _navigateToMovieScreen() {
    // Don't close chat, just navigate to movies
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DiscoverMoviesScreen(),
      ),
    );
  }

  void _navigateToCinemaLocations() {
    // Don't close chat, just navigate to cinema locator
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CinemaLocatorScreen(),
      ),
    );
  }

  Widget _buildMovieBookingActions(Map<String, dynamic> actionData) {
    final String movieName = actionData['movie_name'] ?? '';
    
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            if (movieName.isNotEmpty) {
              _navigateToSpecificMovieBooking(movieName);
            } else {
              _navigateToMovieBooking();
            }
          },
          icon: const Icon(Icons.confirmation_number),
          label: Text(movieName.isNotEmpty ? 'Book $movieName' : 'Book Tickets'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            _navigateToMovieScreen();
          },
          icon: const Icon(Icons.movie),
          label: const Text('Browse Movies'),
        ),
      ],
    );
  }

  void _navigateToSpecificMovieBooking(String movieName) async {
    try {
      // Don't close chat, just navigate to the movie
      
      // Try to find the movie in the database
      final movieService = MovieService();
      final movies = await movieService.getFirestoreMovies();
      
      // Find the movie by name (case-insensitive)
      BannerMovie? foundMovie;
      try {
        foundMovie = movies.firstWhere(
          (movie) => movie.title.toLowerCase().contains(movieName.toLowerCase()),
        );
      } catch (e) {
        foundMovie = null;
      }
      
        if (foundMovie != null) {
          // Movie found - navigate to showtime selection (user needs to pick date/time/cinema first)
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ShowtimeSelectionScreen(
                movie: {
                  'id': foundMovie!.id,
                  'title': foundMovie!.title,
                  'overview': foundMovie!.overview ?? '',
                  'poster_path': foundMovie!.posterPath ?? '',
                  'backdrop_path': foundMovie!.backdropPath ?? '',
                  'vote_average': foundMovie!.voteAverage ?? 0.0,
                  'release_date': foundMovie!.releaseDate,
                  'genres': foundMovie!.genres ?? [],
                  'runtime': foundMovie!.runtime ?? 120,
                  'adult': false,
                  'original_language': 'en',
                  'original_title': foundMovie!.title,
                  'popularity': 0.0,
                  'video': false,
                  'vote_count': 0,
                  // Add required cinema data for ShowtimeSelectionScreen
                  'cinemaBrands': ['LFS', 'GSC', 'mmCineplexes'], // All available cinema brands
                  'showtimes': {
                    'LFS': ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM'],
                    'GSC': ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM'],
                    'mmCineplexes': ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM'],
                  },
                },
              ),
            ),
          );
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found "$movieName"! Taking you to showtime selection...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Movie not found - navigate to movie screen with search hint
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DiscoverMoviesScreen(),
          ),
        );
        
        // Show helpful message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Movie "$movieName" not found. Please search in the movies section.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      // Error occurred - fallback to movie screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DiscoverMoviesScreen(),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding movie. Please search manually.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildQuickReplies(List<String> replies) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: replies.map((reply) {
        return InkWell(
          onTap: () {
            _handleQuickReplyAction(reply);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ColorApp.primaryDarkColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorApp.primaryDarkColor.withOpacity(0.3)),
            ),
            child: Text(
              reply,
              style: TextStyle(
                color: ColorApp.primaryDarkColor,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMovieInfoActions(Map<String, dynamic> actionData) {
    final String movieName = actionData['movie_name'] ?? '';
    
    return ElevatedButton.icon(
      onPressed: () {
        _navigateToMovieScreen();
        if (movieName.isNotEmpty) {
          // Show helpful message about searching for the movie
          Future.delayed(const Duration(milliseconds: 500), () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Search for "$movieName" to see details'),
                backgroundColor: ColorApp.primaryDarkColor,
              ),
            );
          });
        }
      },
      icon: const Icon(Icons.movie),
      label: Text(movieName.isNotEmpty ? 'View $movieName Details' : 'View Details'),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorApp.primaryDarkColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ColorApp.primaryDarkColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double animationValue = _animationController.value;
        final double delay = index * 0.2;
        final double opacity = (animationValue - delay).clamp(0.0, 1.0);
        
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickActionChip('🎬 Movies Today', 'What movies are showing today?'),
            const SizedBox(width: 8),
            _buildQuickActionChip('🎫 Book Tickets', 'I want to book movie tickets'),
            const SizedBox(width: 8),
            _buildQuickActionChip('📍 Locations', 'Show me cinema locations'),
            const SizedBox(width: 8),
            _buildQuickActionChip('💰 Pricing', 'What are the ticket prices?'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label, String message) {
    return InkWell(
      onTap: () {
        _handleQuickReplyAction(message);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: ColorApp.primaryDarkColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  // Get user-specific chat history key
  String _getChatHistoryKey() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return 'chat_history_${user.uid}';
    }
    return 'chat_history_anonymous';
  }

  String _getLastResetKey() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return 'last_chat_reset_${user.uid}';
    }
    return 'last_chat_reset_anonymous';
  }

  // Chat History Management
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatHistoryKey = _getChatHistoryKey();
      final lastResetKey = _getLastResetKey();
      
      final chatHistoryJson = prefs.getString(chatHistoryKey);
      final lastResetTime = prefs.getInt(lastResetKey) ?? 0;
      
      // Check if 30 minutes have passed since last reset
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceReset = now - lastResetTime;
      
      if (timeSinceReset >= _chatResetDuration.inMilliseconds) {
        // Reset chat history
        await _resetChatHistory();
        return;
      }
      
      if (chatHistoryJson != null) {
        final List<dynamic> chatData = jsonDecode(chatHistoryJson);
        final List<ChatMessage> loadedMessages = chatData.map((data) {
          return ChatMessage.fromJson(data);
        }).toList();
        
        setState(() {
          _messages.addAll(loadedMessages);
        });
        
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        // No chat history, add welcome message
        _addWelcomeMessage();
      }
    } catch (e) {
      print('Error loading chat history: $e');
      _addWelcomeMessage();
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatHistoryKey = _getChatHistoryKey();
      final chatData = _messages.map((message) => message.toJson()).toList();
      await prefs.setString(chatHistoryKey, jsonEncode(chatData));
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  Future<void> _resetChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatHistoryKey = _getChatHistoryKey();
      final lastResetKey = _getLastResetKey();
      
      await prefs.remove(chatHistoryKey);
      await prefs.setInt(lastResetKey, DateTime.now().millisecondsSinceEpoch);
      
      setState(() {
        _messages.clear();
      });
      
      _addWelcomeMessage();
    } catch (e) {
      print('Error resetting chat history: $e');
    }
  }

  void _startResetTimer() {
    _resetTimer = Timer(_chatResetDuration, () {
      _resetChatHistory();
      _startResetTimer(); // Restart timer for next reset
    });
  }

  // Method to clear all chat history (useful for logout or admin purposes)
  Future<void> clearAllChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Remove all chat history keys
      for (String key in keys) {
        if (key.startsWith('chat_history_') || key.startsWith('last_chat_reset_')) {
          await prefs.remove(key);
        }
      }
      
      print('All chat history cleared');
    } catch (e) {
      print('Error clearing all chat history: $e');
    }
  }
}
