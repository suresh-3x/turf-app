import 'package:flutter/material.dart';

import '../models/slot.dart';
import '../utils/formatters.dart';

/// A horizontal strip of days with the slots of the selected day below it.
///
/// Days are the next [days] days from today. Booked or past slots are shown
/// but cannot be selected.
class SlotCalendar extends StatefulWidget {
  const SlotCalendar({
    super.key,
    required this.slots,
    required this.onSlotSelected,
    this.selectedSlotId,
    this.days = 14,
  });

  final List<Slot> slots;
  final ValueChanged<Slot> onSlotSelected;
  final String? selectedSlotId;
  final int days;

  @override
  State<SlotCalendar> createState() => _SlotCalendarState();
}

class _SlotCalendarState extends State<SlotCalendar> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    // Start on the first day that has a free slot, if any.
    final firstFree = widget.slots.where((s) => s.isAvailable).firstOrNull;
    _selectedDay = dateOnly(firstFree?.startTime ?? DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    final days = List.generate(widget.days, (i) => today.add(Duration(days: i)));
    final daySlots = widget.slots.where((s) => isSameDay(s.startTime, _selectedDay)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = days[i];
              final freeCount = widget.slots
                  .where((s) => s.isAvailable && isSameDay(s.startTime, day))
                  .length;
              return _DayTile(
                day: day,
                selected: isSameDay(day, _selectedDay),
                freeCount: freeCount,
                onTap: () => setState(() => _selectedDay = day),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (daySlots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No slots on ${formatDay(_selectedDay)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in daySlots)
                ChoiceChip(
                  key: ValueKey(slot.id),
                  label: Text(formatTimeRange(slot.startTime, slot.endTime)),
                  selected: slot.id == widget.selectedSlotId,
                  onSelected: slot.isAvailable ? (_) => widget.onSlotSelected(slot) : null,
                  tooltip: slot.isBooked ? 'Already booked' : null,
                ),
            ],
          ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.selected,
    required this.freeCount,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final int freeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_weekday(day), style: text.labelSmall?.copyWith(color: fg)),
              Text('${day.day}', style: text.titleMedium?.copyWith(color: fg)),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: freeCount > 0
                      ? (selected ? scheme.onPrimary : scheme.primary)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _weekday(DateTime d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
}
