import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/slot.dart';
import '../../services/catalog_service.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../utils/slot_generator.dart';
import '../../widgets/async_value_view.dart';

/// Slots of one service for the next [_daysShown] days.
final _vendorSlotsProvider = FutureProvider.autoDispose.family<List<Slot>, String>((
  ref,
  serviceId,
) {
  final today = dateOnly(DateTime.now());
  return ref
      .watch(catalogServiceProvider)
      .fetchSlotsBetween(serviceId, today, today.add(const Duration(days: _daysShown)));
});

const _daysShown = 60;

class ManageSlotsScreen extends ConsumerStatefulWidget {
  const ManageSlotsScreen({super.key, required this.serviceId});
  final String serviceId;

  @override
  ConsumerState<ManageSlotsScreen> createState() => _ManageSlotsScreenState();
}

class _ManageSlotsScreenState extends ConsumerState<ManageSlotsScreen> {
  DateTime _day = dateOnly(DateTime.now());

  Future<void> _delete(Slot slot) async {
    try {
      await ref.read(catalogServiceProvider).deleteSlot(slot.id);
      ref.invalidate(_vendorSlotsProvider(widget.serviceId));
    } catch (e) {
      if (mounted) showSnackBar(context, friendlyError(e), isError: true);
    }
  }

  Future<void> _deleteFreeSlotsOfDay(List<Slot> daySlots) async {
    final free = daySlots.where((s) => !s.isBooked).toList();
    if (free.isEmpty) return;
    final ok = await confirmAction(
      context,
      title: 'Remove ${free.length} free slot${free.length == 1 ? '' : 's'}?',
      message: 'Booked slots on ${formatDay(_day)} are kept.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      for (final s in free) {
        await ref.read(catalogServiceProvider).deleteSlot(s.id);
      }
    } catch (e) {
      if (mounted) showSnackBar(context, friendlyError(e), isError: true);
    }
    ref.invalidate(_vendorSlotsProvider(widget.serviceId));
  }

  Future<void> _openGenerator(List<Slot> existing) async {
    final created = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _AddSlotsSheet(serviceId: widget.serviceId, initialDay: _day, existing: existing),
    );
    if (created != null && mounted) {
      ref.invalidate(_vendorSlotsProvider(widget.serviceId));
      ref.invalidate(upcomingSlotsProvider(widget.serviceId));
      showSnackBar(
        context,
        created == 0
            ? 'No new slots — they all overlap existing ones.'
            : 'Added $created slot${created == 1 ? '' : 's'}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(serviceDetailProvider(widget.serviceId));
    final slots = ref.watch(_vendorSlotsProvider(widget.serviceId));
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    final days = List.generate(_daysShown, (i) => today.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(title: Text(service.valueOrNull?.name ?? 'Slots')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: slots.hasValue ? () => _openGenerator(slots.value!) : null,
        icon: const Icon(Icons.add),
        label: const Text('Add slots'),
      ),
      body: AsyncValueView(
        value: slots,
        onRetry: () => ref.invalidate(_vendorSlotsProvider(widget.serviceId)),
        data: (all) {
          final daySlots = all.where((s) => isSameDay(s.startTime, _day)).toList();
          final bookedCount = daySlots.where((s) => s.isBooked).length;
          return Column(
            children: [
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final count = all.where((s) => isSameDay(s.startTime, d)).length;
                    final selected = isSameDay(d, _day);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        selected: selected,
                        onSelected: (_) => setState(() => _day = d),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatDay(d).split(',').first),
                            Text('${d.day}', style: theme.textTheme.titleSmall),
                            Text(count == 0 ? '—' : '$count', style: theme.textTheme.labelSmall),
                          ],
                        ),
                        showCheckmark: false,
                      ),
                    );
                  },
                ),
              ),
              ListTile(
                title: Text(formatDayLong(_day)),
                subtitle: Text(
                  daySlots.isEmpty ? 'No slots' : '${daySlots.length} slots · $bookedCount booked',
                ),
                trailing: daySlots.any((s) => !s.isBooked)
                    ? TextButton(
                        onPressed: () => _deleteFreeSlotsOfDay(daySlots),
                        child: const Text('Clear free'),
                      )
                    : null,
              ),
              const Divider(height: 1),
              Expanded(
                child: daySlots.isEmpty
                    ? EmptyState(
                        icon: Icons.event_busy,
                        title: 'No slots on this day',
                        message: 'Tap "Add slots" to open times for customers to book.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: daySlots.length,
                        itemBuilder: (context, i) {
                          final s = daySlots[i];
                          return ListTile(
                            leading: Icon(
                              s.isBooked ? Icons.event_busy : Icons.event_available,
                              color: s.isBooked
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.primary,
                            ),
                            title: Text(formatTimeRange(s.startTime, s.endTime)),
                            subtitle: Text(
                              s.isBooked
                                  ? 'Booked'
                                  : s.hasStarted
                                  ? 'Passed'
                                  : 'Free · ${formatDuration(s.duration)}',
                            ),
                            trailing: s.isBooked
                                ? null
                                : IconButton(
                                    tooltip: 'Remove slot',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(s),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Form for opening slots over a range of days. Pops with the number created.
class _AddSlotsSheet extends ConsumerStatefulWidget {
  const _AddSlotsSheet({required this.serviceId, required this.initialDay, required this.existing});

  final String serviceId;
  final DateTime initialDay;
  final List<Slot> existing;

  @override
  ConsumerState<_AddSlotsSheet> createState() => _AddSlotsSheetState();
}

class _AddSlotsSheetState extends ConsumerState<_AddSlotsSheet> {
  late DateTime _firstDay = widget.initialDay;
  int _days = 1;
  TimeOfDay _open = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _close = const TimeOfDay(hour: 22, minute: 0);
  int _lengthMinutes = 60;
  final Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  bool _saving = false;

  static const _lengths = [30, 45, 60, 90, 120];
  static const _dayOptions = [1, 7, 14, 30];
  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  SlotPlan get _plan {
    final open = _open.hour * 60 + _open.minute;
    var close = _close.hour * 60 + _close.minute;
    // Closing at midnight (00:00) means the end of the day.
    if (close == 0) close = 24 * 60;
    return SlotPlan(
      firstDay: _firstDay,
      numberOfDays: _days,
      openMinutes: open,
      closeMinutes: close,
      slotLength: Duration(minutes: _lengthMinutes),
      weekdays: _weekdays,
    );
  }

  Future<void> _save(List<SlotRange> ranges) async {
    setState(() => _saving = true);
    try {
      await ref.read(catalogServiceProvider).createSlots(widget.serviceId, ranges);
      if (mounted) Navigator.of(context).pop(ranges.length);
    } catch (e) {
      if (mounted) showSnackBar(context, friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(bool open) async {
    final picked = await showTimePicker(context: context, initialTime: open ? _open : _close);
    if (picked != null) setState(() => open ? _open = picked : _close = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = generateSlots(_plan, existing: widget.existing);
    final closeBeforeOpen = _plan.closeMinutes <= _plan.openMinutes;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add slots', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Starting'),
              subtitle: Text(formatDayLong(_firstDay)),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _firstDay,
                  firstDate: dateOnly(now),
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _firstDay = picked);
              },
            ),
            Text('For', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final d in _dayOptions)
                  ButtonSegment(value: d, label: Text(d == 1 ? '1 day' : '$d days')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
            if (_days > 1) ...[
              const SizedBox(height: 12),
              Text('On', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(_weekdayLetters[i - 1]),
                      showCheckmark: false,
                      selected: _weekdays.contains(i),
                      onSelected: (sel) =>
                          setState(() => sel ? _weekdays.add(i) : _weekdays.remove(i)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: Text('Opens ${_open.format(context)}'),
                    onPressed: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.nightlight_outlined),
                    label: Text('Closes ${_close.format(context)}'),
                    onPressed: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Slot length', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in _lengths)
                  ChoiceChip(
                    label: Text(formatDuration(Duration(minutes: m))),
                    selected: _lengthMinutes == m,
                    onSelected: (_) => setState(() => _lengthMinutes = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (closeBeforeOpen)
              Text(
                'Closing time must be after opening time.',
                style: TextStyle(color: theme.colorScheme.error),
              )
            else
              Text(
                preview.isEmpty
                    ? 'No new slots: they would be in the past or overlap existing ones.'
                    : 'This creates ${preview.length} slot${preview.length == 1 ? '' : 's'}'
                          '${preview.length <= 3 ? ': ${preview.map((r) => formatTimeRange(r.start, r.end)).join(', ')}' : ', first ${formatSlot(preview.first.start, preview.first.end)}'}.',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || preview.isEmpty ? null : () => _save(preview),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(preview.isEmpty ? 'Add slots' : 'Add ${preview.length} slots'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
