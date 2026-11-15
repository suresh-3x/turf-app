import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/booking.dart';
import '../../services/booking_service.dart';
import '../../utils/helpers.dart';

/// Buttons a vendor can use on a booking, depending on its state.
List<Widget> vendorBookingActions(BuildContext context, WidgetRef ref, Booking b) {
  Future<void> change(BookingStatus to, {String? confirmTitle, String? confirmMessage}) async {
    if (confirmTitle != null) {
      final ok = await confirmAction(
        context,
        title: confirmTitle,
        message: confirmMessage ?? '',
        confirmLabel: 'Yes',
        destructive: to == BookingStatus.rejected || to == BookingStatus.cancelled,
      );
      if (!ok) return;
    }
    try {
      await ref.read(bookingServiceProvider).updateStatus(b.id, to);
      ref.invalidate(vendorBookingsProvider);
      if (context.mounted) showSnackBar(context, 'Booking ${to.label.toLowerCase()}.');
    } catch (e) {
      if (context.mounted) showSnackBar(context, friendlyError(e), isError: true);
    }
  }

  return switch (b.status) {
    BookingStatus.pending => [
      TextButton(
        onPressed: () => change(
          BookingStatus.rejected,
          confirmTitle: 'Decline booking?',
          confirmMessage: 'The customer will be told and the slot freed up.',
        ),
        child: const Text('Decline'),
      ),
      if (!b.hasStarted)
        FilledButton(onPressed: () => change(BookingStatus.confirmed), child: const Text('Accept')),
    ],
    BookingStatus.confirmed => [
      if (!b.hasStarted)
        TextButton(
          onPressed: () => change(
            BookingStatus.cancelled,
            confirmTitle: 'Cancel this booking?',
            confirmMessage: 'The customer will be told and the slot freed up.',
          ),
          child: const Text('Cancel'),
        ),
      if (b.hasStarted)
        FilledButton.tonal(
          onPressed: () => change(BookingStatus.completed),
          child: const Text('Mark completed'),
        ),
    ],
    _ => const [],
  };
}
