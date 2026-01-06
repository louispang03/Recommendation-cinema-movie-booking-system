import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  bool _notificationsEnabled = true;
  List<int> _selectedReminderTimes = [30, 60]; // Default: 30 and 60 minutes
  bool _isLoading = true; 
  bool _isSaving = false;
  
  final List<int> _availableReminderTimes = [5, 10, 15, 30, 45, 60, 90, 120]; // in minutes

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final preferences = await _notificationService.getUserNotificationPreferences();
      setState(() {
        _notificationsEnabled = preferences['enabled'] ?? true;
        _selectedReminderTimes = List<int>.from(preferences['reminderTimes'] ?? [30, 60]);
      });
    } catch (e) {
      print('Error loading notification settings: $e');
      _showErrorSnackBar('Error loading settings');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _notificationService.updateNotificationPreferences(
        enabled: _notificationsEnabled,
        reminderTimes: _selectedReminderTimes,
      );
      
      _showSuccessSnackBar('Settings saved successfully!');
    } catch (e) {
      print('Error saving notification settings: $e');
      _showErrorSnackBar('Error saving settings');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatReminderTime(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '$hours ${hours == 1 ? 'hour' : 'hours'} $remainingMinutes minutes';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: ColorApp.primaryDarkColor,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: ColorApp.primaryDarkColor,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Movie Reminders',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ColorApp.primaryDarkColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get notified before your booked movies start',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enable/Disable Notifications
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _notificationsEnabled ? Icons.notifications : Icons.notifications_off,
                                color: _notificationsEnabled ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Enable Notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _notificationsEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _notificationsEnabled = value;
                                  });
                                },
                                activeColor: ColorApp.primaryDarkColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _notificationsEnabled
                                ? 'You will receive notifications before your movies start'
                                : 'Notifications are disabled',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reminder Times
                  if (_notificationsEnabled) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: ColorApp.primaryDarkColor,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Reminder Times',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose when you want to be reminded before your movie starts',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Reminder time chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableReminderTimes.map((minutes) {
                                final isSelected = _selectedReminderTimes.contains(minutes);
                                return FilterChip(
                                  label: Text(
                                    _formatReminderTime(minutes),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : ColorApp.primaryDarkColor,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        if (!_selectedReminderTimes.contains(minutes)) {
                                          _selectedReminderTimes.add(minutes);
                                          _selectedReminderTimes.sort();
                                        }
                                      } else {
                                        _selectedReminderTimes.remove(minutes);
                                      }
                                    });
                                  },
                                  selectedColor: ColorApp.primaryDarkColor,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: Colors.grey[100],
                                  side: BorderSide(
                                    color: isSelected ? ColorApp.primaryDarkColor : Colors.grey[300]!,
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            if (_selectedReminderTimes.isEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Please select at least one reminder time',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preview
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.preview,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Preview',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.movie,
                                        size: 20,
                                        color: ColorApp.primaryDarkColor,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '🎬 Movie Reminder',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Avengers: Endgame starts in 30 minutes!\n📅 Sat, 23 Dec at 7:00 PM\n🎭 Cinema: GSC\n🪑 Seats: A1, A2',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
} 