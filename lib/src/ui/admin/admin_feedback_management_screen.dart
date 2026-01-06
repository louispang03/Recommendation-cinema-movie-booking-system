import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/services/notification_service.dart';

class AdminFeedbackManagementScreen extends StatefulWidget {
  const AdminFeedbackManagementScreen({super.key});

  @override
  State<AdminFeedbackManagementScreen> createState() => _AdminFeedbackManagementScreenState();
}

class _AdminFeedbackManagementScreenState extends State<AdminFeedbackManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;
  String _selectedStatus = 'All';
  final List<String> _statusOptions = ['All', 'pending', 'responded', 'resolved'];

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _firestore.collection('feedback')
          .orderBy('timestamp', descending: true);

      if (_selectedStatus != 'All') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }

      final snapshot = await query.get();
      
      _feedbacks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

    } catch (e) {
      print('Error loading feedbacks: $e');
      _showErrorSnackBar('Error loading feedbacks');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFeedbackStatus(String feedbackId, String newStatus) async {
    try {
      await _firestore
          .collection('feedback')
          .doc(feedbackId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _loadFeedbacks(); // Refresh the list
      _showSuccessSnackBar('Status updated successfully');
    } catch (e) {
      print('Error updating feedback status: $e');
      _showErrorSnackBar('Error updating status');
    }
  }

  Future<void> _respondToFeedback(Map<String, dynamic> feedback) async {
    final responseController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to Feedback'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Original Feedback:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(feedback['feedback'] ?? ''),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Response:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: responseController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Type your response here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (responseController.text.trim().isNotEmpty) {
                await _sendResponse(feedback, responseController.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorApp.primaryDarkColor,
            ),
            child: const Text('Send Response', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendResponse(Map<String, dynamic> feedback, String response) async {
    try {
      final feedbackId = feedback['id'];
      final userId = feedback['userId'];

      // Update feedback with response
      await _firestore
          .collection('feedback')
          .doc(feedbackId)
          .update({
        'response': response,
        'responseDate': FieldValue.serverTimestamp(),
        'status': 'responded',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for the user
      await _notificationService.createFeedbackResponseNotification(
        userId: userId,
        feedbackId: feedbackId,
        message: 'Thank you for your feedback! We have responded to your inquiry. Response: $response',
        title: '📝 Feedback Response from Admin',
        additionalData: {
          'feedbackId': feedbackId,
          'originalFeedback': feedback['feedback'],
          'response': response,
          'details': 'The admin team has reviewed your feedback and provided a response.',
        },
      );

      _loadFeedbacks(); // Refresh the list
      _showSuccessSnackBar('Response sent successfully!');
    } catch (e) {
      print('Error sending response: $e');
      _showErrorSnackBar('Error sending response');
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

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.grey[400], size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'responded':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'responded':
        return Icons.reply;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Feedback Management',
          style: TextStyle(
            color: Color(0xFF047857),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF9FAFB),
        iconTheme: const IconThemeData(color: Color(0xFF047857)),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status filter
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusOptions.map((status) {
                        final isSelected = _selectedStatus == status;
                        final count = status == 'All' 
                            ? _feedbacks.length
                            : _feedbacks.where((f) => f['status'] == status).length;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              '${status.toUpperCase()} ($count)',
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF047857),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatus = status;
                              });
                              _loadFeedbacks();
                            },
                            selectedColor: const Color(0xFF047857),
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.grey[100],
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF047857) : Colors.grey[300]!,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                // Feedback list
                Expanded(
                  child: _feedbacks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.feedback_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedStatus == 'All' 
                                    ? 'No feedback received yet'
                                    : 'No ${_selectedStatus.toLowerCase()} feedback',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadFeedbacks,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _feedbacks.length,
                            itemBuilder: (context, index) {
                              final feedback = _feedbacks[index];
                              return _buildFeedbackCard(feedback);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final status = feedback['status'] ?? 'pending';
    final timestamp = feedback['timestamp'] as Timestamp?;
    final hasResponse = feedback['response'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 16,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // User info
            Row(
              children: [
                Icon(Icons.person, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Text(
                  feedback['userEmail'] ?? 'Unknown user',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Feedback content
            Text(
              'Feedback:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feedback['feedback'] ?? '',
              style: TextStyle(color: Colors.grey[700]),
            ),
            
            // Image if exists
            if (feedback['imageUrl'] != null && feedback['imageUrl'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Attached Image:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showImageDialog(feedback['imageUrl']),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      feedback['imageUrl'],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            
            // Response if exists
            if (hasResponse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Admin Response:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback['response'] ?? '',
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action buttons
            const SizedBox(height: 12),
            Row(
              children: [
                if (!hasResponse)
                  ElevatedButton.icon(
                    onPressed: () => _respondToFeedback(feedback),
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Respond'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorApp.primaryDarkColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    _updateFeedbackStatus(feedback['id'], value);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'pending',
                      child: Row(
                        children: [
                          Icon(Icons.pending, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Mark as Pending'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'responded',
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Mark as Responded'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'resolved',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Mark as Resolved'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Change Status'),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 