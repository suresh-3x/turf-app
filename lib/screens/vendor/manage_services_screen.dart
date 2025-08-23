import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/vendor_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/service_card.dart';
import '../../models/service.dart';

class ManageServicesScreen extends ConsumerWidget {
  const ManageServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in as a vendor.')),
      );
    }
    final servicesAsync = ref.watch(vendorServicesProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Services')),
      body: servicesAsync.when(
        data: (services) => services.isEmpty
            ? const Center(child: Text('No services found.'))
            : ListView.builder(
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  return ServiceCard(service: service);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (context) => AddServiceDialog(vendorId: user.id),
          );
          ref.refresh(vendorServicesProvider(user.id));
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Service',
      ),
    );
  }
}

class AddServiceDialog extends ConsumerStatefulWidget {
  final String vendorId;
  const AddServiceDialog({super.key, required this.vendorId});

  @override
  ConsumerState<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends ConsumerState<AddServiceDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Service'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref.read(vendorServiceProvider).createService(
              Service(
                id: '',
                vendorId: widget.vendorId,
                name: _nameController.text,
                description: _descController.text,
                category: _categoryController.text,
                location: _locationController.text,
              ),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
} 