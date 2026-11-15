import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../utils/formatters.dart';
import 'status_chip.dart';

/// Summary of a booking. [showCustomer] is for the vendor's view.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.showCustomer = false,
    this.actions = const [],
    this.onTap,
  });

  final Booking booking;
  final bool showCustomer;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = booking.slot;
    final customer = booking.customer;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      booking.service?.name ?? 'Service',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: booking.status),
                ],
              ),
              const SizedBox(height: 8),
              if (slot != null)
                _InfoRow(icon: Icons.event, text: formatSlot(slot.startTime, slot.endTime)),
              if (!showCustomer && booking.service != null)
                _InfoRow(icon: Icons.place_outlined, text: booking.service!.location),
              if (showCustomer && customer != null) ...[
                _InfoRow(icon: Icons.person_outline, text: customer.name),
                if (customer.phone != null && customer.phone!.isNotEmpty)
                  _InfoRow(icon: Icons.phone_outlined, text: customer.phone!),
                _InfoRow(icon: Icons.mail_outline, text: customer.email),
              ],
              if (booking.notes != null && booking.notes!.isNotEmpty)
                _InfoRow(icon: Icons.notes, text: booking.notes!),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 4, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
