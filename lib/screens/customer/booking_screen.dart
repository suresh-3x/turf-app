import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import '../../models/slot.dart';
import '../../models/service.dart';
import 'package:go_router/go_router.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key, required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotId = GoRouterState.of(context).uri.queryParameters['slotId'];
    final slotAsync = slotId != null ? ref.watch(slotProvider(slotId)) : null;
    final serviceAsync = ref.watch(serviceProvider(serviceId));
    final user = ref.read(authServiceProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Book a Slot')),
      body: slotId == null
          ? const Center(child: Text('No slot selected'))
          : serviceAsync.when(
              data: (service) => slotAsync!.when(
                data: (slot) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(service.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Slot: ${slot.startTime} - ${slot.endTime}'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: user == null
                            ? null
                            : () async {
                                await ref.read(bookingServiceProvider).createBooking(
                                      serviceId: service.id,
                                      userId: user.id,
                                      slotId: slot.id,
                                      startTime: slot.startTime,
                                      endTime: slot.endTime,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Booking confirmed!')),
                                  );
                                  context.go('/my-bookings');
                                }
                              },
                        child: const Text('Confirm Booking'),
                      ),
                    ],
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error loading slot: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading service: $e')),
            ),
    );
  }
} 