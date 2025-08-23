class Booking {
  final String id;
  final String serviceId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // pending, confirmed, rejected

  Booking({
    required this.id,
    required this.serviceId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.status,
  });
} 