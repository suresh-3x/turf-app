class Slot {
  final String id;
  final String serviceId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;

  Slot({
    required this.id,
    required this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.isBooked,
  });
} 