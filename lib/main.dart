import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/src/app.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fyp_cinema_app/src/services/notification_service.dart';
import 'package:fyp_cinema_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with proper configuration
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully with proper configuration");
  } catch (e) {
    print("❌ Error initializing Firebase: $e");
    // Try fallback initialization
    try {
      await Firebase.initializeApp();
      print("✅ Firebase initialized with fallback method");
    } catch (fallbackError) {
      print("❌ Firebase fallback initialization failed: $fallbackError");
    }
  }
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("e03b3464-7270-45f1-9645-49d4cca80337");
  OneSignal.Notifications.requestPermission(true);
  
  // Initialize notification service
  try {
    await NotificationService().initialize();
    print("Notification service initialized successfully");
  } catch (e) {
    print("Error initializing notification service: $e");
  }
  
  runApp(const App());
}