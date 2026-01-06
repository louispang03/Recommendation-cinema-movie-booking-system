class Booking {
  final String id;
  final String movieId;
  final String movieTitle;
  final String date;
  final String time;
  final List<String> seats;
  final double totalPrice;
  final DateTime bookingDate;
  final bool isPaid;
  final String cinema;
  final String status; // 'active', 'pending_cancellation', 'cancelled'
  final String? path; // document path for direct reference

  Booking({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.date,
    required this.time,
    required this.seats,
    required this.totalPrice,
    required this.bookingDate,
    required this.cinema,
    this.isPaid = false,
    this.status = 'active',
    this.path,
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'date': date,
      'time': time,
      'seats': seats,
      'totalPrice': totalPrice,
      'bookingDate': bookingDate.toIso8601String(),
      'isPaid': isPaid,
      'cinema': cinema,
      'status': status,
    };
    
    if (path != null) {
      map['path'] = path;
    }
    
    return map;
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] ?? '',
      movieId: map['movieId'],
      movieTitle: map['movieTitle'],
      date: map['date'],
      time: map['time'],
      seats: List<String>.from(map['seats']),
      totalPrice: map['totalPrice'],
      bookingDate: DateTime.parse(map['bookingDate']),
      isPaid: map['isPaid'] ?? false,
      cinema: map['cinema'] ?? 'GSC',
      status: map['status'] ?? 'active',
      path: map['path'],
    );
  }

  String getQRData() {
    return 'CINEMA-BOOKING\n'
        'ID: $id\n'
        'Cinema: $cinema\n'
        'Movie: $movieTitle\n'
        'Date: $date\n'
        'Time: $time\n'
        'Seats: ${seats.join(", ")}\n'
        'Total: RM${totalPrice.toStringAsFixed(2)}\n'
        'Status: ${status.toUpperCase()}';
  }
} 