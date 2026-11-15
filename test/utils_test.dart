import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turfapp/utils/formatters.dart';
import 'package:turfapp/utils/helpers.dart';
import 'package:turfapp/utils/validators.dart';

void main() {
  test('validators', () {
    expect(validateEmail('a@b.co'), isNull);
    expect(validateEmail('nope'), isNotNull);
    expect(validateEmail(''), isNotNull);
    expect(validatePassword('12345'), isNotNull);
    expect(validatePassword('123456'), isNull);
    expect(validatePhone(''), isNull);
    expect(validatePhone('+91 98765 43210'), isNull);
    expect(validatePhone('abc'), isNotNull);
    expect(validatePrice('0'), isNull);
    expect(validatePrice('-1'), isNotNull);
    expect(validatePrice('x'), isNotNull);
  });

  test('formatters', () {
    expect(formatPrice(0), 'Free');
    expect(formatPrice(1200), contains('1,200'));
    expect(formatDuration(const Duration(minutes: 90)), '1 hr 30 min');
    expect(formatDuration(const Duration(hours: 2)), '2 hrs');
    expect(formatDuration(const Duration(minutes: 45)), '45 min');
    final now = DateTime(2030, 1, 10, 12);
    expect(formatRelative(now.subtract(const Duration(seconds: 10)), now: now), 'just now');
    expect(formatRelative(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
  });

  test('friendlyError uses database messages and maps codes', () {
    expect(
      friendlyError(
        const PostgrestException(
          message: 'Sorry, this slot has just been booked by someone else.',
          code: 'P0001',
        ),
      ),
      'Sorry, this slot has just been booked by someone else.',
    );
    expect(
      friendlyError(const PostgrestException(message: 'x', code: '23P01')),
      contains('overlaps'),
    );
    expect(
      friendlyError(const AuthException('Invalid login credentials')),
      'Invalid login credentials',
    );
  });
}
