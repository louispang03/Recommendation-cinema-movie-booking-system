import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/screen/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/ui/screen/feedback_form_screen.dart';
import 'package:fyp_cinema_app/src/ui/screen/about_screen.dart';


class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  
  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = true;

  User? get _currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });
    await _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _userProfile = doc.data();
          _isLoadingProfile = false;
        });
      } else {
        // Create default user profile if it doesn't exist
        final defaultProfile = {
          'name': _currentUser!.displayName ?? 'User',
          'email': _currentUser!.email ?? '',
          'phone': '',
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .set(defaultProfile);
        
        setState(() {
          _userProfile = defaultProfile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoadingProfile = false;
      });
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


  String _buildEmailSubtitle() {
    final currentEmail = _currentUser?.email ?? 'No email';
    return currentEmail;
  }



  Future<void> _showUpdateProfileDialog() async {
    final user = _currentUser;
    if (user == null) return;

    // Use current profile data from Firestore and Firebase Auth
    final nameController = TextEditingController(text: _userProfile?['name'] ?? user.displayName ?? '');
    final phoneController = TextEditingController(text: _userProfile?['phone'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();

              // Validate inputs
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name cannot be empty'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                // Update Firebase Auth display name if changed
                if (user.displayName != newName && newName.isNotEmpty) {
                  try {
                    await user.updateDisplayName(newName);
                    print("Display name updated in Firebase Auth");
                  } catch (displayNameError) {
                    // Check if it's the PigeonUserDetails error
                    if (displayNameError.toString().contains('PigeonUserDetails') || 
                        displayNameError.toString().contains('PigeonUserInfo')) {
                      print("PigeonUserDetails error occurred but display name update might have succeeded");
                      // This is a known platform channel issue, not a functional error
                    } else {
                      print("Error updating display name: $displayNameError");
                    }
                    // Continue anyway as Firestore update is more important
                  }
                }

                // Update Firestore with current Firebase Auth email
                final currentAuthEmail = user.email!; // Use actual Firebase Auth email
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                  'name': newName,
                  'email': currentAuthEmail, // Keep Firebase Auth email in sync
                  'phone': newPhone,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                // Reload user profile data
                await _loadUserProfile();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Refresh the profile data to update UI
                  await _refreshProfile();
                  // Notify parent widget of profile update
                  widget.onProfileUpdated?.call();
                }
              } catch (e) {
                // Check if it's the PigeonUserDetails error
                if (e.toString().contains('PigeonUserDetails') || 
                    e.toString().contains('PigeonUserInfo') ||
                    e.toString().contains('List<Object?>') ||
                    e.toString().contains('type cast')) {
                  print("PigeonUserDetails error occurred but profile update might have succeeded");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully! (Platform channel issue ignored)'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _refreshProfile,
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 24),
                _buildSectionTitle('Profile Information'),
                const SizedBox(height: 8),
                _buildSettingsSection([
                  _buildSettingsItem(
                    icon: Icons.person_outline_outlined,
                    iconBackgroundColor: Colors.blue[100],
                    iconColor: Colors.blue,
                    title: 'Name',
                    subtitle: _userProfile?['name'] ?? _currentUser?.displayName ?? 'No name',
                  ),
                  _buildSettingsItem(
                    icon: Icons.email_outlined,
                    iconBackgroundColor: Colors.red[100],
                    iconColor: Colors.red,
                    title: 'Email',
                    subtitle: _buildEmailSubtitle(),
                  ),
                  _buildSettingsItem(
                    icon: Icons.mobile_friendly_outlined,
                    iconBackgroundColor: Colors.orange[100],
                    iconColor: Colors.orange,
                    title: 'Mobile Number',
                    subtitle: _userProfile?['phone']?.isNotEmpty == true 
                        ? _userProfile!['phone'] 
                        : 'No phone number',
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle('About'),
                const SizedBox(height: 8),
                _buildSettingsSection([
                  _buildSettingsItem(
                    icon: Icons.info_outline,
                    iconBackgroundColor: Colors.purple[100],
                    iconColor: Colors.purple,
                    title: 'About',
                    subtitle: 'Learn more about CINELOOK',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsItem(
                    icon: Icons.feedback_outlined,
                    iconBackgroundColor: Colors.yellow[100],
                    iconColor: Colors.amber,
                    title: 'Send Feedback',
                    subtitle: 'Let us know how we can make CINELOOK better',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FeedbackFormScreen(),
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle('Account'),
                const SizedBox(height: 8),
                _buildSettingsSection([ 
                  _buildSettingsItem(
                    icon: Icons.person_outline,
                    iconBackgroundColor: Colors.grey[300],
                    iconColor: Colors.grey[800],
                    title: 'Update Profile',
                    onTap: _showUpdateProfileDialog,
                  ),
                  _buildSettingsItem(
                    icon: Icons.logout,
                    iconBackgroundColor: Colors.grey[300],
                    iconColor: Colors.grey[800],
                    title: 'Sign Out',
                    onTap: () => _showLogoutConfirmationDialog(),
                  ),
                  
                ]),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final user = _currentUser;
    final displayName = _userProfile?['name'] ?? user?.displayName ?? 'User Name';
    final photoURL = user?.photoURL; // Use if available, otherwise default

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorApp.primaryDarkColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
            child: photoURL == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: ColorApp.primaryDarkColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: 60, // Indent divider to align with text
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    Color? iconBackgroundColor,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBackgroundColor ?? Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.black, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: Colors.grey[600]))
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16) : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showLogoutConfirmationDialog() {
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
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
} 