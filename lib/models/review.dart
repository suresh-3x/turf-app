class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.serviceId,
    this.customerName,
  });

  final String id;
  final String bookingId;
  final String? serviceId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String? customerName;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    bookingId: json['booking_id'] as String,
    serviceId: json['service_id'] as String?,
    rating: (json['rating'] as num).toInt(),
    comment: (json['comment'] as String?) ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    customerName: json['customer_name'] as String?,
  );
}
