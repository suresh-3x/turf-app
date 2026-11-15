import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/service.dart';
import '../../models/slot.dart';
import '../../services/booking_service.dart';
import '../../services/catalog_service.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/async_value_view.dart';

/// Review and confirm a booking for one slot.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.serviceId, required this.slotId});
  final String serviceId;
  final String slotId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirm(Service service, Slot slot) async {
    setState(() => _submitting = true);
    try {
      await ref.read(bookingServiceProvider).bookSlot(slot.id, notes: _notesController.text);
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, size: 48),
          title: const Text('Booking requested'),
          content: Text(
            '${service.name}\n${formatSlot(slot.startTime, slot.endTime)}\n\n'
            "We've sent your request to the venue. You'll get a notification "
            'when they confirm it.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('View my bookings'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/bookings');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, friendlyError(e), isError: true);
      // The slot may be gone; refresh so the user sees its current state.
      ref.invalidate(slotDetailProvider(widget.slotId));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(serviceDetailProvider(widget.serviceId));
    final slot = ref.watch(slotDetailProvider(widget.slotId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm booking')),
      body: AsyncValueView(
        value: service,
        onRetry: () => ref.invalidate(serviceDetailProvider(widget.serviceId)),
        data: (s) => AsyncValueView(
          value: slot,
          onRetry: () => ref.invalidate(slotDetailProvider(widget.slotId)),
          data: (sl) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(s.location, style: theme.textTheme.bodyMedium),
                      const Divider(height: 24),
                      _Row(label: 'Date', value: formatDayLong(sl.startTime)),
                      _Row(label: 'Time', value: formatTimeRange(sl.startTime, sl.endTime)),
                      _Row(label: 'Duration', value: formatDuration(sl.duration)),
                      const Divider(height: 24),
                      _Row(label: 'Price', value: formatPrice(s.pricePerSlot), emphasize: true),
                      const SizedBox(height: 4),
                      Text('Pay at the venue.', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Note for the venue (optional)',
                  hintText: 'e.g. number of players, equipment needed',
                ),
                maxLines: 3,
                maxLength: 300,
              ),
              const SizedBox(height: 8),
              if (!sl.isAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    sl.isBooked
                        ? 'Sorry, this slot has just been booked. Please pick another.'
                        : 'This slot has already started. Please pick another.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: _submitting || !sl.isAvailable ? null : () => _confirm(s, sl),
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Request booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasize
                  ? theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
