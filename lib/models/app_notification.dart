class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.bookingId,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? bookingId;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? '',
    body: (json['body'] as String?) ?? '',
    isRead: (json['is_read'] as bool?) ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    bookingId: json['booking_id'] as String?,
  );
}
