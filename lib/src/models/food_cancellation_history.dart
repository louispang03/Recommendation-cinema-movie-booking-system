class FoodCancellationHistory {
  final String id;
  final String orderId;
  final String userId;
  final String userName;
  final String userEmail;
  final List<Map<String, dynamic>> foodItems;
  final double totalAmount;
  final DateTime orderTime;
  final DateTime pickupTime;
  final DateTime cancellationRequestTime;
  final DateTime processedTime;
  final String systemDecision; // 'auto_approved' or 'auto_rejected'
  final String reason; // e.g., 'before_30_minutes' or 'within_30_minutes'
  final bool refundProcessed;
  final double refundAmount;

  FoodCancellationHistory({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.foodItems,
    required this.totalAmount,
    required this.orderTime,
    required this.pickupTime,
    required this.cancellationRequestTime,
    required this.processedTime,
    required this.systemDecision,
    required this.reason,
    this.refundProcessed = false,
    this.refundAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'foodItems': foodItems,
      'totalAmount': totalAmount,
      'orderTime': orderTime.toIso8601String(),
      'pickupTime': pickupTime.toIso8601String(),
      'cancellationRequestTime': cancellationRequestTime.toIso8601String(),
      'processedTime': processedTime.toIso8601String(),
      'systemDecision': systemDecision,
      'reason': reason,
      'refundProcessed': refundProcessed,
      'refundAmount': refundAmount,
    };
  }

  factory FoodCancellationHistory.fromMap(Map<String, dynamic> map) {
    return FoodCancellationHistory(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      foodItems: List<Map<String, dynamic>>.from(map['foodItems'] ?? []),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      orderTime: DateTime.parse(map['orderTime']),
      pickupTime: DateTime.parse(map['pickupTime']),
      cancellationRequestTime: DateTime.parse(map['cancellationRequestTime']),
      processedTime: DateTime.parse(map['processedTime']),
      systemDecision: map['systemDecision'] ?? '',
      reason: map['reason'] ?? '',
      refundProcessed: map['refundProcessed'] ?? false,
      refundAmount: (map['refundAmount'] ?? 0).toDouble(),
    );
  }

  String get statusIcon {
    switch (systemDecision) {
      case 'auto_approved':
        return '✅';
      case 'auto_rejected':
        return '❌';
      default:
        return '❓';
    }
  }

  String get statusText {
    switch (systemDecision) {
      case 'auto_approved':
        return 'Auto-approved';
      case 'auto_rejected':
        return 'Auto-rejected';
      default:
        return 'Unknown';
    }
  }

  String get reasonText {
    switch (reason) {
      case 'before_30_minutes':
        return 'Requested before 30-minute deadline';
      case 'within_30_minutes':
        return 'Requested within 30 minutes of pickup time';
      default:
        return reason;
    }
  }

  String get refundStatusText {
    if (systemDecision == 'auto_rejected') return 'N/A - Not eligible';
    return refundProcessed ? 'Refunded: RM${refundAmount.toStringAsFixed(2)}' : 'Pending refund';
  }

  String get foodItemsDisplay {
    return foodItems.map((item) => '${item['quantity']}x ${item['title']}').join(', ');
  }
}
