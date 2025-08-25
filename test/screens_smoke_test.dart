import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:turfapp/screens/shared/splash_screen.dart';
import 'package:turfapp/screens/auth/onboarding_screen.dart';
import 'package:turfapp/screens/auth/signup_screen.dart';
import 'package:turfapp/screens/customer/home_screen.dart';
import 'package:turfapp/screens/customer/service_detail_screen.dart';
import 'package:turfapp/screens/customer/booking_screen.dart';
import 'package:turfapp/screens/customer/my_bookings_screen.dart';
import 'package:turfapp/screens/customer/review_screen.dart';
import 'package:turfapp/screens/vendor/dashboard_screen.dart';
import 'package:turfapp/screens/vendor/manage_services_screen.dart';
import 'package:turfapp/screens/vendor/manage_slots_screen.dart';
import 'package:turfapp/screens/vendor/booking_requests_screen.dart';
import 'package:turfapp/screens/vendor/booking_history_screen.dart';
import 'package:turfapp/screens/shared/profile_screen.dart';

import 'package:turfapp/services/auth_service.dart';
import 'package:turfapp/services/vendor_service.dart';
import 'package:turfapp/services/booking_service.dart';
import 'package:turfapp/models/service.dart';
import 'package:turfapp/models/slot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthService implements AuthService {
  bool signOutCalled = false;
  String? capturedEmail;
  String? capturedPassword;

  @override
  Future<void> signIn(String email, String password) async {
    capturedEmail = email;
    capturedPassword = password;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<void> signUp(String email, String password) async {
    capturedEmail = email;
    capturedPassword = password;
  }

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  User? get currentUser => null; // Not logged in by default
}

void main() {
  final sampleService = Service(
    id: '1',
    vendorId: 'v1',
    name: 'Service A',
    description: 'Desc',
    category: 'Cat',
    location: 'Loc',
  );

  final sampleSlots = <Slot>[
    Slot(
      id: 'slot1',
      serviceId: '1',
      startTime: DateTime(2025, 1, 1, 10),
      endTime: DateTime(2025, 1, 1, 11),
      isBooked: false,
    ),
  ];

  group('Splash and onboarding', () {
    testWidgets('SplashScreen renders progress indicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
            authServiceProvider.overrideWithValue(_FakeAuthService()),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      // Allow the delayed timer in SplashScreen to complete to avoid pending timer assertion
      await tester.pump(const Duration(seconds: 11));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OnboardingScreen shows Login and Sign Up', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });
  });

  group('Auth screens', () {
    testWidgets('SignupScreen calls signUp', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(fakeAuth)],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).last, 'secret123');
      // The dialog has "Cancel" and "Add", but here we just want to invoke the signUp method.
      // There are two Text widgets with "Sign Up" (AppBar and button), so tap the ElevatedButton explicitly.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();

      expect(fakeAuth.capturedEmail, 'user@example.com');
      expect(fakeAuth.capturedPassword, 'secret123');
    });

    testWidgets('ProfileScreen taps Logout and calls signOut', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(fakeAuth)],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.tap(find.text('Logout'));
      await tester.pump();

      expect(fakeAuth.signOutCalled, isTrue);
    });
  });

  group('Customer flow screens', () {
    testWidgets('HomeScreen renders services list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allServicesProvider.overrideWith((ref) async => [
                  sampleService,
                  sampleService.copyWith(id: '2', name: 'Service B'),
                ]),
          ],
          child: const MaterialApp(home: CustomerHomeScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Service A'), findsOneWidget);
      expect(find.text('Service B'), findsOneWidget);
    });

    testWidgets('ServiceDetailScreen shows details and slots', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceProvider.overrideWith((ref, id) async => sampleService),
            slotsProvider.overrideWith((ref, serviceId) async => sampleSlots),
          ],
          child: const MaterialApp(
            home: ServiceDetailScreen(serviceId: '1'),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Service Details'), findsOneWidget);
      expect(find.text('Service A'), findsOneWidget);
      expect(find.text('Available Slots:'), findsOneWidget);
    });

    testWidgets('BookingScreen disables confirm when not logged in', (tester) async {
      final router = GoRouter(
        initialLocation: '/book/1?slotId=slot1',
        routes: [
          GoRoute(
            path: '/book/:id',
            builder: (context, state) => BookingScreen(serviceId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_FakeAuthService()),
            serviceProvider.overrideWith((ref, id) async => sampleService),
            slotProvider.overrideWith((ref, slotId) async => sampleSlots.first),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();
      final confirmFinder = find.widgetWithText(ElevatedButton, 'Confirm Booking');
      final ElevatedButton button = tester.widget(confirmFinder);
      expect(button.onPressed, isNull); // disabled when user is null
    });

    testWidgets('MyBookingsScreen asks to log in when user is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(_FakeAuthService())],
          child: const MaterialApp(home: MyBookingsScreen()),
        ),
      );

      expect(find.text('Please log in to view your bookings.'), findsOneWidget);
    });
  });

  group('Vendor screens', () {
    testWidgets('VendorDashboardScreen loads', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VendorDashboardScreen()));
      expect(find.text('Vendor Dashboard'), findsOneWidget);
    });

    testWidgets('ManageServicesScreen asks vendor login when user null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(_FakeAuthService())],
          child: const MaterialApp(home: ManageServicesScreen()),
        ),
      );
      expect(find.text('Please log in as a vendor.'), findsOneWidget);
    });

    testWidgets('ManageSlotsScreen shows empty text when no slots', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceSlotsProvider.overrideWith((ref, serviceId) async => []),
          ],
          child: const MaterialApp(home: ManageSlotsScreen(serviceId: '1')),
        ),
      );

      await tester.pump();
      expect(find.text('No slots found.'), findsOneWidget);
    });

    testWidgets('BookingRequestsScreen loads', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BookingRequestsScreen()));
      expect(find.text('Booking Requests'), findsOneWidget);
    });

    testWidgets('BookingHistoryScreen loads', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BookingHistoryScreen()));
      expect(find.text('Booking History'), findsOneWidget);
    });
  });

  group('Misc screens', () {
    testWidgets('ReviewScreen loads with booking id text', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ReviewScreen(bookingId: 'b1')));
      expect(find.textContaining('booking b1'), findsOneWidget);
    });
  });
}
