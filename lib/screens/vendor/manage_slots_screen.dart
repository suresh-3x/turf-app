import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/vendor_service.dart';
import '../../models/slot.dart';

class ManageSlotsScreen extends ConsumerWidget {
  const ManageSlotsScreen({super.key, required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(serviceSlotsProvider(serviceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Slots')),
      body: slotsAsync.when(
        data: (slots) => slots.isEmpty
            ? const Center(child: Text('No slots found.'))
            : ListView.builder(
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  return ListTile(
                    title: Text('${slot.startTime} - ${slot.endTime}'),
                    subtitle: Text(slot.isBooked ? 'Booked' : 'Available'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (context) => AddSlotDialog(serviceId: serviceId),
          );
          ref.refresh(serviceSlotsProvider(serviceId));
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Slot',
      ),
    );
  }
}

class AddSlotDialog extends ConsumerStatefulWidget {
  final String serviceId;
  const AddSlotDialog({super.key, required this.serviceId});

  @override
  ConsumerState<AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends ConsumerState<AddSlotDialog> {
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Slot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(_startTime == null ? 'Select Start Time' : _startTime.toString()),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDateTimePicker(context);
              if (picked != null) setState(() => _startTime = picked);
            },
          ),
          ListTile(
            title: Text(_endTime == null ? 'Select End Time' : _endTime.toString()),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDateTimePicker(context);
              if (picked != null) setState(() => _endTime = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _startTime != null && _endTime != null
              ? () async {
                  await ref.read(vendorServiceProvider).createSlot(
                        serviceId: widget.serviceId,
                        startTime: _startTime!,
                        endTime: _endTime!,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                }
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

Future<DateTime?> showDateTimePicker(BuildContext context) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
} 