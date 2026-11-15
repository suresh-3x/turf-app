import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/booking_service.dart';
import '../../services/catalog_service.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/rating_widget.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(String serviceId) async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(catalogServiceProvider)
          .submitReview(
            bookingId: widget.bookingId,
            rating: _rating,
            comment: _commentController.text,
          );
      ref.invalidate(myBookingsProvider);
      ref.invalidate(serviceReviewsProvider(serviceId));
      ref.invalidate(serviceDetailProvider(serviceId));
      if (!mounted) return;
      showSnackBar(context, 'Thanks for your review!');
      context.pop();
    } catch (e) {
      if (mounted) showSnackBar(context, friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingDetailProvider(widget.bookingId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a review')),
      body: AsyncValueView(
        value: booking,
        onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        data: (b) {
          if (!b.canReview) {
            return EmptyState(
              icon: Icons.rate_review_outlined,
              title: b.hasReview ? 'You already reviewed this booking' : 'Not ready for review',
              message: b.hasReview
                  ? null
                  : 'You can review a booking once the venue marks it completed.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(b.service?.name ?? '', style: theme.textTheme.titleLarge),
              if (b.slot != null)
                Text(
                  formatSlot(b.slot!.startTime, b.slot!.endTime),
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 24),
              Text('How was it?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Center(
                child: RatingWidget(
                  rating: _rating,
                  size: 40,
                  onChanged: (r) => setState(() => _rating = r),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(labelText: 'Tell others about it (optional)'),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _rating == 0 || _submitting ? null : () => _submit(b.serviceId),
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit review'),
              ),
            ],
          );
        },
      ),
    );
  }
}
