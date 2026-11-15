import 'package:flutter_test/flutter_test.dart';
import 'package:turfapp/models/app_user.dart';
import 'package:turfapp/models/booking.dart';
import 'package:turfapp/models/service.dart';
import 'package:turfapp/screens/vendor/dashboard_screen.dart';

Map<String, dynamic> bookingJson({
  String status = 'pending',
  required DateTime start,
  double price = 1000,
  bool reviewed = false,
}) => {
  'id': 'b-$status-${start.millisecondsSinceEpoch}',
  'customer_id': 'c',
  'service_id': 's',
  'slot_id': 'sl',
  'status': status,
  'booking_time': '2030-01-01T00:00:00Z',
  'notes': null,
  'service': {
    'id': 's',
    'vendor_id': 'v',
    'name': 'Court A',
    'category': 'Football turf',
    'location': 'Koramangala',
    'price_per_slot': price,
    'is_active': true,
  },
  'slot': {
    'id': 'sl',
    'service_id': 's',
    'start_time': start.toUtc().toIso8601String(),
    'end_time': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
    'is_booked': true,
  },
  'customer': {'id': 'c', 'name': 'Asha', 'email': 'a@x.com', 'role': 'customer'},
  'reviews': reviewed
      ? [
          {'id': 'r'},
        ]
      : [],
};

void main() {
  group('Booking.fromJson', () {
    test('parses embedded rows and converts times to local', () {
      final start = DateTime.now().add(const Duration(days: 1));
      final b = Booking.fromJson(bookingJson(start: start));
      expect(b.status, BookingStatus.pending);
      expect(b.service!.name, 'Court A');
      expect(b.service!.pricePerSlot, 1000);
      expect(b.customer!.name, 'Asha');
      expect(b.slot!.startTime.isUtc, isFalse);
      expect(b.slot!.startTime.difference(start).inSeconds.abs(), lessThan(1));
      expect(b.isUpcoming, isTrue);
      expect(b.canCustomerCancel, isTrue);
      expect(b.canReview, isFalse);
    });

    test('completed booking can be reviewed once', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(Booking.fromJson(bookingJson(status: 'completed', start: past)).canReview, isTrue);
      expect(
        Booking.fromJson(bookingJson(status: 'completed', start: past, reviewed: true)).canReview,
        isFalse,
      );
    });

    test('started bookings cannot be cancelled', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final b = Booking.fromJson(bookingJson(status: 'confirmed', start: past));
      expect(b.canCustomerCancel, isFalse);
      expect(b.isUpcoming, isFalse);
    });

    test('unknown status falls back to pending', () {
      expect(BookingStatus.fromString('weird'), BookingStatus.pending);
    });
  });

  test('Service.fromJson tolerates missing optional fields', () {
    final s = Service.fromJson({'id': '1', 'vendor_id': 'v', 'name': 'X'});
    expect(s.pricePerSlot, 0);
    expect(s.isActive, isTrue);
    expect(s.vendor, isNull);
    expect(s.toWriteJson()['vendor_id'], 'v');
  });

  test('AppUser role parsing', () {
    expect(UserRole.fromString('vendor'), UserRole.vendor);
    expect(UserRole.fromString(null), UserRole.customer);
  });

  test('DashboardStats', () {
    final now = DateTime(2030, 3, 15, 12);
    final list = [
      // pending later today
      Booking.fromJson(bookingJson(start: DateTime(2030, 3, 15, 18))),
      // confirmed tomorrow
      Booking.fromJson(bookingJson(status: 'confirmed', start: DateTime(2030, 3, 16, 9))),
      // completed earlier this month, 1000 + 1500
      Booking.fromJson(bookingJson(status: 'completed', start: DateTime(2030, 3, 2, 9))),
      Booking.fromJson(
        bookingJson(status: 'completed', start: DateTime(2030, 3, 3, 9), price: 1500),
      ),
      // completed last month — not counted
      Booking.fromJson(bookingJson(status: 'completed', start: DateTime(2030, 2, 20, 9))),
      // cancelled today — not on schedule
      Booking.fromJson(bookingJson(status: 'cancelled', start: DateTime(2030, 3, 15, 20))),
    ];
    final stats = DashboardStats.from(list, now: now);
    expect(stats.pending, 1);
    expect(stats.upcoming, 2);
    expect(stats.today.length, 1);
    expect(stats.completedThisMonth, 2);
    expect(stats.earningsThisMonth, 2500);
  });
}
