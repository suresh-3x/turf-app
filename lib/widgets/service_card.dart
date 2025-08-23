import 'package:flutter/material.dart';

import '../../models/service.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});
  final Service service;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(service.name),
        subtitle: Text(service.location),
        // TODO: Add onTap to navigate to service details
      ),
    );
  }
} 