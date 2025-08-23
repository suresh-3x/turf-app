import 'package:flutter/material.dart';

class BookingRequestsScreen extends StatelessWidget {
  const BookingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Requests')),
      body: const Center(
        child: Text('List of pending booking requests'),
        // TODO: Add list of requests with accept/reject buttons
      ),
    );
  }
} 