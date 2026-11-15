import 'package:flutter/material.dart';

import '../models/booking.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      BookingStatus.pending => (Colors.amber.shade100, Colors.brown.shade800),
      BookingStatus.confirmed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      BookingStatus.completed => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      BookingStatus.rejected ||
      BookingStatus.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
