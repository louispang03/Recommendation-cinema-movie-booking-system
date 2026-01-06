import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/model/admin/admin.dart';
//import 'package:fyp_cinema_app/src/ui/home/home_page.dart';
import 'package:fyp_cinema_app/src/ui/screen/login_page.dart';
import 'package:fyp_cinema_app/src/ui/screen/home_page.dart';
import 'package:fyp_cinema_app/src/services/auth_service.dart';
import 'package:fyp_cinema_app/src/ui/admin/admin_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: ColorApp.primaryColor,
        hintColor: ColorApp.accentColor,
      ),
      home: const AuthGate(),
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }

}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _previousUser;
  bool _isTransitioning = false;
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirebaseAuth auth = FirebaseAuth.instance;
    
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        print("🔐 Auth state changed: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, user: ${snapshot.data?.email}");
        
        // Handle user switching - detect when user changes
        if (snapshot.hasData && _previousUser != null && _previousUser!.uid != snapshot.data!.uid && !_hasNavigated) {
          print("🔄 User switched from ${_previousUser!.email} to ${snapshot.data!.email}");
          _isTransitioning = true;
          _hasNavigated = true;
          
          // Clear navigation stack when switching users
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthGate()),
                (Route<dynamic> route) => false,
              );
            } catch (e) {
              print("❌ Navigation error during user switch: $e");
              // Reset flags if navigation fails
              _hasNavigated = false;
              _isTransitioning = false;
            }
          });
        }
        
        // Update previous user reference
        _previousUser = snapshot.data;
        
        // Show loading indicator while waiting for auth state or during transitions
        if (snapshot.connectionState == ConnectionState.waiting || _isTransitioning) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        }
        
        // Reset transition flags when not transitioning
        if (!_isTransitioning) {
          _hasNavigated = false;
        }
        _isTransitioning = false;
        
        // If not logged in, show login page
        if (!snapshot.hasData || snapshot.data == null) {
          print("👤 No user logged in, showing login page");
          return LoginPage();
        }
        
        // User is logged in
        User? currentUser = snapshot.data;
        print("✅ User authenticated: ${currentUser?.uid}, ${currentUser?.email}");
        
        // Safety check - this should never happen due to the check above, but just in case
        if (currentUser == null) {
          print("❌ Unexpected: currentUser is null despite authentication");
          return LoginPage();
        }
        
        // Optimized admin check - avoid Firestore calls during auth flow
        final isAdminEmail = currentUser.email == 'admin@cinema.com';
        print("🔍 Quick admin check: ${currentUser.email} -> isAdmin: $isAdminEmail");
        
        if (isAdminEmail) {
          print("🔧 Loading admin dashboard for ${currentUser.email}");
          // Create admin object immediately to avoid loading screen and Firestore calls
          try {
            final admin = Admin(
              id: currentUser.uid,
              email: currentUser.email ?? 'admin@cinema.com',
              username: 'Admin User',
              role: 'admin',
              createdAt: DateTime.now(),
            );
            print("✅ Admin dashboard loaded immediately for ${currentUser.email}");
            return AdminDashboardScreen(admin: admin);
          } catch (e) {
            print("❌ Failed to create admin object: $e");
            print("🏠 Fallback to home page");
            return const HomePage();
          }
        }
        
        // For all other users, go directly to home page
        print("🏠 Loading user home page for ${currentUser.email}");
        return const HomePage();
      },
    );
  }
}
