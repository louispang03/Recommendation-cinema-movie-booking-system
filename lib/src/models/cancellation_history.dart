class CancellationHistory {
  final String id;
  final String bookingId;
  final String movieTitle;
  final String movieId;
  final String showDate;
  final String showTime;
  final String cinema;
  final List<String> seats;
  final double totalPrice;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime cancellationRequestTime;
  final DateTime processedTime;
  final String systemDecision; // 'auto_approved' or 'auto_rejected'
  final String reason; // e.g., 'before_30_minutes' or 'within_30_minutes'
  final bool refundProcessed;
  final double refundAmount;

  CancellationHistory({
    required this.id,
    required this.bookingId,
    required this.movieTitle,
    required this.movieId,
    required this.showDate,
    required this.showTime,
    required this.cinema,
    required this.seats,
    required this.totalPrice,
    required this.userId,
    required this.userName,
    required this.userEmail,
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
      'bookingId': bookingId,
      'movieTitle': movieTitle,
      'movieId': movieId,
      'showDate': showDate,
      'showTime': showTime,
      'cinema': cinema,
      'seats': seats,
      'totalPrice': totalPrice,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'cancellationRequestTime': cancellationRequestTime.toIso8601String(),
      'processedTime': processedTime.toIso8601String(),
      'systemDecision': systemDecision,
      'reason': reason,
      'refundProcessed': refundProcessed,
      'refundAmount': refundAmount,
    };
  }

  factory CancellationHistory.fromMap(Map<String, dynamic> map) {
    return CancellationHistory(
      id: map['id'] ?? '',
      bookingId: map['bookingId'] ?? '',
      movieTitle: map['movieTitle'] ?? '',
      movieId: map['movieId'] ?? '',
      showDate: map['showDate'] ?? '',
      showTime: map['showTime'] ?? '',
      cinema: map['cinema'] ?? '',
      seats: List<String>.from(map['seats'] ?? []),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      cancellationRequestTime: DateTime.parse(map['cancellationRequestTime']),
      processedTime: DateTime.parse(map['processedTime']),
      systemDecision: map['systemDecision'] ?? '',
      reason: map['reason'] ?? '',
      refundProcessed: map['refundProcessed'] ?? false,
      refundAmount: (map['refundAmount'] ?? 0).toDouble(),
    );
  }

  String get formattedShowDateTime => '$showDate at $showTime';
  
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
        return 'Requested within 30 minutes of showtime';
      default:
        return reason;
    }
  }

  String get refundStatusText {
    if (systemDecision == 'auto_rejected') return 'N/A - Not eligible';
    return refundProcessed ? 'Refunded: RM${refundAmount.toStringAsFixed(2)}' : 'Pending refund';
  }
}
