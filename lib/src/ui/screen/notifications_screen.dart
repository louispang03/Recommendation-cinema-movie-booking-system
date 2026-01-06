import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/src/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Movie Reminders', 'Feedback Responses', 'New Movie', 'Unread'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _notifications.clear(); // Clear existing notifications to prevent duplicates
    });

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Load all notification types
      await Future.wait([
        _loadMovieReminders(user.uid),
        _loadFeedbackResponses(user.uid),
        _loadSystemNotifications(user.uid),
      ]);

      // Sort notifications by timestamp (newest first)
      _notifications.sort((a, b) {
        final timestampA = a['timestamp'] as Timestamp?;
        final timestampB = b['timestamp'] as Timestamp?;
        
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        
        return timestampB.compareTo(timestampA);
      });

    } catch (e) {
      print('Error loading notifications: $e');
      _showErrorSnackBar('Error loading notifications');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMovieReminders(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'movie_reminder')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        _notifications.add({
          'id': doc.id,
          'type': 'movie_reminder',
          'title': '🎬 Movie Reminder',
          'message': 'Your movie "${data['movieTitle']}" starts at ${data['movieTime']} on ${data['movieDate']}',
          'timestamp': data['notificationTime'] ?? data['createdAt'],
          'isRead': data['isRead'] ?? false,
          'data': data,
        });
      }
    } catch (e) {
      print('Error loading movie reminders: $e');
    }
  }

  Future<void> _loadFeedbackResponses(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'feedback_response')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        _notifications.add({
          'id': doc.id,
          'type': 'feedback_response',
          'title': '📝 Feedback Response',
          'message': data['message'] ?? 'You have received a response to your feedback.',
          'timestamp': data['timestamp'] ?? data['createdAt'],
          'isRead': data['isRead'] ?? false,
          'data': data,
        });
      }
    } catch (e) {
      print('Error loading feedback responses: $e');
    }
  }

  Future<void> _loadSystemNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'system')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        _notifications.add({
          'id': doc.id,
          'type': 'system',
          'title': data['title'] ?? '📢 System Notification',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'] ?? data['createdAt'],
          'isRead': data['isRead'] ?? false,
          'data': data,
        });
      }
    } catch (e) {
      print('Error loading system notifications: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    switch (_selectedFilter) {
      case 'Movie Reminders':
        return _notifications.where((n) => n['type'] == 'movie_reminder').toList();
      case 'Feedback Responses':
        return _notifications.where((n) => n['type'] == 'feedback_response').toList();
      case 'New Movie':
        return _notifications.where((n) => n['type'] == 'system').toList();
      case 'Unread':
        return _notifications.where((n) => !n['isRead']).toList();
      default:
        return _notifications;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      
      for (var notification in _notifications.where((n) => !n['isRead'])) {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(notification['id']);
        batch.update(docRef, {'isRead': true});
      }
      
      await batch.commit();
      
      setState(() {
        for (var notification in _notifications) {
          notification['isRead'] = true;
        }
      });
      
      _showSuccessSnackBar('All notifications marked as read');
    } catch (e) {
      print('Error marking all as read: $e');
      _showErrorSnackBar('Error updating notifications');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });
      
      _showSuccessSnackBar('Notification deleted');
    } catch (e) {
      print('Error deleting notification: $e');
      _showErrorSnackBar('Error deleting notification');
    }
  }

  Future<void> _clearAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = _firestore.batch();
      
      for (var notification in _notifications) {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(notification['id']);
        batch.delete(docRef);
      }
      
      await batch.commit();
      
      setState(() {
        _notifications.clear();
      });
      
      _showSuccessSnackBar('All notifications cleared');
    } catch (e) {
      print('Error clearing all notifications: $e');
      _showErrorSnackBar('Error clearing notifications');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'movie_reminder':
        return Colors.blue;
      case 'feedback_response':
        return Colors.green;
      case 'system':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'movie_reminder':
        return Icons.movie;
      case 'feedback_response':
        return Icons.feedback;
      case 'system':
        return Icons.notifications;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();
    final unreadCount = _notifications.where((n) => !n['isRead']).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
        style: TextStyle(
            fontSize: 20,
          ),
        ),
        backgroundColor: ColorApp.primaryDarkColor,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAllNotifications,
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter chips
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        final count = filter == 'All' 
                            ? _notifications.length
                            : filter == 'Unread'
                                ? unreadCount
                                : _notifications.where((n) => 
                                    filter == 'Movie Reminders' ? n['type'] == 'movie_reminder' :
                                    filter == 'Feedback Responses' ? n['type'] == 'feedback_response' :
                                    filter == 'New Movie' ? n['type'] == 'system' : false
                                  ).length;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              '$filter ($count)',
                              style: TextStyle(
                                color: isSelected ? Colors.white : ColorApp.primaryDarkColor,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            selectedColor: ColorApp.primaryDarkColor,
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.grey[100],
                            side: BorderSide(
                              color: isSelected ? ColorApp.primaryDarkColor : Colors.grey[300]!,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                // Notifications list
                Expanded(
                  child: filteredNotifications.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = filteredNotifications[index];
                              return _buildNotificationCard(notification);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All' 
                ? 'No notifications yet'
                : _selectedFilter == 'New Movie'
                    ? 'No new movie notifications'
                    : 'No ${_selectedFilter.toLowerCase()} notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your notifications will appear here'
                : 'Try selecting a different filter',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] as bool;
    final type = notification['type'] as String;
    final timestamp = notification['timestamp'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getNotificationColor(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getNotificationIcon(type),
            color: _getNotificationColor(type),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification['title'],
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'],
              style: TextStyle(
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'mark_read':
                if (!isRead) _markAsRead(notification['id']);
                break;
              case 'delete':
                _deleteNotification(notification['id']);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, size: 20),
                    SizedBox(width: 8),
                    Text('Mark as read'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          if (!isRead) {
            _markAsRead(notification['id']);
          }
          _showNotificationDetails(notification);
        },
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification['message']),
              const SizedBox(height: 16),
              Text(
                'Time: ${_formatTimestamp(notification['timestamp'])}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (notification['data'] != null && notification['data']['details'] != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(notification['data']['details']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
