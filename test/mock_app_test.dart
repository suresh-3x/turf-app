import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turfapp/app.dart';
import 'package:turfapp/services/mock/mock_database.dart';
import 'package:turfapp/services/mock/mock_services.dart';

/// Runs the real app against the demo database.
Future<MockDatabase> pumpDemo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420 * 2, 900 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final db = MockDatabase.seeded()..latency = Duration.zero;
  await tester.pumpWidget(
    ProviderScope(overrides: mockBackendOverrides(db), child: const TurfApp()),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('demo customer logs in with one tap and books a slot', (tester) async {
    final db = await pumpDemo(tester);
    await tapText(tester, 'I already have an account');
    expect(find.text('Demo mode'), findsOneWidget);
    await tapText(tester, 'Customer');

    expect(find.text('Hi, Asha'), findsOneWidget);
    expect(find.text('Green Field Turf – 5-a-side'), findsOneWidget);

    await tapText(tester, 'Green Field Turf – 5-a-side');
    expect(find.text('Great surface and lights. Will book again!'), findsOneWidget);

    // Pick the first selectable slot on the calendar.
    final chip = find.byWidgetPredicate((w) => w is ChoiceChip && w.onSelected != null).first;
    await tester.scrollUntilVisible(
      chip,
      150,
      scrollable: find
          .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .first,
    );
    await Scrollable.ensureVisible(tester.element(chip), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^Book ')));
    await tester.pumpAndSettle();
    final before = db.bookings.length;
    await tapText(tester, 'Request booking');
    expect(find.text('Booking requested'), findsOneWidget);
    expect(db.bookings.length, before + 1);
    await tapText(tester, 'View my bookings');
    expect(find.text('My bookings'), findsOneWidget);
  });

  testWidgets('new user signs up as a venue owner and adds a service', (tester) async {
    final db = await pumpDemo(tester);
    await tapText(tester, 'Create an account');
    await tapText(tester, 'List my venue');
    await tester.enterText(find.widgetWithText(TextFormField, 'Business name'), 'Ace Courts');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ace@courts.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret12');
    await tapText(tester, 'Create account');

    // Signed straight in, on the vendor dashboard with the first-service prompt.
    expect(find.text('Ace Courts'), findsOneWidget);
    expect(find.text('Add your first service'), findsOneWidget);
    expect(db.users.any((u) => u['email'] == 'ace@courts.com' && u['role'] == 'vendor'), isTrue);

    await tapText(tester, 'Add your first service');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Ace Court 1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Jayanagar');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price per slot'), '500');
    await tapText(tester, 'Add service');

    // Lands on the slots screen for the new service.
    expect(find.text('Ace Court 1'), findsOneWidget);
    expect(find.text('Add slots'), findsOneWidget);
    expect(db.services.any((s) => s['name'] == 'Ace Court 1'), isTrue);

    await tapText(tester, 'Add slots');
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    final add = find.textContaining(RegExp(r'^Add \d+ slots$'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(
      db.slots.where((s) => db.serviceById(s['service_id'] as String)?['name'] == 'Ace Court 1'),
      isNotEmpty,
    );
  });

  testWidgets('demo vendor accepts a request; customer is notified', (tester) async {
    final db = await pumpDemo(tester);
    await tapText(tester, 'I already have an account');
    await tapText(tester, 'Venue owner');
    expect(find.text('Green Field Sports'), findsOneWidget);

    await tapText(tester, 'Bookings');
    expect(find.text('Office team, 10 players'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pumpAndSettle();
    expect(
      db.notifications.any(
        (n) => n['user_id'] == 'u-customer-2' && n['title'] == 'Booking confirmed',
      ),
      isTrue,
    );
  });
}
