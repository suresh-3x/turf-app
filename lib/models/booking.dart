import 'app_user.dart';
import 'service.dart';
import 'slot.dart';

enum BookingStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  completed;

  static BookingStatus fromString(String? value) =>
      BookingStatus.values.firstWhere((s) => s.name == value, orElse: () => BookingStatus.pending);

  String get label => switch (this) {
    BookingStatus.pending => 'Awaiting confirmation',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.rejected => 'Declined',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.completed => 'Completed',
  };

  /// The booking still holds the slot.
  bool get isActive => this == BookingStatus.pending || this == BookingStatus.confirmed;
}

class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.serviceId,
    required this.slotId,
    required this.status,
    required this.createdAt,
    this.notes,
    this.service,
    this.slot,
    this.customer,
    this.hasReview = false,
  });

  final String id;
  final String customerId;
  final String serviceId;
  final String slotId;
  final BookingStatus status;
  final DateTime createdAt;
  final String? notes;
  final Service? service;
  final Slot? slot;
  final AppUser? customer;
  final bool hasReview;

  DateTime? get startTime => slot?.startTime;
  bool get hasStarted => slot?.hasStarted ?? false;

  /// Upcoming bookings are active and in the future.
  bool get isUpcoming => status.isActive && !hasStarted;

  bool get canCustomerCancel => status.isActive && !hasStarted;
  bool get canReview => status == BookingStatus.completed && !hasReview;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final service = json['service'];
    final slot = json['slot'];
    final customer = json['customer'];
    final reviews = json['reviews'];
    return Booking(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      serviceId: json['service_id'] as String,
      slotId: json['slot_id'] as String,
      status: BookingStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(
        (json['booking_time'] ?? json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ).toLocal(),
      notes: json['notes'] as String?,
      service: service is Map<String, dynamic> ? Service.fromJson(service) : null,
      slot: slot is Map<String, dynamic> ? Slot.fromJson(slot) : null,
      customer: customer is Map<String, dynamic> && customer['id'] != null
          ? AppUser.fromJson(customer)
          : null,
      hasReview: reviews is List && reviews.isNotEmpty,
    );
  }
}
