import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/service.dart';
import '../../services/catalog_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/service_card.dart';

class ManageServicesScreen extends ConsumerWidget {
  const ManageServicesScreen({super.key});

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, Service s) async {
    try {
      await ref.read(catalogServiceProvider).setServiceActive(s.id, !s.isActive);
      ref.invalidate(myServicesProvider);
      if (context.mounted) {
        showSnackBar(
          context,
          s.isActive ? '${s.name} is hidden from customers.' : '${s.name} is live.',
        );
      }
    } catch (e) {
      if (context.mounted) showSnackBar(context, friendlyError(e), isError: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Service s) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${s.name}?',
      message:
          'This removes the service, all its slots, bookings and reviews. '
          'To stop taking bookings but keep the history, pause it instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(catalogServiceProvider).deleteService(s.id);
      ref.invalidate(myServicesProvider);
    } catch (e) {
      if (context.mounted) showSnackBar(context, friendlyError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(myServicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/my-services/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: AsyncValueView(
        value: services,
        onRetry: () => ref.invalidate(myServicesProvider),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(myServicesProvider.future),
          child: list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 48),
                    EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No services yet',
                      message:
                          'Add your turf, court or game zone so customers can find and book it.',
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return ServiceCard(
                      service: s,
                      onTap: () => context.push('/my-services/${s.id}/slots'),
                      trailing: Row(
                        children: [
                          if (!s.isActive)
                            Text(
                              'Paused',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: () => context.push('/my-services/${s.id}/slots'),
                            icon: const Icon(Icons.calendar_month, size: 18),
                            label: const Text('Slots'),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'More',
                            onSelected: (v) {
                              switch (v) {
                                case 'edit':
                                  context.push('/my-services/${s.id}/edit');
                                case 'toggle':
                                  _toggleActive(context, ref, s);
                                case 'delete':
                                  _delete(context, ref, s);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(s.isActive ? 'Pause bookings' : 'Resume bookings'),
                              ),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
