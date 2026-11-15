class Slot {
  const Slot({
    required this.id,
    required this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.isBooked,
  });

  final String id;
  final String serviceId;

  /// Local time.
  final DateTime startTime;

  /// Local time.
  final DateTime endTime;
  final bool isBooked;

  bool get hasStarted => !startTime.isAfter(DateTime.now());
  bool get isAvailable => !isBooked && !hasStarted;
  Duration get duration => endTime.difference(startTime);

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
    id: json['id'] as String,
    serviceId: json['service_id'] as String,
    startTime: DateTime.parse(json['start_time'] as String).toLocal(),
    endTime: DateTime.parse(json['end_time'] as String).toLocal(),
    isBooked: (json['is_booked'] as bool?) ?? false,
  );
}

/// A start/end pair used when creating slots.
class SlotRange {
  const SlotRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  Map<String, dynamic> toInsertJson(String serviceId) => {
    'service_id': serviceId,
    'start_time': start.toUtc().toIso8601String(),
    'end_time': end.toUtc().toIso8601String(),
  };
}
