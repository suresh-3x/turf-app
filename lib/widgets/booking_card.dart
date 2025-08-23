import 'package:flutter/material.dart';

import '../../models/booking.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Booking for ${booking.serviceId}'),
        subtitle: Text('Status: ${booking.status}'),
        // TODO: Add more details and actions
      ),
    );
  }
} 