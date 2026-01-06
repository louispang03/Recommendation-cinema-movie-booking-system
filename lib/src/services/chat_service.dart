import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:fyp_cinema_app/src/model/chat/chat_message.dart';
import 'package:fyp_cinema_app/src/services/movie_service.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final MovieService _movieService = MovieService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Configuration flags
  static const bool USE_DIFY = true; // Re-enable Dify with fixed configuration
  static const bool USE_OPENAI_FALLBACK = false; // Disabled - OpenAI quota exhausted
  static const bool ENABLE_DEBUG_LOGS = true;
  
  // Dify Configuration
  static const String DIFY_API_URL = 'https://api.dify.ai/v1/chat-messages'; // Current format
  static String get DIFY_API_KEY => dotenv.env['DIFY_API_KEY'] ?? '';
  
  // Store conversation IDs per user to maintain separate chat histories
  static final Map<String, String> _userConversationIds = {};
  
  // Generate a UUID v4 for conversation IDs
  String _generateUUID() {
    final random = Random();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    
    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant bits
    
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
  
  // Clear conversation IDs when user switches (call this on logout)
  static void clearUserConversation(String userId) {
    _userConversationIds.remove(userId);
    if (ENABLE_DEBUG_LOGS) print('[ChatService] Cleared conversation ID for user: $userId');
  }
  
  // Clear all conversation IDs (call this on app restart or when needed)
  static void clearAllConversations() {
    _userConversationIds.clear();
    if (ENABLE_DEBUG_LOGS) print('[ChatService] Cleared all conversation IDs');
  }
  
  // Force refresh movie data (call this when admin adds new movies)
  Future<void> refreshMovieData() async {
    try {
      if (ENABLE_DEBUG_LOGS) print('[ChatService] Refreshing movie data...');
      await _movieService.getFirestoreMovies(); // This will refresh the cache
      if (ENABLE_DEBUG_LOGS) print('[ChatService] Movie data refreshed successfully');
    } catch (e) {
      if (ENABLE_DEBUG_LOGS) print('[ChatService] Error refreshing movie data: $e');
    }
  }
  
  Future<ChatResponse> sendMessage(String message) async {
    try {
      if (ENABLE_DEBUG_LOGS) print('[ChatService] Processing message: "$message"');
      
      // Handle welcome message
      if (message.toLowerCase().trim() == 'welcome' || message.toLowerCase().trim() == 'start') {
        return ChatResponse(
          text: "👋 Hi! I'm your CINELOOK Assistant! 🎬\n\n"
                "I can help you with:\n\n"
                "🎬 **Movies** - Find current movies and showtimes\n"
                "🎫 **Booking** - Book tickets for any movie\n"
                "🏢 **Locations** - Find nearby cinemas\n"
                "❓ **FAQ** - Common questions and help\n\n"
                "What would you like to do?",
          messageType: ChatMessageType.text,
          actionData: {
            'type': 'quick_replies',
            'replies': ['Show Movies', 'Book Tickets', 'Find Cinemas', 'FAQ'],
          },
        );
      }
      
      if (USE_DIFY) {
        // PRIMARY: Use Dify AI Platform
        try {
          if (ENABLE_DEBUG_LOGS) print('[ChatService] 🚀 Sending to Dify AI...');
          final difyResponse = await _sendToDify(message);
          if (ENABLE_DEBUG_LOGS) print('[ChatService] ✅ Dify response received successfully');
          
           // Enhance Dify response with actionable buttons
           final enhancedResponse = await _enhanceWithLocalActions(difyResponse, message);
           return enhancedResponse;
          
        } catch (e) {
          if (ENABLE_DEBUG_LOGS) print('[ChatService] ❌ Dify failed: $e');
          
          if (USE_OPENAI_FALLBACK) {
            if (ENABLE_DEBUG_LOGS) print('[ChatService] 🔄 Falling back to OpenAI...');
             try {
               final openAIResponse = await _sendToOpenAI(message);
               return await _enhanceWithLocalActions(openAIResponse, message);
            } catch (openAIError) {
              if (ENABLE_DEBUG_LOGS) print('[ChatService] ❌ OpenAI fallback also failed: $openAIError');
            }
          }
          
          // Final fallback to local system
          if (ENABLE_DEBUG_LOGS) print('[ChatService] 🏠 Using local system as final fallback...');
          final intent = _analyzeIntent(message.toLowerCase());
          return await _generateResponse(intent, message);
        }
      } else {
        // Direct to local system when Dify is disabled
        if (ENABLE_DEBUG_LOGS) print('[ChatService] 🏠 Using local system directly...');
        final intent = _analyzeIntent(message.toLowerCase());
        return await _generateResponse(intent, message);
      }
      
    } catch (e) {
      if (ENABLE_DEBUG_LOGS) print('[ChatService] ❌ Critical error: $e');
      return ChatResponse(
        text: "I'm sorry, I'm having trouble understanding that. Could you please rephrase your question?",
        messageType: ChatMessageType.error,
      );
    }
  }

  Future<ChatResponse> _enhanceWithLocalActions(ChatResponse difyResponse, String originalMessage) async {
    // Use Dify's response directly - don't override it with our own movie list
    final lowerResponse = difyResponse.text.toLowerCase();
    final lowerMessage = originalMessage.toLowerCase();
    
    Map<String, dynamic>? actionData;
    String enhancedText = difyResponse.text; // Use Dify's response as-is
    
    if (ENABLE_DEBUG_LOGS) {
      print('[Enhance] Using Dify response directly: ${difyResponse.text}');
    }
    
    // Provide helpful action buttons based on the bot's response content, not user patterns
    // This way, regardless of how the user asks, if the bot provides relevant info, we show appropriate actions
    
    // 1. If bot mentions movies, films, or recommendations - show movie-related actions
    if (lowerResponse.contains('movie') || lowerResponse.contains('film') || 
        lowerResponse.contains('recommend') || lowerResponse.contains('⭐') || 
        lowerResponse.contains('showing') || lowerResponse.contains('cinema')) {
      
      // Check if user mentioned a specific movie for booking
      final movieName = await _extractMovieName(originalMessage);
      
      if (movieName.isNotEmpty && (lowerMessage.contains('book') || lowerMessage.contains('ticket'))) {
        actionData = {
          'type': 'movie_booking',
          'movie_name': movieName,
        };
      } else {
        actionData = {
          'type': 'quick_replies',
          'replies': ['Show current movies', 'Book tickets'],
        };
      }
    }
    // 2. If bot mentions locations, addresses, or cinema names - show location actions
    else if (lowerResponse.contains('location') || lowerResponse.contains('address') || 
             lowerResponse.contains('gsc') || lowerResponse.contains('lfs') || 
             lowerResponse.contains('mmcineplexes') || lowerResponse.contains('where')) {
      actionData = {
        'type': 'cinema_locations',
        'replies': ['Find nearest cinema', 'All locations'],
      };
    }
    // 3. If bot provides pricing information - show pricing actions
    else if (lowerResponse.contains('price') || lowerResponse.contains('cost') || 
             lowerResponse.contains('pricing') || lowerResponse.contains('rm') ||
             lowerResponse.contains('ticket price') || lowerResponse.contains('discount')) {
      actionData = {
        'type': 'quick_replies',
        'replies': ['Book Tickets', 'Find Cinemas', 'Show Movies', 'More Help'],
      };
    }
    // 4. If bot provides help, FAQ, or assistance - show help actions
    else if (lowerResponse.contains('help') || lowerResponse.contains('assist') || 
             lowerResponse.contains('faq') || lowerResponse.contains('question') ||
             lowerResponse.contains('support')) {
      actionData = {
        'type': 'quick_replies',
        'replies': ['Show movies', 'Book tickets', 'Find cinemas', 'FAQ'],
      };
    }
    // 5. If bot mentions booking, tickets, or showtimes - show booking actions
    else if (lowerResponse.contains('book') || lowerResponse.contains('ticket') || 
             lowerResponse.contains('showtime') || lowerResponse.contains('available') ||
             lowerResponse.contains('reserve') || lowerResponse.contains('buy')) {
      actionData = {
        'type': 'quick_replies',
        'replies': ['Book tickets', 'Show current movies'],
      };
    }
    // 6. For any other response, provide general helpful actions
    else {
      actionData = {
        'type': 'quick_replies',
        'replies': ['Show movies', 'Book tickets', 'Find cinemas', 'Help'],
      };
    }
    
    // Return enhanced response with action data
    return ChatResponse(
      text: enhancedText,
      messageType: difyResponse.messageType,
      actionData: actionData ?? difyResponse.actionData,
    );
  }

  bool _shouldUseOpenAI(String message) {
    // Use OpenAI for complex queries that our local system might not handle well
    final complexPatterns = [
      'recommend', 'suggest', 'opinion', 'think', 'feel', 'compare',
      'better', 'best', 'worst', 'review', 'rating', 'quality',
      'plot', 'story', 'ending', 'character', 'actor performance',
      'similar to', 'like', 'genre preference', 'mood'
    ];
    
    final lowerMessage = message.toLowerCase();
    return complexPatterns.any((pattern) => lowerMessage.contains(pattern));
  }

  ChatIntent _analyzeIntent(String message) {
    // Movies and showtimes
    if (message.contains('movie') || message.contains('film') || 
        message.contains('showing') || message.contains('showtimes') || 
        message.contains('what movies') || message.contains('tonight') ||
        message.contains('today') || message.contains('schedule') ||
        message.contains('recommend') || message.contains('suggest')) {
      return ChatIntent.movieShowtimes;
    }
    
    // Booking tickets
    if (message.contains('book') || message.contains('ticket') || 
        message.contains('reserve') || message.contains('buy') ||
        message.contains('seat')) {
      return ChatIntent.bookTickets;
    }
    
    // Cinema locations
    if (message.contains('location') || message.contains('cinema') || 
        message.contains('where') || message.contains('address') ||
        message.contains('near me') || message.contains('find cinema')) {
      return ChatIntent.cinemaLocations;
    }
    
    // Pricing queries
    if (message.contains('price') || message.contains('cost') || 
        message.contains('pricing') || message.contains('ticket price') ||
        message.contains('how much') || message.contains('fee') ||
        message.contains('discount') || message.contains('promotion')) {
      return ChatIntent.pricing;
    }
    
    // FAQ and Help
    if (message.contains('help') || message.contains('how') || 
        message.contains('?') || message.contains('faq') ||
        message.contains('cancel') || message.contains('refund') ||
        message.contains('about') || message.contains('info')) {
      return ChatIntent.help;
    }
    
    return ChatIntent.general;
  }

  Future<ChatResponse> _generateResponse(ChatIntent intent, String originalMessage) async {
    switch (intent) {
      case ChatIntent.movieShowtimes:
        return await _handleMovieShowtimes(originalMessage);
      
      case ChatIntent.bookTickets:
        return await _handleBookTickets(originalMessage);
      
      case ChatIntent.cinemaLocations:
        return _handleCinemaLocations();
      
      case ChatIntent.pricing:
        return _handlePricing();
      
      case ChatIntent.help:
        return _handleFAQ();
      
      case ChatIntent.general:
      default:
        return _handleGeneral();
    }
  }

  Future<ChatResponse> _handleMovieShowtimes(String message) async {
    try {
      // Extract time preference from message
      String timeFilter = '';
      if (message.contains('tonight') || message.contains('evening')) {
        timeFilter = 'evening';
      } else if (message.contains('morning')) {
        timeFilter = 'morning';
      } else if (message.contains('afternoon')) {
        timeFilter = 'afternoon';
      }

      // Fetch current movies from Firebase database
      final moviesList = await _movieService.getFirestoreMovies();
      
      if (moviesList.isEmpty) {
        return ChatResponse(
          text: "I'm sorry, I couldn't find any movies currently showing. Please check back later or contact customer service.",
          messageType: ChatMessageType.text,
        );
      }

      // Generate response with movie listings from Firebase
      String responseText = "🎬 Here are the movies currently showing:\n\n";
      
      for (int i = 0; i < moviesList.length && i < 5; i++) {
        final movie = moviesList[i];
        final rating = movie.voteAverage ?? 0;
        final year = movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : '';
        
        responseText += "🎭 ${movie.title}";
        if (year.isNotEmpty) responseText += " ($year)";
        if (rating > 0) responseText += " ⭐ ${rating.toStringAsFixed(1)}/10";
        responseText += "\n";
        
        if (movie.genres != null && movie.genres!.isNotEmpty) {
          responseText += "🎪 ${movie.genres!.take(2).join(', ')}\n";
        }
        responseText += "⏰ Showtimes: 2:00 PM, 5:00 PM, 8:00 PM, 11:00 PM\n";
        responseText += "🏢 Available at: GSC, LFS, mmCineplexes\n\n";
      }

      responseText += "Would you like to book tickets for any of these movies?";

      return ChatResponse(
        text: responseText,
        messageType: ChatMessageType.movieInfo,
        actionData: {
          'type': 'quick_replies',
          'replies': ['Book tickets', 'Show more movies', 'Cinema locations'],
        },
      );
    } catch (e) {
      print('Error fetching movies for chat: $e');
      
      // Provide fallback response with popular movie suggestions
      return ChatResponse(
        text: "🎬 **Popular Movies Currently Available:**\n\n"
              "🎭 **Spider-Man: No Way Home**\n"
              "⏰ Showtimes: 2:00 PM, 5:00 PM, 8:00 PM, 11:00 PM\n"
              "🏢 Available at: GSC, LFS, mmCineplexes\n\n"
              "🎭 **Avatar: The Way of Water**\n"
              "⏰ Showtimes: 1:30 PM, 4:30 PM, 7:30 PM, 10:30 PM\n"
              "🏢 Available at: GSC, LFS, mmCineplexes\n\n"
              "🎭 **Black Panther: Wakanda Forever**\n"
              "⏰ Showtimes: 3:00 PM, 6:00 PM, 9:00 PM\n"
              "🏢 Available at: GSC, LFS, mmCineplexes\n\n"
              "💡 For the most up-to-date showtimes, please check our Movies section in the app!",
        messageType: ChatMessageType.movieInfo,
        actionData: {
          'type': 'quick_replies',
          'replies': ['Book tickets', 'View all movies', 'Cinema locations'],
        },
      );
    }
  }

  Future<ChatResponse> _handleBookTickets(String message) async {
    // Extract movie name if mentioned
    String movieName = await _extractMovieName(message);
    
    if (movieName.isNotEmpty) {
      return ChatResponse(
        text: "Great! I'd love to help you book tickets for **$movieName**! 🎬\n\n"
              "I'll take you to the booking page where you can:\n"
              "📅 Select your preferred date\n"
              "⏰ Choose showtime\n"
              "🏢 Pick cinema location\n"
              "💺 Select your seats\n\n"
              "Ready to book your tickets?",
        messageType: ChatMessageType.actionRequired,
        actionData: {
          'type': 'movie_booking',
          'movie_name': movieName,
        },
      );
    } else {
      return ChatResponse(
        text: "I'd be happy to help you book movie tickets! 🎫\n\n"
              "I can take you directly to our movie selection where you can:\n"
              "🎬 Browse current movies\n"
              "📱 See detailed information\n"
              "🎟️ Start booking process\n\n"
              "What would you like to do?",
        messageType: ChatMessageType.text,
        actionData: {
          'type': 'quick_replies',
          'replies': ['Book tickets', 'Show current movies', 'Popular movies'],
        },
      );
    }
  }

  ChatResponse _handleCinemaLocations() {
    return ChatResponse(
      text: "🏢 **Finding Cinema Locations for You!**\n\n"
            "I'll take you to our interactive cinema locator where you can:\n\n"
            "📍 **Find Nearest Cinema**\n"
            "• Use your current location\n"
            "• See distance and directions\n\n"
            "🎬 **Browse All Locations**\n"
            "• GSC, LFS, mmCineplexes\n"
            "• Filter by cinema brand\n"
            "• Check facilities and amenities\n\n"
            "🚗 **Get Directions**\n"
            "• Real-time navigation\n"
            "• Parking information\n\n"
            "Taking you to the cinema locator now...",
      messageType: ChatMessageType.actionRequired,
      actionData: {
        'type': 'cinema_locations',
        'replies': ['Find nearest cinema', 'All locations', 'Book tickets'],
      },
    );
  }

  ChatResponse _handlePricing() {
    return ChatResponse(
      text: "💰 **Ticket Pricing Information**\n\n"
            "**🎫 STANDARD TICKETS**\n"
            "• Adult: RM 15-18\n"
            "• Student: RM 12-15 (with valid ID)\n"
            "• Senior (60+): RM 10-12\n"
            "• Child (3-12): RM 8-10\n\n"
            "**🎬 PREMIUM EXPERIENCES**\n"
            "• IMAX: RM 20-25\n"
            "• Dolby Atmos: RM 18-22\n"
            "• VIP Hall: RM 25-30\n"
            "• 3D Movies: +RM 3-5\n\n"
            "**🎁 DISCOUNTS & PROMOTIONS**\n"
            "• Early Bird (before 2 PM): -RM 2\n"
            "• Group Booking (4+): -RM 1 per ticket\n"
            "• Student Wednesday: 20% off\n"
            "• Senior Tuesday: 30% off\n\n"
            "**🍿 FOOD & BEVERAGES**\n"
            "• Combo Meals: RM 15-25\n"
            "• Popcorn: RM 8-12\n"
            "• Drinks: RM 5-8\n\n"
            "💡 *Prices may vary by cinema location and movie type*",
      messageType: ChatMessageType.text,
      actionData: {
        'type': 'quick_replies',
        'replies': ['Book Tickets', 'Find Cinemas', 'Show Movies', 'More Help'],
      },
    );
  }


  ChatResponse _handleFAQ() {
    return ChatResponse(
      text: "❓ **Frequently Asked Questions**\n\n"
            "**🎬 MOVIES**\n"
            "• What movies are showing? → I'll show you current movies\n"
            "• What time is [movie]? → I'll find showtimes\n"
            "• Recommend a movie → I'll suggest based on your mood\n\n"
            "**🎫 BOOKING**\n"
            "• How to book tickets? → I'll take you to booking\n"
            "• Book [movie name] → I'll find and book that movie\n"
            "• Can I choose seats? → Yes! You can select your seats\n\n"
            "**🏢 LOCATIONS**\n"
            "• Where are the cinemas? → I'll show you all locations\n"
            "• Find nearest cinema → I'll use your location\n"
            "• What cinemas are available? → GSC, LFS, mmCineplexes\n\n"
            "**💰 PRICING**\n"
            "• How much are tickets? → RM 12-18 (varies by cinema)\n"
            "• Any discounts? → Student, senior, children discounts available\n\n"
            "**❓ OTHER**\n"
            "• Can I cancel? → Yes, up to 2 hours before showtime\n"
            "• Refund policy? → Full refund with processing fee\n\n"
            "Need more help? Just ask!",
      messageType: ChatMessageType.text,
      actionData: {
        'type': 'quick_replies',
        'replies': ['Show Movies', 'Book Tickets', 'Find Cinemas', 'More Help'],
      },
    );
  }

  ChatResponse _handleGeneral() {
    return ChatResponse(
      text: "I'm here to help! I can assist you with:\n\n"
            "🎬 **Movies** - Find current movies and showtimes\n"
            "🎫 **Booking** - Book tickets for any movie\n"
            "🏢 **Locations** - Find nearby cinemas\n"
            "❓ **FAQ** - Common questions and help\n\n"
            "What would you like to do?",
      messageType: ChatMessageType.text,
      actionData: {
        'type': 'quick_replies',
        'replies': ['Show Movies', 'Book Tickets', 'Find Cinemas', 'FAQ'],
      },
    );
  }

  Future<String> _extractMovieName(String message) async {
    // Enhanced movie name extraction with dynamic database movies
    final lowerMessage = message.toLowerCase();
    
    try {
      // Get current movies from database
      final moviesList = await _movieService.getFirestoreMovies();
      
      // Create dynamic movie patterns from database
      final moviePatterns = <String, String>{};
      
      for (final movie in moviesList) {
        final title = movie.title;
        final lowerTitle = title.toLowerCase();
        
        // Add exact title match
        moviePatterns[lowerTitle] = title;
        
        // Add partial matches for common words
        final words = lowerTitle.split(' ');
        for (final word in words) {
          if (word.length > 3 && !_isCommonWord(word)) {
            moviePatterns[word] = title;
          }
        }
        
        // Add common variations
        if (lowerTitle.contains(':')) {
          final beforeColon = lowerTitle.split(':')[0].trim();
          moviePatterns[beforeColon] = title;
        }
        
        if (lowerTitle.contains(' - ')) {
          final beforeDash = lowerTitle.split(' - ')[0].trim();
          moviePatterns[beforeDash] = title;
        }
      }
      
      // Add static popular movies as fallback
      final staticPatterns = {
        'spider-man': 'Spider-Man',
        'spiderman': 'Spider-Man',
        'avatar': 'Avatar',
        'batman': 'Batman',
        'avengers': 'Avengers',
        'iron man': 'Iron Man',
        'captain america': 'Captain America',
        'black panther': 'Black Panther',
        'doctor strange': 'Doctor Strange',
        'guardians of the galaxy': 'Guardians of the Galaxy',
        'thor': 'Thor',
        'hulk': 'Hulk',
        'ant-man': 'Ant-Man',
        'antman': 'Ant-Man',
        'fast and furious': 'Fast & Furious',
        'john wick': 'John Wick',
        'mission impossible': 'Mission: Impossible',
        'transformers': 'Transformers',
        'jurassic': 'Jurassic Park',
        'star wars': 'Star Wars',
        'harry potter': 'Harry Potter',
        'lord of the rings': 'Lord of the Rings',
        'hobbit': 'The Hobbit',
        'matrix': 'The Matrix',
        'terminator': 'Terminator',
        'alien': 'Alien',
        'predator': 'Predator',
        'godzilla': 'Godzilla',
        'king kong': 'King Kong',
        'pirates of the caribbean': 'Pirates of the Caribbean',
        'indiana jones': 'Indiana Jones',
        'james bond': 'James Bond',
        'top gun': 'Top Gun',
        'deadpool': 'Deadpool',
        'wolverine': 'Wolverine',
        'x-men': 'X-Men',
        'fantastic four': 'Fantastic Four',
      };
      
      moviePatterns.addAll(staticPatterns);
      
      // Check for exact matches first
      for (final entry in moviePatterns.entries) {
        if (lowerMessage.contains(entry.key)) {
          return entry.value;
        }
      }
      
      // Try to extract using regex patterns for quoted titles
      final quotedPattern = RegExp(r'"([^"]+)"');
      final quotedMatch = quotedPattern.firstMatch(message);
      if (quotedMatch != null) {
        return quotedMatch.group(1) ?? '';
      }
      
      // Try to extract movie titles that might be capitalized
      final words = message.split(' ');
      final capitalizedWords = <String>[];
      
      for (int i = 0; i < words.length; i++) {
        final word = words[i];
        if (word.isNotEmpty && word[0].toUpperCase() == word[0] && 
            word.length > 2 && !_isCommonWord(word.toLowerCase())) {
          capitalizedWords.add(word);
          
          // Check if next words are also capitalized (multi-word title)
          if (i + 1 < words.length && words[i + 1].isNotEmpty && 
              words[i + 1][0].toUpperCase() == words[i + 1][0]) {
            capitalizedWords.add(words[i + 1]);
            i++; // Skip the next word since we've added it
          }
          
          if (capitalizedWords.length >= 1) {
            return capitalizedWords.join(' ');
          }
        }
      }
      
    } catch (e) {
      if (ENABLE_DEBUG_LOGS) print('[ChatService] Error extracting movie name: $e');
    }
    
    return '';
  }

  bool _isCommonWord(String word) {
    const commonWords = {
      'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'by', 'from', 'up', 'about', 'into', 'through', 'during', 'before',
      'after', 'above', 'below', 'between', 'among', 'book', 'watch', 'see',
      'movie', 'film', 'cinema', 'ticket', 'tickets', 'show', 'showing',
      'tonight', 'today', 'tomorrow', 'want', 'need', 'like', 'love',
      'can', 'could', 'would', 'should', 'will', 'shall', 'may', 'might',
      'must', 'have', 'has', 'had', 'is', 'are', 'was', 'were', 'be',
      'been', 'being', 'do', 'does', 'did', 'done', 'doing', 'get', 'got',
      'getting', 'give', 'gave', 'given', 'giving', 'go', 'went', 'gone',
      'going', 'come', 'came', 'coming', 'take', 'took', 'taken', 'taking'
    };
    return commonWords.contains(word);
  }

  bool _containsSpecificMovieTitles(String text) {
    // Check if the text contains specific movie titles (not just generic movie references)
    final movieIndicators = [
      'spider-man', 'avatar', 'batman', 'avengers', 'iron man', 'thor',
      'black panther', 'guardians', 'captain america', 'doctor strange',
      'ant-man', 'hulk', 'wolverine', 'deadpool', 'x-men', 'fantastic four',
      'fast and furious', 'john wick', 'mission impossible', 'transformers',
      'jurassic', 'star wars', 'harry potter', 'lord of the rings', 'hobbit',
      'matrix', 'terminator', 'alien', 'predator', 'godzilla', 'king kong',
      'pirates of the caribbean', 'indiana jones', 'james bond', 'top gun'
    ];
    
    return movieIndicators.any((title) => text.contains(title));
  }

  // Note: _isMovieRelatedQuery removed - not needed with Knowledge Base method
  // Dify will handle all queries using the knowledge base

  // Clean up markdown formatting from AI responses
  String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove **bold** but keep content
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')       // Remove `code`
        .replaceAll(RegExp(r'#+\s*'), '')            // Remove # headers
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1') // Remove [link](url) -> link
        .replaceAll(RegExp(r'\$1\s*'), '')           // Remove $1 placeholders
        .replaceAll(RegExp(r'\$\d+\s*'), '')         // Remove $number placeholders
        .replaceAll(RegExp(r'\n+'), '\n')            // Clean up multiple newlines
        .trim();
  }

  // Check if response is in a non-English language
  bool _isNonEnglishResponse(String text) {
    if (text.isEmpty) return false;
    
    // If the text is mostly English (contains common English words), don't flag as non-English
    final englishIndicators = [
      'the', 'and', 'you', 'that', 'have', 'for', 'not', 'with', 'this', 'but', 'his', 'by', 'from',
      'they', 'she', 'her', 'been', 'than', 'more', 'will', 'about', 'if', 'up', 'out', 'many',
      'then', 'them', 'can', 'only', 'other', 'new', 'some', 'what', 'time', 'very', 'when', 'much',
      'movie', 'cinema', 'ticket', 'book', 'show', 'time', 'recommend', 'action', 'comedy', 'horror',
      'thriller', 'drama', 'rating', 'director', 'starring', 'film', 'based', 'current', 'listings'
    ];
    
    final lowerText = text.toLowerCase();
    int englishWordCount = 0;
    final words = lowerText.split(RegExp(r'\s+'));
    
    for (final word in words) {
      if (englishIndicators.contains(word)) {
        englishWordCount++;
      }
    }
    
    // If more than 30% of words are English indicators, consider it English
    if (words.length > 0 && (englishWordCount / words.length) > 0.3) {
      return false;
    }
    
    // Check for specific non-English patterns (more restrictive)
    final nonEnglishPatterns = [
      RegExp(r'[αβγδεζηθικλμνξοπρστυφχψω]', caseSensitive: false), // Greek
      RegExp(r'[абвгдеёжзийклмнопрстуфхцчшщъыьэюя]', caseSensitive: false), // Cyrillic
      RegExp(r'[一-龯]'), // Chinese characters
      RegExp(r'[ひらがなカタカナ]'), // Japanese hiragana/katakana
      RegExp(r'[가-힣]'), // Korean
      RegExp(r'[ا-ي]'), // Arabic
    ];
    
    // Check for non-English patterns
    for (final pattern in nonEnglishPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    
    // Check for common non-English words/phrases (more restrictive)
    final nonEnglishWords = [
      'bonjour', 'salut', 'merci', 'français', 'française',
      'hola', 'gracias', 'español', 'española',
      'ciao', 'grazie', 'italiano', 'italiana',
      'hallo', 'danke', 'deutsch', 'deutsche',
      'olá', 'obrigado', 'português', 'portuguesa',
      'привет', 'спасибо', 'русский', 'русская',
      'こんにちは', 'ありがとう', '日本語',
      '안녕하세요', '감사합니다', '한국어',
      '你好', '谢谢', '中文',
      'مرحبا', 'شكرا', 'عربي',
      'नमस्ते', 'धन्यवाद', 'हिंदी',
    ];
    
    for (final word in nonEnglishWords) {
      if (lowerText.contains(word)) {
        return true;
      }
    }
    
    return false;
  }

  // Dify AI Platform Integration (Hybrid: Knowledge Base + Real-time Variables)
  Future<ChatResponse> _sendToDify(String message) async {
    try {
      Map<String, dynamic> inputs = {};
      
      // Send comprehensive movie data for real-time updates
      try {
        final moviesList = await _movieService.getFirestoreMovies();
        if (moviesList.isNotEmpty) {
          // Send basic info for real-time updates
          inputs['total_movies_count'] = moviesList.length;
          inputs['last_updated'] = DateTime.now().toIso8601String();
          
          // Send detailed movie information for all movies
          final moviesData = moviesList.map((movie) => {
            'title': movie.title,
            'overview': movie.overview ?? '',
            'genres': movie.genres?.join(', ') ?? '',
            'release_date': movie.releaseDate,
            'rating': movie.voteAverage ?? 0.0,
            'poster_url': movie.posterPath ?? '',
            'backdrop_url': movie.backdropPath ?? '',
            'original_language': movie.originalLanguage ?? 'en',
            'runtime': movie.runtime ?? 0,
            'is_coming_soon': movie.isComingSoon,
            'is_bookable': movie.isBookable,
            'categories': movie.categories?.join(', ') ?? '',
            'cinema_brands': movie.cinemaBrands?.join(', ') ?? '',
          }).toList();
          
          inputs['movies_data'] = moviesData;
          
          // Send recent movies (last 5) for quick reference
          final recentMovies = moviesList.take(5).map((movie) => '${movie.title} (${movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : 'N/A'})').join(', ');
          inputs['recent_movies'] = recentMovies.length > 100 ? recentMovies.substring(0, 100) + '...' : recentMovies;
          
          // Send movie titles for quick search
          final movieTitles = moviesList.map((movie) => movie.title).join(', ');
          inputs['movie_titles'] = movieTitles.length > 200 ? movieTitles.substring(0, 200) + '...' : movieTitles;
          
          if (ENABLE_DEBUG_LOGS) {
            print('[Dify] Hybrid method: Knowledge Base + Real-time updates');
            print('[Dify] Total movies: ${moviesList.length}');
            print('[Dify] Recent movies: $recentMovies');
            print('[Dify] Movie titles: ${movieTitles.substring(0, movieTitles.length > 50 ? 50 : movieTitles.length)}...');
          }
        }
      } catch (e) {
        print('[Dify] Error fetching real-time movie data: $e');
      }
      
      // Add language instruction to ensure English response
      final englishQuery = "Please respond in English only. $message";
      
      // Get or create user-specific conversation ID (maintains same conversation per user)
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      String? existingConversationId = _userConversationIds[userId];
      
      String? conversationId;
      if (existingConversationId != null) {
        // Reuse existing conversation ID
        conversationId = existingConversationId;
        if (ENABLE_DEBUG_LOGS) print('[Dify] Reusing conversation ID for user $userId: $conversationId');
      } else {
        // For new conversations, don't send conversation_id - let Dify create it
        if (ENABLE_DEBUG_LOGS) print('[Dify] Starting new conversation for user $userId (no conversation_id sent)');
      }
      
      final requestBody = {
        'inputs': inputs, // Send movie data as context
        'query': englishQuery,
        'response_mode': 'blocking',
        'user': userId,
        'language': 'en', // Force English language response
      };
      
      // Only add conversation_id if we have one (for continuing existing conversations)
      if (conversationId != null) {
        requestBody['conversation_id'] = conversationId;
      }
      
      if (ENABLE_DEBUG_LOGS) {
        print('[Dify] Request body inputs keys: ${inputs.keys.toList()}');
        print('[Dify] Request body: ${jsonEncode(requestBody)}');
      }
      
      final response = await http.post(
        Uri.parse(DIFY_API_URL),
        headers: {
          'Authorization': 'Bearer $DIFY_API_KEY',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (ENABLE_DEBUG_LOGS) print('[Dify] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final difyResponse = data['answer'] ?? data['message'] ?? '';
        
        // Capture conversation_id from Dify response for future use
        if (data['conversation_id'] != null && conversationId == null) {
          final newConversationId = data['conversation_id'].toString();
          _userConversationIds[userId] = newConversationId;
          if (ENABLE_DEBUG_LOGS) print('[Dify] Captured new conversation ID from Dify: $newConversationId');
        }
        
        // Use Dify response directly without cleaning
        String cleanResponse = difyResponse;
        
        if (ENABLE_DEBUG_LOGS) {
          print('[Dify] Raw response: ${difyResponse.substring(0, difyResponse.length > 200 ? 200 : difyResponse.length)}...');
          print('[Dify] Using response directly without cleaning');
        }
        
        // Check if response is in a non-English language and provide fallback
        if (_isNonEnglishResponse(cleanResponse)) {
          if (ENABLE_DEBUG_LOGS) print('[Dify] Non-English response detected, providing fallback');
          return ChatResponse(
            text: "I'd be happy to help you with movie recommendations! Let me show you our current movies instead.",
            messageType: ChatMessageType.text,
            actionData: {
              'type': 'quick_replies',
              'replies': ['Show Movies', 'Book Tickets', 'Find Cinemas', 'FAQ'],
            },
          );
        }
        
        if (ENABLE_DEBUG_LOGS) print('[Dify] Response: ${cleanResponse.substring(0, cleanResponse.length > 100 ? 100 : cleanResponse.length)}...');
        
        return ChatResponse(
          text: cleanResponse,
          messageType: ChatMessageType.text,
        );
      } else {
        if (ENABLE_DEBUG_LOGS) print('[Dify] API Error: ${response.statusCode} - ${response.body}');
        
        // Handle specific error cases
        if (response.statusCode == 400 && response.body.contains('overloaded')) {
          throw Exception('Dify AI model is temporarily overloaded. Using fallback system.');
        } else if (response.statusCode == 503) {
          throw Exception('Dify service temporarily unavailable. Using fallback system.');
        } else {
          throw Exception('Dify API request failed with status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (ENABLE_DEBUG_LOGS) print('[Dify] Error: $e');
      throw Exception('Failed to get Dify response: $e');
    }
  }

  // OpenAI GPT Integration (Fallback)
  Future<ChatResponse> _sendToOpenAI(String message) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    const apiUrl = 'https://api.openai.com/v1/chat/completions';
    
    // Enhanced system prompt for cinema context with current date
    final currentDate = DateTime.now();
    final systemPrompt = '''
You are CINELOOK Assistant, an AI-powered cinema chatbot for a Malaysian cinema app. Today is ${currentDate.day}/${currentDate.month}/${currentDate.year}.

🎬 YOUR ROLE:
You're a knowledgeable cinema expert who helps users with movie-related queries, bookings, and cinema information. You have access to real-time movie data and can provide intelligent, personalized responses.

🎯 CORE SERVICES:
- Movie recommendations based on preferences, mood, or occasion
- Information about current movies, showtimes, and availability
- Guidance for booking tickets and selecting seats
- Cinema location details (GSC, LFS, mmCineplexes across Malaysia)
- Ticket pricing, discounts, and promotions
- Food & beverage options and pre-ordering
- Booking modifications, cancellations, and refunds

💬 CONVERSATION STYLE:
- Be conversational, friendly, and enthusiastic about movies
- Use emojis naturally to enhance communication
- Ask follow-up questions to better understand user needs
- Provide personalized recommendations based on user preferences
- Be empathetic and helpful with booking issues

🇲🇾 MALAYSIAN CONTEXT:
- Use Malaysian Ringgit (RM) for all pricing
- Reference local cinema chains: GSC, LFS, mmCineplexes
- Consider Malaysian movie preferences and cultural context
- Mention popular locations like KLCC, Mid Valley, 1 Utama when relevant

🎪 SPECIAL FEATURES:
- For movie recommendations, consider user's mood, occasion, and preferences
- Suggest complete movie experiences (IMAX, Dolby Atmos, VIP halls)
- Recommend food combos and pre-ordering for convenience
- Provide insights about movie popularity and ratings

Remember: You're not just answering questions - you're helping create memorable cinema experiences!
''';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': message,
            }
          ],
          'max_tokens': 200,
          'temperature': 0.7,
          'presence_penalty': 0.1,
          'frequency_penalty': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'].toString().trim();
        
        // Analyze the AI response to determine if it needs action buttons
        final actionData = _analyzeAIResponseForActions(aiResponse, message);
        
        return ChatResponse(
          text: aiResponse,
          messageType: ChatMessageType.text,
          actionData: actionData,
        );
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        throw Exception('OpenAI API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      throw Exception('Failed to get AI response: $e');
    }
  }

  Map<String, dynamic>? _analyzeAIResponseForActions(String aiResponse, String originalMessage) {
    final lowerResponse = aiResponse.toLowerCase();
    final lowerMessage = originalMessage.toLowerCase();
    
    // Only show action buttons based on user's actual intent, not bot response content
    // This prevents irrelevant buttons from appearing
    
    // User asked about movies/showtimes - show movie-related actions
    if (lowerMessage.contains('movie') || lowerMessage.contains('film') || 
        lowerMessage.contains('showing') || lowerMessage.contains('showtime') ||
        lowerMessage.contains('recommend') || lowerMessage.contains('what movies')) {
      return {
        'type': 'quick_replies',
        'replies': ['Show current movies', 'Book tickets'],
      };
    }
    
    // User asked about booking - show booking actions
    if (lowerMessage.contains('book') || lowerMessage.contains('ticket') || 
        lowerMessage.contains('reserve') || lowerMessage.contains('buy')) {
      return {
        'type': 'quick_replies',
        'replies': ['Book tickets', 'Show current movies'],
      };
    }
    
    // User asked about locations - show location actions
    if (lowerMessage.contains('location') || lowerMessage.contains('cinema') || 
        lowerMessage.contains('where') || lowerMessage.contains('address') ||
        lowerMessage.contains('find cinema') || lowerMessage.contains('nearest')) {
      return {
        'type': 'quick_replies',
        'replies': ['Find nearest cinema', 'All locations'],
      };
    }
    
    // User asked about pricing - no action buttons needed for simple pricing questions
    if (lowerMessage.contains('price') || lowerMessage.contains('cost') || 
        lowerMessage.contains('pricing') || lowerMessage.contains('how much') ||
        lowerMessage.contains('ticket price') || lowerMessage.contains('discount')) {
      // For simple pricing questions, don't show action buttons
      // User just wants to know prices, not take actions
      return null;
    }
    
    // User asked for help/FAQ - show help actions
    if (lowerMessage.contains('help') || lowerMessage.contains('how') || 
        lowerMessage.contains('faq') || lowerMessage.contains('support') ||
        lowerMessage.contains('cancel') || lowerMessage.contains('refund')) {
      return {
        'type': 'quick_replies',
        'replies': ['Show movies', 'Book tickets', 'Find cinemas', 'FAQ'],
      };
    }
    
    // For general queries or when user intent is unclear, show minimal actions
    return {
      'type': 'quick_replies',
      'replies': ['Show movies', 'Book tickets', 'Find cinemas', 'Help'],
    };
  }
}

enum ChatIntent {
  movieShowtimes,
  bookTickets,
  cinemaLocations,
  pricing,
  help,
  general,
}
