import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/booking.dart';
import '../../services/booking_service.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/booking_card.dart';
import 'booking_actions.dart';

/// Every booking that is finished: completed, cancelled, declined, or past.
class BookingHistoryScreen extends ConsumerStatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  ConsumerState<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen> {
  BookingStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(vendorBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking history')),
      body: AsyncValueView(
        value: bookings,
        onRetry: () => ref.invalidate(vendorBookingsProvider),
        data: (all) {
          final past = all
              .where((b) => !b.status.isActive || b.hasStarted)
              .where((b) => _filter == null || b.status == _filter)
              .toList()
              .reversed
              .toList();
          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _chip('All', null),
                    _chip('Completed', BookingStatus.completed),
                    _chip('Cancelled', BookingStatus.cancelled),
                    _chip('Declined', BookingStatus.rejected),
                    _chip('Not completed', BookingStatus.confirmed),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(vendorBookingsProvider.future),
                  child: past.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 48),
                            EmptyState(icon: Icons.history, title: 'Nothing here yet'),
                          ],
                        )
                      : ListView.builder(
                          itemCount: past.length,
                          itemBuilder: (context, i) => BookingCard(
                            booking: past[i],
                            showCustomer: true,
                            actions: vendorBookingActions(context, ref, past[i]),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, BookingStatus? status) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _filter == status,
      onSelected: (_) => setState(() => _filter = status),
    ),
  );
}
