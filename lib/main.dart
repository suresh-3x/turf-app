import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import screens
import 'screens/shared/splash_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/customer/home_screen.dart';
import 'screens/customer/service_detail_screen.dart';
import 'screens/customer/booking_screen.dart';
import 'screens/customer/my_bookings_screen.dart';
import 'screens/customer/review_screen.dart';
import 'screens/vendor/dashboard_screen.dart';
import 'screens/vendor/manage_services_screen.dart';
import 'screens/vendor/manage_slots_screen.dart';
import 'screens/vendor/booking_requests_screen.dart';
import 'screens/vendor/booking_history_screen.dart';
import 'screens/shared/profile_screen.dart';

import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Checking Supabase credentials...');
  print('supabaseUrl: $supabaseUrl');
  print('supabaseAnonKey: ${supabaseAnonKey.substring(0, 8)}...');

  try {
    final res = await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    print('Supabase initialized: $res');
  } catch (e, st) {
    print('ERROR: Supabase initialization failed: $e');
    print(st);
  }

  runApp(const ProviderScope(child: TurfApp()));
}

class TurfApp extends ConsumerWidget {
  const TurfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        
        // Customer routes
        GoRoute(path: '/home', builder: (context, state) => const CustomerHomeScreen()),
        GoRoute(path: '/service/:id', builder: (context, state) => ServiceDetailScreen(serviceId: state.pathParameters['id']!)),
        GoRoute(path: '/book/:id', builder: (context, state) => BookingScreen(serviceId: state.pathParameters['id']!)),
        GoRoute(path: '/my-bookings', builder: (context, state) => const MyBookingsScreen()),
        GoRoute(path: '/review/:id', builder: (context, state) => ReviewScreen(bookingId: state.pathParameters['id']!)),

        // Vendor routes
        GoRoute(path: '/vendor/dashboard', builder: (context, state) => const VendorDashboardScreen()),
        GoRoute(path: '/vendor/services', builder: (context, state) => const ManageServicesScreen()),
        GoRoute(path: '/vendor/services/:id/slots', builder: (context, state) => ManageSlotsScreen(serviceId: state.pathParameters['id']!)),
        GoRoute(path: '/vendor/requests', builder: (context, state) => const BookingRequestsScreen()),
        GoRoute(path: '/vendor/history', builder: (context, state) => const BookingHistoryScreen()),
      ],
      // TODO: Add error handling and redirection logic
    );

    return MaterialApp.router(
      title: 'TurfApp',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
