import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;
import 'package:turfapp/models/app_user.dart';
import 'package:turfapp/models/booking.dart';
import 'package:turfapp/models/service.dart';
import 'package:turfapp/models/slot.dart';
import 'package:turfapp/services/mock/mock_database.dart';
import 'package:turfapp/services/mock/mock_services.dart';

void main() {
  late MockDatabase db;
  late MockAuthService auth;
  late MockCatalogService catalog;
  late MockBookingService bookings;
  late MockNotificationService notifications;

  setUp(() {
    db = MockDatabase.seeded()..latency = Duration.zero;
    auth = MockAuthService(db);
    catalog = MockCatalogService(db);
    bookings = MockBookingService(db);
    notifications = MockNotificationService(db);
  });

  Future<Slot> freeSlot(String serviceId) async =>
      (await catalog.fetchUpcomingSlots(serviceId)).firstWhere((s) => s.isAvailable);

  Matcher pgError(String code) => isA<PostgrestException>().having((e) => e.code, 'code', code);

  group('seed data', () {
    test('has venues, future slots and demo accounts', () async {
      await auth.signIn('customer@demo.com', 'demo123');
      final services = await catalog.fetchActiveServices();
      expect(services.length, 5);
      for (final s in services) {
        expect(
          (await catalog.fetchUpcomingSlots(s.id)).where((x) => x.isAvailable),
          isNotEmpty,
          reason: s.name,
        );
      }
      expect(services.firstWhere((s) => s.id == 'svc-turf-5').reviewCount, 1);
    });

    test('no service has overlapping slots and booked flags match bookings', () {
      for (final s in db.services) {
        final list = db.slots.where((x) => x['service_id'] == s['id']).map(Slot.fromJson).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        for (var i = 1; i < list.length; i++) {
          expect(
            list[i].startTime.isBefore(list[i - 1].endTime),
            isFalse,
            reason: s['name'] as String,
          );
        }
      }
      for (final slot in db.slots) {
        final active = db.bookings.any(
          (b) =>
              b['slot_id'] == slot['id'] &&
              ['pending', 'confirmed', 'completed'].contains(b['status']),
        );
        expect(slot['is_booked'], active, reason: slot['id'] as String);
      }
    });

    test('demo customer has something to review and vendor a request to answer', () async {
      await auth.signIn('customer@demo.com', 'demo123');
      final mine = await bookings.fetchCustomerBookings('u-customer-1');
      expect(mine.where((b) => b.canReview), isNotEmpty);
      expect(mine.where((b) => b.isUpcoming), isNotEmpty);

      await auth.signIn('vendor@demo.com', 'demo123');
      final requests = await bookings.fetchVendorBookings('u-vendor-1');
      expect(requests.where((b) => b.status == BookingStatus.pending && !b.hasStarted), isNotEmpty);
    });
  });

  group('auth', () {
    test('wrong password is rejected', () {
      expect(auth.signIn('customer@demo.com', 'nope'), throwsA(isA<AuthException>()));
    });

    test('sign up creates a profile and signs in', () async {
      final events = <String?>[];
      final sub = auth.userIdChanges.listen(events.add);
      final result = await auth.signUp(
        name: 'New Owner',
        email: 'New@Venue.com',
        password: 'secret1',
        role: UserRole.vendor,
      );
      expect(result.needsEmailConfirmation, isFalse);
      final id = auth.currentUserId!;
      final profile = await auth.fetchProfile(id);
      expect(profile!.role, UserRole.vendor);
      expect(profile.email, 'new@venue.com');
      await Future<void>.delayed(Duration.zero);
      expect(events, [id]);
      await sub.cancel();
    });

    test('duplicate email is rejected', () {
      expect(
        auth.signUp(
          name: 'x',
          email: 'customer@demo.com',
          password: 'secret1',
          role: UserRole.customer,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('profile never exposes passwords', () async {
      await auth.signIn('customer@demo.com', 'demo123');
      final s = await catalog.fetchService('svc-turf-5');
      expect(s.vendor!.name, 'Green Field Sports');
      expect(db.publicUser('u-vendor-1')!.containsKey('password'), isFalse);
    });
  });

  group('booking rules', () {
    test('book, double-book, cancel, rebook', () async {
      await auth.signIn('customer@demo.com', 'demo123');
      final slot = await freeSlot('svc-turf-5');
      final id = await bookings.bookSlot(slot.id, notes: '  bring bibs ');
      expect((await bookings.fetchBooking(id)).notes, 'bring bibs');
      expect((await catalog.fetchSlot(slot.id)).isBooked, isTrue);

      await auth.signIn('ravi@demo.com', 'demo123');
      await expectLater(bookings.bookSlot(slot.id), throwsA(pgError('P0001')));

      await auth.signIn('customer@demo.com', 'demo123');
      await bookings.cancel(id);
      expect((await catalog.fetchSlot(slot.id)).isBooked, isFalse);

      await auth.signIn('ravi@demo.com', 'demo123');
      await bookings.bookSlot(slot.id);
    });

    test('vendors cannot book and customers cannot manage services', () async {
      await auth.signIn('vendor@demo.com', 'demo123');
      await expectLater(
        bookings.bookSlot((await freeSlot('svc-gaming')).id),
        throwsA(pgError('P0001')),
      );

      await auth.signIn('customer@demo.com', 'demo123');
      await expectLater(
        catalog.createService(
          const Service(
            id: '',
            vendorId: 'u-customer-1',
            name: 'x',
            description: '',
            category: 'Other',
            location: 'x',
            pricePerSlot: 0,
          ),
        ),
        throwsA(pgError('42501')),
      );
      await expectLater(catalog.setServiceActive('svc-turf-5', false), throwsA(pgError('42501')));
    });

    test('status transitions, notifications and reviews', () async {
      await auth.signIn('customer@demo.com', 'demo123');
      final id = await bookings.bookSlot((await freeSlot('svc-badminton')).id);

      // Customer cannot confirm their own booking.
      await expectLater(
        bookings.updateStatus(id, BookingStatus.confirmed),
        throwsA(pgError('P0001')),
      );

      // Another vendor cannot touch it.
      await auth.signIn('owner2@demo.com', 'demo123');
      await expectLater(
        bookings.updateStatus(id, BookingStatus.confirmed),
        throwsA(pgError('P0001')),
      );

      await auth.signIn('vendor@demo.com', 'demo123');
      final vendorInbox = await notifications.watch('u-vendor-1').first;
      expect(vendorInbox.first.title, 'New booking request');
      await bookings.updateStatus(id, BookingStatus.confirmed);
      // Not started yet, so completing is allowed by the rules (UI hides it).
      await bookings.updateStatus(id, BookingStatus.completed);

      await auth.signIn('customer@demo.com', 'demo123');
      final inbox = await notifications.watch('u-customer-1').first;
      expect(inbox.map((n) => n.title), containsAll(['Booking confirmed', 'Booking completed']));

      await catalog.submitReview(bookingId: id, rating: 5, comment: 'Lovely');
      await expectLater(
        catalog.submitReview(bookingId: id, rating: 4, comment: ''),
        throwsA(pgError('23505')),
      );
      final reviews = await catalog.fetchReviews('svc-badminton');
      expect(reviews.first.customerName, 'Asha Rao');
      expect((await bookings.fetchBooking(id)).hasReview, isTrue);
    });

    test('customers only see their own bookings', () async {
      await auth.signIn('ravi@demo.com', 'demo123');
      expect(await bookings.fetchCustomerBookings('u-customer-1'), isEmpty);
      final ashaBooking = db.bookings.firstWhere((b) => b['customer_id'] == 'u-customer-1');
      await expectLater(
        bookings.fetchBooking(ashaBooking['id'] as String),
        throwsA(pgError('PGRST116')),
      );
    });
  });

  group('slots', () {
    test('overlapping slots are rejected; booked slots cannot be deleted', () async {
      await auth.signIn('vendor@demo.com', 'demo123');
      final existing = await freeSlot('svc-turf-5');
      await expectLater(
        catalog.createSlots('svc-turf-5', [
          SlotRange(
            existing.startTime.add(const Duration(minutes: 30)),
            existing.endTime.add(const Duration(minutes: 30)),
          ),
        ]),
        throwsA(pgError('23P01')),
      );

      final booked = db.slots.firstWhere(
        (s) => s['is_booked'] == true && s['service_id'] == 'svc-turf-5',
      );
      await catalog.deleteSlot(booked['id'] as String);
      expect(db.slotById(booked['id'] as String), isNotNull);

      await catalog.deleteSlot(existing.id);
      expect(db.slotById(existing.id), isNull);
    });
  });

  test('saves and restores through JSON', () async {
    await auth.signIn('customer@demo.com', 'demo123');
    String? saved;
    db.onChanged = (json) => saved = json;
    final id = await bookings.bookSlot((await freeSlot('svc-cricket')).id);

    final restored = MockDatabase.fromJsonString(saved)!..latency = Duration.zero;
    expect(restored.sessionUserId, 'u-customer-1');
    final b = await MockBookingService(restored).fetchBooking(id);
    expect(b.status, BookingStatus.pending);
    expect(MockDatabase.fromJsonString('not json'), isNull);
  });

  test('reset restores the seed and signs out', () async {
    await auth.signIn('customer@demo.com', 'demo123');
    db.services.clear();
    db.resetToSeed();
    expect(db.services.length, 5);
    expect(auth.currentUserId, isNull);
  });
}
