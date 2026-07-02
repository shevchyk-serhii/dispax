// The add-client dialog pre-fills a generated temporary password that must
// satisfy the backend policy (AuthService.validatePassword): at least 8
// characters with an uppercase letter, a lowercase letter, and a digit.
// Otherwise creation fails with WeakPassword and the client cannot be added.

import 'dart:math';

import 'package:dispax/utils/temp_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated temp passwords always satisfy the backend policy', () {
    final rng = Random(42);
    for (var i = 0; i < 500; i++) {
      final password = generateTempPassword(random: rng);
      expect(password.length, greaterThanOrEqualTo(8));
      expect(
        password,
        matches(RegExp(r'[A-Z]')),
        reason: 'must contain an uppercase letter: $password',
      );
      expect(
        password,
        matches(RegExp(r'[a-z]')),
        reason: 'must contain a lowercase letter: $password',
      );
      expect(
        password,
        matches(RegExp(r'[0-9]')),
        reason: 'must contain a digit: $password',
      );
      expect(isValidTempPassword(password), isTrue);
    }
  });

  test('isValidTempPassword mirrors the backend policy', () {
    expect(isValidTempPassword('Abcdef12'), isTrue);
    expect(isValidTempPassword('Abcde12'), isFalse, reason: 'too short');
    expect(isValidTempPassword('abcdefg1'), isFalse, reason: 'no uppercase');
    expect(isValidTempPassword('ABCDEFG1'), isFalse, reason: 'no lowercase');
    expect(isValidTempPassword('Abcdefgh'), isFalse, reason: 'no digit');
  });
}
