import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/services/recommendation_service.dart';
import 'package:fyp_cinema_app/src/ui/recommendation/recommendation_screen.dart';

class UserPreferenceScreen extends StatefulWidget {
  const UserPreferenceScreen({super.key});

  @override
  State<UserPreferenceScreen> createState() => _UserPreferenceScreenState();
}

class _UserPreferenceScreenState extends State<UserPreferenceScreen> {
  final RecommendationService _recommendationService = RecommendationService();
  
  List<String> _availableGenres = [];
  List<String> _selectedGenres = [];
  
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvailableGenres();
  }

  Future<void> _loadAvailableGenres() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final genres = await _recommendationService.getAvailableGenres();
      setState(() {
        _availableGenres = genres;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }


  Future<void> _getRecommendations() async {
    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one genre'),
          backgroundColor: ColorApp.primaryDarkColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final recommendations = await _recommendationService.getNewUserRecommendations(
        preferredGenres: _selectedGenres,
        preferredActors: null,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RecommendationScreen(
            recommendations: recommendations,
            isFirstTime: true,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting recommendations: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Setup Your Preferences'),
        backgroundColor: ColorApp.primaryDarkColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ColorApp.primaryDarkColor),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading preferences',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadAvailableGenres,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorApp.primaryDarkColor,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ColorApp.primaryDarkColor.withOpacity(0.2), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.movie_filter,
                              size: 48,
                              color: ColorApp.primaryDarkColor,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Welcome to Your Cinema Experience!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tell us about your movie preferences to get personalized recommendations',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Genre selection
                      const Text(
                        'Favorite Genres',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select at least one genre you enjoy watching',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableGenres.map((genre) {
                          final isSelected = _selectedGenres.contains(genre);
                          return FilterChip(
                            label: Text(genre),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedGenres.add(genre);
                                } else {
                                  _selectedGenres.remove(genre);
                                }
                              });
                            },
                            backgroundColor: Colors.grey[800],
                            selectedColor: ColorApp.primaryDarkColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[300],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                      
                    ],
                  ),
                ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(
            top: BorderSide(color: Colors.grey[700]!, width: 1),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _selectedGenres.isNotEmpty ? _getRecommendations : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorApp.primaryDarkColor,
              disabledBackgroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                    'Get My Recommendations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
} 