import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/review.dart';
import '../../models/service.dart';
import '../../models/slot.dart';
import '../../services/catalog_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/rating_widget.dart';
import '../../widgets/service_card.dart';
import '../../widgets/slot_calendar.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});
  final String serviceId;

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  Slot? _selected;

  Future<void> _refresh() async {
    setState(() => _selected = null);
    ref.invalidate(upcomingSlotsProvider(widget.serviceId));
    ref.invalidate(serviceReviewsProvider(widget.serviceId));
    final _ = await ref.refresh(serviceDetailProvider(widget.serviceId).future);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(serviceDetailProvider(widget.serviceId));
    return Scaffold(
      appBar: AppBar(title: Text(service.valueOrNull?.name ?? 'Details')),
      body: AsyncValueView(
        value: service,
        onRetry: _refresh,
        data: (s) => RefreshIndicator(onRefresh: _refresh, child: _body(context, s)),
      ),
      bottomNavigationBar: service.hasValue && service.value!.isActive
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () async {
                          await context.push(
                            '/home/service/${widget.serviceId}/book/${_selected!.id}',
                          );
                          // Slot may have been booked; reload.
                          if (mounted) _refresh();
                        },
                  child: Text(
                    _selected == null
                        ? 'Pick a slot'
                        : 'Book ${formatTime(_selected!.startTime)} · ${formatPrice(service.value!.pricePerSlot)}',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _body(BuildContext context, Service s) {
    final theme = Theme.of(context);
    final slots = ref.watch(upcomingSlotsProvider(widget.serviceId));
    final reviews = ref.watch(serviceReviewsProvider(widget.serviceId));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ServiceImage(service: s, height: 200),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(s.name, style: theme.textTheme.headlineSmall)),
                  RatingSummary(average: s.averageRating, count: s.reviewCount),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(iconForCategory(s.category), size: 18),
                    label: Text(s.category),
                  ),
                  Chip(
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    label: Text('${formatPrice(s.pricePerSlot)} / slot'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Line(icon: Icons.place_outlined, text: s.location),
              if (s.vendor != null) ...[
                _Line(icon: Icons.storefront_outlined, text: s.vendor!.name),
                if ((s.vendor!.phone ?? '').isNotEmpty)
                  _Line(icon: Icons.phone_outlined, text: s.vendor!.phone!),
              ],
              if (s.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(s.description, style: theme.textTheme.bodyMedium),
              ],
              const Divider(height: 32),
              Text('Pick a slot', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (!s.isActive)
                const Text('This venue is not taking bookings right now.')
              else
                AsyncValueView(
                  value: slots,
                  onRetry: () => ref.invalidate(upcomingSlotsProvider(widget.serviceId)),
                  data: (list) => list.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No upcoming slots. Check back later.'),
                        )
                      : SlotCalendar(
                          slots: list,
                          selectedSlotId: _selected?.id,
                          onSlotSelected: (slot) => setState(() => _selected = slot),
                        ),
                ),
              const Divider(height: 32),
              Text('Reviews', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              AsyncValueView(
                value: reviews,
                data: (list) => list.isEmpty
                    ? const Text('No reviews yet.')
                    : Column(children: [for (final r in list) _ReviewTile(review: r)]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingWidget(rating: review.rating, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.customerName ?? 'Customer',
                  style: theme.textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(formatRelative(review.createdAt), style: theme.textTheme.bodySmall),
            ],
          ),
          if (review.comment.isNotEmpty) ...[const SizedBox(height: 4), Text(review.comment)],
        ],
      ),
    );
  }
}
