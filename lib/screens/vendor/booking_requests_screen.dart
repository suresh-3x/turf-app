import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/booking.dart';
import '../../services/booking_service.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/notification_bell.dart';
import 'booking_actions.dart';

/// New requests to accept or decline, and confirmed bookings coming up.
class BookingRequestsScreen extends ConsumerWidget {
  const BookingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(vendorBookingsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bookings'),
          actions: const [NotificationBell()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Confirmed'),
            ],
          ),
        ),
        body: AsyncValueView(
          value: bookings,
          onRetry: () => ref.invalidate(vendorBookingsProvider),
          data: (all) {
            final requests = all
                .where((b) => b.status == BookingStatus.pending && !b.hasStarted)
                .toList();
            // Confirmed ones, including those that started and still need
            // marking as completed.
            final confirmed = all.where((b) => b.status == BookingStatus.confirmed).toList();
            return TabBarView(
              children: [
                _list(
                  context,
                  ref,
                  requests,
                  empty: const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No new requests',
                    message: 'New booking requests will appear here.',
                  ),
                ),
                _list(
                  context,
                  ref,
                  confirmed,
                  empty: const EmptyState(
                    icon: Icons.event_available,
                    title: 'No confirmed bookings',
                  ),
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
      onRefresh: () => ref.refresh(vendorBookingsProvider.future),
      child: list.isEmpty
          ? ListView(children: [const SizedBox(height: 48), empty])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, i) => BookingCard(
                booking: list[i],
                showCustomer: true,
                actions: vendorBookingActions(context, ref, list[i]),
              ),
            ),
    );
  }
}
