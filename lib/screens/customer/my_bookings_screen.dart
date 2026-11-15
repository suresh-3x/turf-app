import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/booking.dart';
import '../../services/booking_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/notification_bell.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking booking) async {
    final ok = await confirmAction(
      context,
      title: 'Cancel booking?',
      message: 'The slot will be released for others to book.',
      confirmLabel: 'Cancel booking',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(bookingServiceProvider).cancel(booking.id);
      ref.invalidate(myBookingsProvider);
      if (context.mounted) showSnackBar(context, 'Booking cancelled.');
    } catch (e) {
      if (context.mounted) showSnackBar(context, friendlyError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My bookings'),
          actions: const [NotificationBell()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: AsyncValueView(
          value: bookings,
          onRetry: () => ref.invalidate(myBookingsProvider),
          data: (all) {
            final upcoming = all.where((b) => b.isUpcoming).toList();
            final past = all.where((b) => !b.isUpcoming).toList().reversed.toList();
            return TabBarView(
              children: [
                _list(
                  context,
                  ref,
                  upcoming,
                  empty: EmptyState(
                    icon: Icons.event_available,
                    title: 'No upcoming bookings',
                    message: 'Find a venue and book your next game.',
                    action: FilledButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Explore venues'),
                    ),
                  ),
                ),
                _list(
                  context,
                  ref,
                  past,
                  empty: const EmptyState(icon: Icons.history, title: 'No past bookings yet'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<Booking> list, {required Widget empty}) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myBookingsProvider.future),
      child: list.isEmpty
          ? ListView(children: [const SizedBox(height: 48), empty])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final b = list[i];
                return BookingCard(
                  booking: b,
                  onTap: () => context.push('/home/service/${b.serviceId}'),
                  actions: [
                    if (b.canCustomerCancel)
                      TextButton(
                        onPressed: () => _cancel(context, ref, b),
                        child: const Text('Cancel'),
                      ),
                    if (b.canReview)
                      FilledButton.tonal(
                        onPressed: () => context.push('/review/${b.id}'),
                        child: const Text('Leave a review'),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
