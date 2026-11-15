import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/async_value_view.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () {
                final uid = ref.read(currentUserIdProvider);
                if (uid != null) ref.read(notificationServiceProvider).markAllRead(uid);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: AsyncValueView(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none,
                title: "You're all caught up",
                message: 'Booking updates will show up here.',
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = list[i];
                  return ListTile(
                    leading: Icon(
                      n.isRead ? Icons.notifications_none : Icons.notifications_active,
                      color: n.isRead ? theme.colorScheme.outline : theme.colorScheme.primary,
                    ),
                    title: Text(
                      n.title,
                      style: n.isRead ? null : const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(n.body),
                    trailing: Text(formatRelative(n.createdAt), style: theme.textTheme.bodySmall),
                    onTap: n.isRead
                        ? null
                        : () => ref.read(notificationServiceProvider).markRead(n.id),
                  );
                },
              ),
      ),
    );
  }
}
