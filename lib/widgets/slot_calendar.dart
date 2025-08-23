import 'package:flutter/material.dart';

class SlotCalendar extends StatelessWidget {
  const SlotCalendar({super.key, required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Slot Calendar Placeholder'),
        // TODO: Implement a calendar to show and select available slots
      ),
    );
  }
} 