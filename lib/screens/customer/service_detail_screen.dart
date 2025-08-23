import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/vendor_service.dart';
import '../../models/service.dart';
import '../../models/slot.dart';
import 'package:go_router/go_router.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceProvider(serviceId));
    final slotsAsync = ref.watch(slotsProvider(serviceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: serviceAsync.when(
        data: (service) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(service.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(service.description),
              const SizedBox(height: 8),
              Text('Location: ${service.location}'),
              const SizedBox(height: 16),
              Text('Available Slots:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: slotsAsync.when(
                  data: (slots) => slots.isEmpty
                      ? const Text('No slots available')
                      : ListView.builder(
                          itemCount: slots.length,
                          itemBuilder: (context, index) {
                            final slot = slots[index];
                            return ListTile(
                              title: Text('${slot.startTime} - ${slot.endTime}'),
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () => context.go('/book/${service.id}?slotId=${slot.id}'),
                            );
                          },
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text('Error loading slots: $e'),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
} 