import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/service.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/async_value_view.dart';

/// Create a service, or edit one when [serviceId] is given.
class ServiceFormScreen extends ConsumerWidget {
  const ServiceFormScreen({super.key, this.serviceId});
  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = serviceId;
    if (id == null) return const _ServiceForm(existing: null);
    final service = ref.watch(serviceDetailProvider(id));
    return service.when(
      data: (s) => _ServiceForm(existing: s),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit service')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit service')),
        body: ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(serviceDetailProvider(id)),
        ),
      ),
    );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({required this.existing});
  final Service? existing;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _location = TextEditingController(text: widget.existing?.location);
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.pricePerSlot.toStringAsFixed(0),
  );
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl);
  late String _category = widget.existing?.category ?? serviceCategories.first;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _description, _location, _price, _imageUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vendorId = ref.read(currentUserIdProvider);
    if (vendorId == null) return;
    setState(() => _saving = true);
    final service = Service(
      id: widget.existing?.id ?? '',
      vendorId: vendorId,
      name: _name.text.trim(),
      description: _description.text.trim(),
      category: _category,
      location: _location.text.trim(),
      pricePerSlot: double.parse(_price.text.trim()),
      imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      isActive: widget.existing?.isActive ?? true,
    );
    try {
      final catalog = ref.read(catalogServiceProvider);
      if (_isEdit) {
        await catalog.updateService(service);
        ref.invalidate(serviceDetailProvider(service.id));
        ref.invalidate(myServicesProvider);
        if (mounted) context.pop();
      } else {
        final created = await catalog.createService(service);
        ref.invalidate(myServicesProvider);
        if (!mounted) return;
        showSnackBar(context, 'Service added. Now open some slots for customers to book.');
        context.pushReplacement('/my-services/${created.id}/slots');
      }
    } catch (e) {
      if (mounted) showSnackBar(context, friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {...serviceCategories, _category}.toList();
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit service' : 'New service')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Green Field Turf – Court A',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => validateRequired(v, field: 'Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Area and city, e.g. Koramangala, Bengaluru',
              ),
              validator: (v) => validateRequired(v, field: 'Location'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Price per slot', prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: validatePrice,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Surface, size, facilities, rules…',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrl,
              decoration: const InputDecoration(labelText: 'Photo URL (optional)'),
              keyboardType: TextInputType.url,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                final uri = Uri.tryParse(t);
                return uri != null && uri.hasScheme && uri.host.isNotEmpty
                    ? null
                    : 'Enter a full link starting with https://';
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add service'),
            ),
          ],
        ),
      ),
    );
  }
}
