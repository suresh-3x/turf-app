import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'auth_service.dart';
import 'supabase_providers.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(supabaseClientProvider)),
);

/// Live list of the signed-in user's notifications, newest first.
/// Rows are written by database triggers when bookings change.
final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(notificationServiceProvider).watch(userId);
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});

class NotificationService {
  NotificationService(this._client);
  final SupabaseClient _client;

  Stream<List<AppNotification>> watch(String userId) => _client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at')
      .limit(50)
      .map((rows) => rows.map(AppNotification.fromJson).toList());

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
