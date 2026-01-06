import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About CINELOOK',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Title Section
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ColorApp.primaryDarkColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.movie_outlined,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CINELOOK',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: ColorApp.primaryDarkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // App Description
            _buildSection(
              title: 'About the App',
              content: 'CINELOOK is your ultimate cinema companion app that brings the magic of movies right to your fingertips. Experience seamless movie booking, discover new films, and manage your cinema experience all in one place.',
            ),
            
            const SizedBox(height: 24),
            
            // Features Section
            _buildSection(
              title: 'Features',
              child: Column(
                children: [
                  _buildFeatureItem(
                    icon: Icons.search,
                    title: 'Browse & Discover',
                    description: 'Explore a vast collection of movies and find your next favorite film',
                  ),
                  _buildFeatureItem(
                    icon: Icons.confirmation_number,
                    title: 'Easy Booking',
                    description: 'Book movie tickets seamlessly with just a few taps',
                  ),
                  _buildFeatureItem(
                    icon: Icons.schedule,
                    title: 'Showtimes',
                    description: 'View cinema showtimes and plan your movie experience',
                  ),
                  _buildFeatureItem(
                    icon: Icons.person,
                    title: 'Profile Management',
                    description: 'Manage your profile, bookings, and preferences',
                  ),
                  _buildFeatureItem(
                    icon: Icons.auto_awesome,
                    title: 'Personal Recommendations',
                    description: 'Get personalized movie recommendations based on your viewing history and preferences',
                  ),
                  _buildFeatureItem(
                    icon: Icons.feedback,
                    title: 'Feedback System',
                    description: 'Send feedback and suggestions to help us improve',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Technology Section
            _buildSection(
              title: 'Technology',
              content: 'Built with Flutter framework for cross-platform compatibility and smooth performance. Powered by Firebase for secure authentication and real-time data management.',
            ),
            
            const SizedBox(height: 24),
            
            // Contact Section
            _buildSection(
              title: 'Contact & Support',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactItem(Icons.email, 'support@cinelook.com'),
                  _buildContactItem(Icons.web, 'www.cinelook.com'),
                  _buildContactItem(Icons.phone, '+1 (555) 123-4567'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Footer
            Center(
              child: Column(
                children: [
                  const Text(
                    'Developed with ❤️ using Flutter',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '© 2024 CINELOOK. All rights reserved.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? content,
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ColorApp.primaryDarkColor,
          ),
        ),
        const SizedBox(height: 12),
        if (content != null)
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        if (child != null) child,
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ColorApp.primaryDarkColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: ColorApp.primaryDarkColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: ColorApp.primaryDarkColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
} 