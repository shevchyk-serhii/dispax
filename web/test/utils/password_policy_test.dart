// Unit tests for the shared client-side password policy, which must mirror
// the backend AuthService.validatePassword: >=8 chars, uppercase, lowercase,
// and a digit.

import 'package:dispax/utils/password_policy.dart';
import 'package:dispax/utils/temp_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPolicyCompliantPassword', () {
    test('accepts a password matching the backend policy', () {
      expect(isPolicyCompliantPassword('NewPass123'), isTrue);
      expect(isPolicyCompliantPassword('Aa345678'), isTrue);
    });

    test('rejects a password shorter than 8 characters', () {
      // Would pass the old client-side `< 6` check.
      expect(isPolicyCompliantPassword('Abc123'), isFalse);
      expect(isPolicyCompliantPassword('Abcd123'), isFalse);
    });

    test('rejects a password without an uppercase letter', () {
      expect(isPolicyCompliantPassword('abcdefg1'), isFalse);
    });

    test('rejects a password without a lowercase letter', () {
      expect(isPolicyCompliantPassword('ABCDEFG1'), isFalse);
    });

    test('rejects a password without a digit', () {
      expect(isPolicyCompliantPassword('Abcdefgh'), isFalse);
    });

    test('rejects the empty password', () {
      expect(isPolicyCompliantPassword(''), isFalse);
    });

    test('isValidTempPassword delegates to the same policy', () {
      expect(isValidTempPassword('NewPass123'), isTrue);
      expect(isValidTempPassword('abcdef'), isFalse);
    });
  });
}
