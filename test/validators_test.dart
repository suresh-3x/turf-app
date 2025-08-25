import 'package:flutter_test/flutter_test.dart';
import 'package:turfapp/utils/validators.dart';

void main() {
  group('validateEmail', () {
    test('returns error when null or empty', () {
      expect(validateEmail(null), isNotNull);
      expect(validateEmail(''), isNotNull);
    });

    test('returns null for non-empty input (basic placeholder)', () {
      expect(validateEmail('user@example.com'), isNull);
    });
  });

  group('validatePassword', () {
    test('returns error when null or empty', () {
      expect(validatePassword(null), isNotNull);
      expect(validatePassword(''), isNotNull);
    });

    test('returns null for non-empty input (basic placeholder)', () {
      expect(validatePassword('secret'), isNull);
    });
  });
}
