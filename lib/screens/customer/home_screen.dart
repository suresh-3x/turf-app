import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/vendor_service.dart';
import '../../widgets/service_card.dart';
import '../../models/service.dart';
import 'package:go_router/go_router.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(allServicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Services')),
      body: servicesAsync.when(
        data: (services) => ListView.builder(
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return GestureDetector(
              onTap: () => context.go('/service/${service.id}'),
              child: ServiceCard(service: service),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
} 