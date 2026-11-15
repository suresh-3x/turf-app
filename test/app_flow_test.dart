import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turfapp/app.dart';
import 'package:turfapp/models/app_notification.dart';
import 'package:turfapp/models/booking.dart';
import 'package:turfapp/models/slot.dart';
import 'package:turfapp/widgets/slot_calendar.dart';

import 'fakes.dart';

Future<void> pumpApp(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(420 * 2, 900 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const TurfApp()));
  await tester.pumpAndSettle();
}

void main() {
  group('signed out', () {
    testWidgets('starts on onboarding and can reach login', (tester) async {
      await pumpApp(tester, fakeOverrides());
      expect(find.text('Create an account'), findsOneWidget);

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('login validates input and shows server errors', (tester) async {
      final auth = FakeAuthService()..failWith = 'Invalid login credentials';
      await pumpApp(tester, fakeOverrides(auth: auth));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(auth.signIns, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asha@x.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();
      expect(auth.signIns, ['asha@x.com']);
      expect(find.text('Invalid login credentials'), findsOneWidget);
    });

    testWidgets('sign up offers both account types', (tester) async {
      await pumpApp(tester, fakeOverrides());
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Your name'), findsOneWidget);
      await tester.tap(find.text('List my venue'));
      await tester.pumpAndSettle();
      expect(find.text('Business name'), findsOneWidget);
    });
  });

  group('customer', () {
    testWidgets('browses, filters and books a slot', (tester) async {
      final bookings = FakeBookingService();
      await pumpApp(tester, fakeOverrides(user: customer, bookings: bookings));

      // Home
      expect(find.text('Hi, Asha'), findsOneWidget);
      expect(find.text('Court A'), findsOneWidget);
      expect(find.text('Pixel Arena'), findsOneWidget);

      // Search
      await tester.enterText(find.byType(SearchBar), 'indira');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Court A'), findsNothing);
      expect(find.text('Pixel Arena'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Category filter
      await tester.tap(find.widgetWithText(FilterChip, 'Football turf'));
      await tester.pumpAndSettle();
      expect(find.text('Pixel Arena'), findsNothing);

      // Detail
      await tester.tap(find.text('Court A'));
      await tester.pumpAndSettle();
      expect(find.text('5-a-side astro turf'), findsOneWidget);
      expect(find.text('Great surface'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pick a slot'), findsOneWidget);

      // The booked slot cannot be chosen; the free one can.
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.length, 2);
      expect(chips[0].onSelected, isNull);
      await tester.tap(find.byKey(const ValueKey('sl2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Book 7:00 PM'), findsOneWidget);

      // Confirm
      await tester.tap(find.textContaining('Book 7:00 PM'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm booking'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '8 players');
      await tester.tap(find.text('Request booking'));
      await tester.pumpAndSettle();
      expect(bookings.booked, ['sl2']);
      expect(find.text('Booking requested'), findsOneWidget);

      await tester.tap(find.text('View my bookings'));
      await tester.pumpAndSettle();
      expect(find.text('My bookings'), findsOneWidget);
      expect(find.text('Awaiting confirmation'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows unread notification count', (tester) async {
      await pumpApp(
        tester,
        fakeOverrides(
          user: customer,
          notifications: [
            AppNotification(
              id: 'n1',
              title: 'Booking confirmed',
              body: 'Your booking was confirmed.',
              isRead: false,
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Your booking was confirmed.'), findsOneWidget);
    });
  });

  group('vendor', () {
    testWidgets('sees dashboard and accepts a request', (tester) async {
      final bookings = FakeBookingService()
        ..vendorBookings = [
          Booking(
            id: 'b1',
            customerId: 'c1',
            serviceId: 's1',
            slotId: 'sl1',
            status: BookingStatus.pending,
            createdAt: DateTime.now(),
            service: courtA,
            slot: slots[0],
            customer: customer,
            notes: 'Bring bibs',
          ),
        ];
      await pumpApp(tester, fakeOverrides(user: vendor, bookings: bookings));

      expect(find.text('Green Turf'), findsOneWidget);
      expect(find.text('Awaiting reply'), findsOneWidget);
      expect(find.text('Earned this month'), findsOneWidget);

      await tester.tap(find.text('Bookings').last);
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Bring bibs'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(bookings.statusChanges, ['b1:confirmed']);
    });

    testWidgets('lists own services', (tester) async {
      await pumpApp(tester, fakeOverrides(user: vendor));
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();
      expect(find.text('My services'), findsOneWidget);
      expect(find.text('Court A'), findsOneWidget);
      expect(find.text('Add service'), findsOneWidget);
    });

    testWidgets('customer routes redirect vendors to the dashboard', (tester) async {
      await pumpApp(tester, fakeOverrides(user: vendor));
      expect(find.text('Awaiting reply'), findsOneWidget);
      expect(find.text('Explore'), findsNothing);
    });
  });

  testWidgets('SlotCalendar switches days', (tester) async {
    final day2 = tomorrow.add(const Duration(days: 1));
    final list = [
      Slot(id: 'a', serviceId: 's', startTime: at(9), endTime: at(10), isBooked: false),
      Slot(
        id: 'b',
        serviceId: 's',
        startTime: DateTime(day2.year, day2.month, day2.day, 17),
        endTime: DateTime(day2.year, day2.month, day2.day, 18),
        isBooked: false,
      ),
    ];
    Slot? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotCalendar(slots: list, onSlotSelected: (s) => picked = s),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('a')), findsOneWidget);
    expect(find.byKey(const ValueKey('b')), findsNothing);

    await tester.tap(find.text('${day2.day}'));
    await tester.pump();
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('b')));
    expect(picked?.id, 'b');
  });
}
