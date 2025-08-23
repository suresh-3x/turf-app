class Review {
  final String id;
  final String serviceId;
  final String userId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.serviceId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
} 