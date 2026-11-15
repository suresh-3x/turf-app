import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/booking.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/catalog_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/notification_bell.dart';
import 'booking_actions.dart';

/// Numbers shown on the vendor dashboard. Pure so it can be unit tested.
class DashboardStats {
  const DashboardStats({
    required this.pending,
    required this.today,
    required this.upcoming,
    required this.completedThisMonth,
    required this.earningsThisMonth,
  });

  final int pending;
  final List<Booking> today;
  final int upcoming;
  final int completedThisMonth;
  final double earningsThisMonth;

  factory DashboardStats.from(List<Booking> bookings, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final active = bookings.where((b) => b.status.isActive);
    final completedThisMonth = bookings.where(
      (b) =>
          b.status == BookingStatus.completed &&
          b.startTime != null &&
          b.startTime!.year == n.year &&
          b.startTime!.month == n.month,
    );
    return DashboardStats(
      pending: active
          .where((b) => b.status == BookingStatus.pending && (b.startTime?.isAfter(n) ?? false))
          .length,
      today: active.where((b) => b.startTime != null && isSameDay(b.startTime!, n)).toList(),
      upcoming: active.where((b) => b.startTime?.isAfter(n) ?? false).length,
      completedThisMonth: completedThisMonth.length,
      earningsThisMonth: completedThisMonth.fold(
        0.0,
        (sum, b) => sum + (b.service?.pricePerSlot ?? 0),
      ),
    );
  }
}

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(vendorBookingsProvider);
    final services = ref.watch(myServicesProvider);
    final name = ref.watch(currentProfileProvider).valueOrNull?.name ?? '';
    final theme = Theme.of(context);

    Future<void> refresh() async {
      ref.invalidate(myServicesProvider);
      final _ = await ref.refresh(vendorBookingsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Dashboard' : name),
        actions: const [NotificationBell()],
      ),
      body: AsyncValueView(
        value: bookings,
        onRetry: refresh,
        data: (list) {
          final stats = DashboardStats.from(list);
          final hasServices = services.valueOrNull?.isNotEmpty ?? true;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (!hasServices)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: theme.colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.add_business),
                      title: const Text('Add your first service'),
                      subtitle: const Text(
                        'List your venue and open slots to start taking bookings.',
                      ),
                      onTap: () => context.push('/my-services/new'),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.8,
                    children: [
                      _StatTile(
                        label: 'Awaiting reply',
                        value: '${stats.pending}',
                        icon: Icons.hourglass_top,
                        highlight: stats.pending > 0,
                        onTap: () => context.go('/requests'),
                      ),
                      _StatTile(
                        label: 'Upcoming',
                        value: '${stats.upcoming}',
                        icon: Icons.event,
                        onTap: () => context.go('/requests'),
                      ),
                      _StatTile(
                        label: 'Completed this month',
                        value: '${stats.completedThisMonth}',
                        icon: Icons.check_circle_outline,
                        onTap: () => context.push('/history'),
                      ),
                      _StatTile(
                        label: 'Earned this month',
                        value: formatPrice(stats.earningsThisMonth),
                        icon: Icons.payments_outlined,
                        onTap: () => context.push('/history'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text("Today's schedule", style: theme.textTheme.titleMedium),
                ),
                if (stats.today.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('No bookings today.'),
                  )
                else
                  for (final b in stats.today)
                    BookingCard(
                      booking: b,
                      showCustomer: true,
                      actions: vendorBookingActions(context, ref, b),
                    ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Booking history'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/history'),
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Manage services & slots'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/my-services'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: highlight ? scheme.tertiaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: theme.textTheme.headlineSmall),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
