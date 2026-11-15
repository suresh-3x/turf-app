import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/app_user.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/customer/booking_screen.dart';
import 'screens/customer/customer_shell.dart';
import 'screens/customer/home_screen.dart';
import 'screens/customer/my_bookings_screen.dart';
import 'screens/customer/review_screen.dart';
import 'screens/customer/service_detail_screen.dart';
import 'screens/shared/notifications_screen.dart';
import 'screens/shared/profile_screen.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/vendor/booking_history_screen.dart';
import 'screens/vendor/booking_requests_screen.dart';
import 'screens/vendor/dashboard_screen.dart';
import 'screens/vendor/manage_services_screen.dart';
import 'screens/vendor/manage_slots_screen.dart';
import 'screens/vendor/service_form_screen.dart';
import 'screens/vendor/vendor_shell.dart';
import 'services/auth_service.dart';

final _rootKey = GlobalKey<NavigatorState>();

const _publicPaths = {'/onboarding', '/login', '/signup'};
const _customerPrefixes = ['/home', '/bookings', '/profile', '/review'];
const _vendorPrefixes = ['/dashboard', '/requests', '/my-services', '/account', '/history'];

bool _under(String location, List<String> prefixes) =>
    prefixes.any((p) => location == p || location.startsWith('$p/'));

/// Where a signed-in user of [role] lands.
String homeFor(UserRole role) => role == UserRole.vendor ? '/dashboard' : '/home';

/// Decides where to send the user given who they are. Pure so it can be tested.
String? resolveRedirect({
  required String location,
  required bool signedIn,
  required AsyncValue<AppUser?> profile,
}) {
  final isPublic = _publicPaths.contains(location);
  if (!signedIn) return isPublic ? null : '/onboarding';

  // Signed in, but profile not loaded yet (or failed): wait on the splash.
  final user = profile.valueOrNull;
  if (user == null) return location == '/' ? null : '/';

  final home = homeFor(user.role);
  if (isPublic || location == '/') return home;
  if (user.isVendor && _under(location, _customerPrefixes)) return home;
  if (!user.isVendor && _under(location, _vendorPrefixes)) return home;
  return null;
}

/// Re-runs the router's redirect when auth or the profile changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(currentUserIdProvider, (_, __) => notifyListeners());
    ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      location: state.matchedLocation,
      signedIn: ref.read(currentUserIdProvider) != null,
      profile: ref.read(currentProfileProvider),
    ),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationsScreen(),
      ),

      // ---------------- Customer ----------------
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => CustomerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const CustomerHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'service/:id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => ServiceDetailScreen(serviceId: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'book/:slotId',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) => BookingScreen(
                          serviceId: s.pathParameters['id']!,
                          slotId: s.pathParameters['slotId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/bookings', builder: (_, __) => const MyBookingsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/review/:bookingId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ReviewScreen(bookingId: s.pathParameters['bookingId']!),
      ),

      // ---------------- Vendor ----------------
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => VendorShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/dashboard', builder: (_, __) => const VendorDashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/requests', builder: (_, __) => const BookingRequestsScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-services',
                builder: (_, __) => const ManageServicesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, __) => const ServiceFormScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => ServiceFormScreen(serviceId: s.pathParameters['id']),
                  ),
                  GoRoute(
                    path: ':id/slots',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => ManageSlotsScreen(serviceId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/account', builder: (_, __) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/history',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BookingHistoryScreen(),
      ),
    ],
  );
});
