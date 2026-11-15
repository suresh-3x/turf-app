import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turfapp/models/app_user.dart';
import 'package:turfapp/router.dart';

void main() {
  const customer = AppUser(id: 'c', name: 'C', email: 'c@x.com', role: UserRole.customer);
  const vendor = AppUser(id: 'v', name: 'V', email: 'v@x.com', role: UserRole.vendor);

  String? go(String location, {bool signedIn = true, AsyncValue<AppUser?>? profile}) =>
      resolveRedirect(
        location: location,
        signedIn: signedIn,
        profile: profile ?? const AsyncData(null),
      );

  group('signed out', () {
    test('can use public screens', () {
      for (final p in ['/onboarding', '/login', '/signup']) {
        expect(go(p, signedIn: false), isNull, reason: p);
      }
    });
    test('is sent to onboarding from anywhere else', () {
      for (final p in ['/', '/home', '/dashboard', '/home/service/1']) {
        expect(go(p, signedIn: false), '/onboarding', reason: p);
      }
    });
  });

  test('waits on splash while the profile loads', () {
    expect(go('/login', profile: const AsyncLoading()), '/');
    expect(go('/', profile: const AsyncLoading()), isNull);
  });

  test('stays on splash if the profile failed to load', () {
    expect(go('/home', profile: AsyncError('x', StackTrace.empty)), '/');
  });

  group('customer', () {
    final p = const AsyncData<AppUser?>(customer);
    test('lands on home', () {
      expect(go('/', profile: p), '/home');
      expect(go('/login', profile: p), '/home');
    });
    test('can use customer screens', () {
      expect(go('/home/service/abc/book/def', profile: p), isNull);
      expect(go('/bookings', profile: p), isNull);
      expect(go('/notifications', profile: p), isNull);
    });
    test('is kept out of vendor screens', () {
      expect(go('/dashboard', profile: p), '/home');
      expect(go('/my-services/1/slots', profile: p), '/home');
      expect(go('/history', profile: p), '/home');
    });
  });

  group('vendor', () {
    final p = const AsyncData<AppUser?>(vendor);
    test('lands on the dashboard', () {
      expect(go('/', profile: p), '/dashboard');
      expect(go('/signup', profile: p), '/dashboard');
    });
    test('can use vendor screens', () {
      expect(go('/my-services/new', profile: p), isNull);
      expect(go('/requests', profile: p), isNull);
    });
    test('is kept out of customer screens', () {
      expect(go('/home', profile: p), '/dashboard');
      expect(go('/review/1', profile: p), '/dashboard');
    });
  });

  test('prefix matching does not over-match', () {
    // "/homework" is not under "/home".
    expect(go('/homework', profile: const AsyncData(vendor)), isNull);
  });
}
