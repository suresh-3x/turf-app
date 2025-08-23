import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/booking_card.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your bookings.')),
      );
    }
    final bookingsAsync = ref.watch(userBookingsProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: bookingsAsync.when(
        data: (bookings) => bookings.isEmpty
            ? const Center(child: Text('No bookings found.'))
            : ListView.builder(
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  return BookingCard(booking: booking);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
} 