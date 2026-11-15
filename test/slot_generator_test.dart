import 'package:flutter_test/flutter_test.dart';
import 'package:turfapp/models/slot.dart';
import 'package:turfapp/utils/slot_generator.dart';

void main() {
  final monday = DateTime(2030, 1, 7); // a Monday
  final beforeEverything = DateTime(2030, 1, 1);

  SlotPlan plan({
    int days = 1,
    int open = 6 * 60,
    int close = 10 * 60,
    int length = 60,
    Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
  }) => SlotPlan(
    firstDay: monday,
    numberOfDays: days,
    openMinutes: open,
    closeMinutes: close,
    slotLength: Duration(minutes: length),
    weekdays: weekdays,
  );

  test('splits opening hours into back-to-back slots', () {
    final slots = generateSlots(plan(), now: beforeEverything);
    expect(slots.length, 4);
    expect(slots.first.start, DateTime(2030, 1, 7, 6));
    expect(slots.last.end, DateTime(2030, 1, 7, 10));
  });

  test('drops a final partial slot', () {
    final slots = generateSlots(plan(close: 9 * 60 + 30, length: 60), now: beforeEverything);
    expect(slots.length, 3);
    expect(slots.last.end, DateTime(2030, 1, 7, 9));
  });

  test('repeats over days and respects weekdays', () {
    // Mon..Sun, weekends only
    final slots = generateSlots(plan(days: 7, weekdays: {6, 7}), now: beforeEverything);
    expect(slots.length, 8);
    expect(slots.map((s) => s.start.weekday).toSet(), {6, 7});
  });

  test('closing at midnight covers the last hour', () {
    final slots = generateSlots(
      plan(open: 22 * 60, close: 24 * 60),
      now: beforeEverything,
    );
    expect(slots.length, 2);
    expect(slots.last.end, DateTime(2030, 1, 8));
  });

  test('skips slots in the past', () {
    final slots = generateSlots(plan(), now: DateTime(2030, 1, 7, 7, 30));
    expect(slots.map((s) => s.start.hour), [8, 9]);
  });

  test('skips slots overlapping existing ones', () {
    final existing = [
      Slot(
        id: 'x',
        serviceId: 's',
        startTime: DateTime(2030, 1, 7, 7, 30),
        endTime: DateTime(2030, 1, 7, 8, 30),
        isBooked: true,
      ),
    ];
    final slots = generateSlots(plan(), existing: existing, now: beforeEverything);
    expect(slots.map((s) => s.start.hour), [6, 9]);
  });

  test('touching an existing slot is not an overlap', () {
    final existing = [
      Slot(
        id: 'x',
        serviceId: 's',
        startTime: DateTime(2030, 1, 7, 10),
        endTime: DateTime(2030, 1, 7, 11),
        isBooked: false,
      ),
    ];
    expect(generateSlots(plan(), existing: existing, now: beforeEverything).length, 4);
  });

  test('returns nothing for invalid plans', () {
    expect(generateSlots(plan(open: 600, close: 600), now: beforeEverything), isEmpty);
    expect(generateSlots(plan(length: 0), now: beforeEverything), isEmpty);
  });

  test('insert JSON is UTC', () {
    final range = SlotRange(DateTime(2030, 1, 7, 6), DateTime(2030, 1, 7, 7));
    final json = range.toInsertJson('svc');
    expect(json['service_id'], 'svc');
    expect((json['start_time'] as String).endsWith('Z'), isTrue);
    expect(DateTime.parse(json['start_time'] as String).toLocal(), range.start);
  });
}
