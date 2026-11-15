import '../models/slot.dart';

/// Settings for creating many slots at once.
class SlotPlan {
  const SlotPlan({
    required this.firstDay,
    required this.numberOfDays,
    required this.openMinutes,
    required this.closeMinutes,
    required this.slotLength,
    this.gap = Duration.zero,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
  });

  /// Date of the first day (time ignored).
  final DateTime firstDay;
  final int numberOfDays;

  /// Opening time as minutes after midnight, e.g. 6:00 = 360.
  final int openMinutes;

  /// Closing time as minutes after midnight. Values above 1440 run past midnight.
  final int closeMinutes;
  final Duration slotLength;

  /// Break between consecutive slots.
  final Duration gap;

  /// DateTime.monday (1) .. DateTime.sunday (7).
  final Set<int> weekdays;
}

/// Splits each selected day's opening hours into back-to-back slots.
///
/// Skips slots that would start before [now] and slots overlapping any in
/// [existing], so the result can be inserted without conflicts.
List<SlotRange> generateSlots(SlotPlan plan, {List<Slot> existing = const [], DateTime? now}) {
  final current = now ?? DateTime.now();
  final result = <SlotRange>[];
  if (plan.slotLength <= Duration.zero || plan.closeMinutes <= plan.openMinutes) return result;

  final first = DateTime(plan.firstDay.year, plan.firstDay.month, plan.firstDay.day);
  for (var d = 0; d < plan.numberOfDays; d++) {
    // Build the day from calendar fields so DST changes do not shift times.
    final day = DateTime(first.year, first.month, first.day + d);
    if (!plan.weekdays.contains(day.weekday)) continue;

    final close = DateTime(day.year, day.month, day.day, 0, plan.closeMinutes);
    var start = DateTime(day.year, day.month, day.day, 0, plan.openMinutes);
    while (true) {
      final end = start.add(plan.slotLength);
      if (end.isAfter(close)) break;
      final overlaps = existing.any((s) => start.isBefore(s.endTime) && end.isAfter(s.startTime));
      if (start.isAfter(current) && !overlaps) result.add(SlotRange(start, end));
      start = end.add(plan.gap);
    }
  }
  return result;
}
