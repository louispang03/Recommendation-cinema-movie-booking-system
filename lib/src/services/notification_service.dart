import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/src/models/booking.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Notification settings
  static const String _movieReminderChannelId = 'movie_reminders';
  static const String _movieReminderChannelName = 'Movie Reminders';
  static const String _movieReminderChannelDescription = 'Notifications for upcoming movie showings';
  
  // Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Initialize OneSignal
    await _initializeOneSignal();
    
    // Request permissions
    await _requestPermissions();
    
    print('✅ Notification service initialized');
  }

  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _movieReminderChannelId,
      _movieReminderChannelName,
      description: _movieReminderChannelDescription,
      importance: Importance.high,
      playSound: true,
    );
    
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initializeOneSignal() async {
    // Initialize OneSignal with your app ID
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("YOUR_ONESIGNAL_APP_ID"); // Replace with your OneSignal App ID
    
    // Request permission for push notifications
    await OneSignal.Notifications.requestPermission(true);
    
    // Set up notification handlers
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('OneSignal: Notification received in foreground');
    });
    
    OneSignal.Notifications.addClickListener((event) {
      print('OneSignal: Notification clicked');
      // Handle push notification click
    });
  }

  Future<void> _requestPermissions() async {
    // Request notification permission
    await Permission.notification.request();
    
    // Request alarm permission for Android 13+
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.id}');
    // Handle notification tap - navigate to booking details or home screen
  }

  // Schedule a notification for a movie booking
  Future<void> scheduleMovieReminder(Booking booking, {int minutesBefore = 30}) async {
    try {
      // Parse the booking date and time
      final DateTime movieDateTime = _parseMovieDateTime(booking.date, booking.time);
      
      // Calculate notification time (default: 30 minutes before)
      final DateTime notificationTime = movieDateTime.subtract(Duration(minutes: minutesBefore));
      
      // Don't schedule if the notification time is in the past
      if (notificationTime.isBefore(DateTime.now())) {
        print('⚠️ Notification time is in the past, skipping');
        return;
      }
      
      // Create notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _movieReminderChannelId,
        _movieReminderChannelName,
        channelDescription: _movieReminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
        playSound: true,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Create notification content
      final String title = '🎬 Movie Reminder';
      final String body = '${booking.movieTitle} starts in $minutesBefore minutes!\n'
          '📅 ${booking.date} at ${booking.time}\n'
          '🎭 Cinema: ${booking.cinema}\n'
          '🪑 Seats: ${booking.seats.join(", ")}';
      
      // Schedule the notification
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        booking.id.hashCode, // Use booking ID hash as notification ID
        title,
        body,
        tz.TZDateTime.from(notificationTime, tz.local),
        notificationDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      // Save notification to Firestore for management
      await _saveNotificationRecord(booking, notificationTime, minutesBefore);
      
      print('✅ Movie reminder scheduled for ${booking.movieTitle} at $notificationTime');
      
    } catch (e) {
      print('❌ Error scheduling movie reminder: $e');
      rethrow;
    }
  }

  // Schedule multiple reminders for a booking
  Future<void> scheduleMultipleReminders(Booking booking) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Always schedule a 30-minute reminder (no user preferences needed)
      await scheduleMovieReminder(booking, minutesBefore: 30);
      
      print('✅ 30-minute reminder scheduled for ${booking.movieTitle}');
    } catch (e) {
      print('❌ Error scheduling reminder: $e');
    }
  }

  // Cancel a scheduled notification
  Future<void> cancelMovieReminder(String bookingId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(bookingId.hashCode);
      
      // Remove from Firestore
      await _removeNotificationRecord(bookingId);
      
      print('✅ Movie reminder cancelled for booking: $bookingId');
    } catch (e) {
      print('❌ Error cancelling movie reminder: $e');
    }
  }

  // Simplified - no longer needed but keeping for compatibility
  Future<Map<String, dynamic>> getUserNotificationPreferences() async {
    return {
      'enabled': true,
      'reminderTimes': [30], // Fixed to 30 minutes only
    };
  }

  // Simplified - no longer needed but keeping for compatibility
  Future<Map<String, dynamic>> _getUserNotificationPreferences() async {
    return await getUserNotificationPreferences();
  }

  // Simplified - no longer needed but keeping for compatibility
  Future<void> updateNotificationPreferences({
    required bool enabled,
    required List<int> reminderTimes,
  }) async {
    // No longer storing preferences since we always use 30 minutes
    print('✅ Notification preferences (fixed to 30 minutes)');
  }

  // Save notification record to Firestore
  Future<void> _saveNotificationRecord(Booking booking, DateTime notificationTime, int minutesBefore) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'type': 'movie_reminder',
        'bookingId': booking.id,
        'movieTitle': booking.movieTitle,
        'movieDate': booking.date,
        'movieTime': booking.time,
        'notificationTime': Timestamp.fromDate(notificationTime),
        'minutesBefore': minutesBefore,
        'status': 'scheduled',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving notification record: $e');
    }
  }

  // Remove notification record from Firestore
  Future<void> _removeNotificationRecord(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(bookingId)
          .delete();
    } catch (e) {
      print('Error removing notification record: $e');
    }
  }

  // Parse movie date and time string to DateTime
  DateTime _parseMovieDateTime(String date, String time) {
    try {
      // Parse date like "Mon, 23 Dec"
      final dateParts = date.split(', ');
      final dayMonth = dateParts[1].split(' ');
      final day = int.parse(dayMonth[0]);
      final month = _getMonthNumber(dayMonth[1]);
      final year = DateTime.now().year;
      
      // Parse time like "7:00 PM"
      final timeParts = time.split(' ');
      final hourMinute = timeParts[0].split(':');
      int hour = int.parse(hourMinute[0]);
      final minute = int.parse(hourMinute[1]);
      
      // Convert to 24-hour format
      if (timeParts[1].toLowerCase() == 'pm' && hour != 12) {
        hour += 12;
      } else if (timeParts[1].toLowerCase() == 'am' && hour == 12) {
        hour = 0;
      }
      
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      print('Error parsing movie date/time: $e');
      rethrow;
    }
  }

  int _getMonthNumber(String month) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };
    return months[month] ?? 1;
  }

  // Send immediate notification (for testing or urgent updates)
  Future<void> sendImmediateNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _movieReminderChannelId,
      _movieReminderChannelName,
      channelDescription: _movieReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  // Get all scheduled notifications for the user
  Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('status', isEqualTo: 'scheduled')
          .orderBy('notificationTime')
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting scheduled notifications: $e');
      return [];
    }
  }

  // Cancel all notifications for a user
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final batch = _firestore.batch();
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .get();
        
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        print('✅ All notifications cancelled');
      } catch (e) {
        print('❌ Error cancelling all notifications: $e');
      }
    }
  }

  // Create a feedback response notification
  Future<void> createFeedbackResponseNotification({
    required String userId,
    required String feedbackId,
    required String message,
    String? title,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'feedback_response',
        'title': title ?? '📝 Feedback Response',
        'message': message,
        'feedbackId': feedbackId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'data': additionalData ?? {},
      });

      // Send immediate push notification
      await sendImmediateNotification(
        title: title ?? '📝 Feedback Response',
        body: message,
      );

      print('✅ Feedback response notification created for user: $userId');
    } catch (e) {
      print('❌ Error creating feedback response notification: $e');
      rethrow;
    }
  }

  // Create a system notification
  Future<void> createSystemNotification({
    required String userId,
    required String title,
    required String message,
    String? details,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'system',
        'title': title,
        'message': message,
        'details': details,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'data': additionalData ?? {},
      });

      // Send immediate push notification
      await sendImmediateNotification(
        title: title,
        body: message,
      );

      print('✅ System notification created for user: $userId');
    } catch (e) {
      print('❌ Error creating system notification: $e');
      rethrow;
    }
  }

  // Create a general notification
  Future<void> createGeneralNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
    bool sendPush = true,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'message': message,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'data': additionalData ?? {},
      });

      // Send immediate push notification if requested
      if (sendPush) {
        await sendImmediateNotification(
          title: title,
          body: message,
        );
      }

      print('✅ General notification created for user: $userId');
    } catch (e) {
      print('❌ Error creating general notification: $e');
      rethrow;
    }
  }

  // Broadcast system notification to all users
  Future<void> broadcastSystemNotification({
    required String title,
    required String message,
    String? details,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      
      final batch = _firestore.batch();
      
      for (final userDoc in usersSnapshot.docs) {
        final notificationRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .doc();
        
        batch.set(notificationRef, {
          'type': 'system',
          'title': title,
          'message': message,
          'details': details,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'data': additionalData ?? {},
        });
      }
      
      await batch.commit();
      
      // Send push notification to all users via OneSignal
      // This would require OneSignal setup for broadcast
      
      print('✅ System notification broadcasted to all users');
    } catch (e) {
      print('❌ Error broadcasting system notification: $e');
      rethrow;
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      
      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      print('✅ Notification deleted: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      rethrow;
    }
  }

  // Get notifications by type
  Future<List<Map<String, dynamic>>> getNotificationsByType(String type) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting notifications by type: $e');
      return [];
    }
  }

  // Get unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return 0;
    }
  }
} 