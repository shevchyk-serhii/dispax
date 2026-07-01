// Unit tests for the shared `Validators` form-field validators.
//
// These pure functions back every login / sign-up / client form in the app yet
// previously had zero coverage. The tests pin down their edge-case behaviour:
// empty/null handling, the email regex, the password length boundary, and the
// (optional) phone format — so a regression in any of them goes red.

import 'package:dispax/constants/app_constants.dart';
import 'package:dispax/modules/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('null and empty are rejected', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('malformed addresses are rejected', () {
      // Missing user, missing domain, no "@", and no dot in the domain.
      expect(Validators.email('test@'), isNotNull);
      expect(Validators.email('@x.com'), isNotNull);
      expect(Validators.email('no-at'), isNotNull);
      expect(Validators.email('a@b'), isNotNull); // no dot after the domain
    });

    test('well-formed addresses pass', () {
      expect(Validators.email('a@b.de'), isNull);
      expect(Validators.email('x@y.co.uk'), isNull);
    });
  });

  group('Validators.password', () {
    final min = AppConstants.minPasswordLength.toInt(); // 6

    test('null and empty are rejected', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
    });

    test('shorter than the minimum is rejected', () {
      expect(Validators.password('a' * (min - 1)), isNotNull);
    });

    test('exactly the minimum length passes (boundary)', () {
      expect(Validators.password('a' * min), isNull);
    });

    test('longer than the minimum passes', () {
      expect(Validators.password('a' * (min + 4)), isNull);
    });
  });

  group('Validators.required', () {
    test('null and empty are rejected', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required(''), isNotNull);
    });

    test('a non-empty value passes', () {
      expect(Validators.required('x'), isNull);
    });

    // NOTE: `required` does NOT trim — a whitespace-only string currently passes.
    // This documents the actual behaviour; `required`/`minLength`/`phone` are an
    // unused public API today, so this is not a live prod bug, but the test locks
    // the contract so a future trim change is a deliberate, visible decision.
    test('whitespace-only currently passes (no trim)', () {
      expect(Validators.required('   '), isNull);
    });

    test('the field name is interpolated into the message', () {
      expect(Validators.required(null, fieldName: 'Name'), contains('Name'));
    });
  });

  group('Validators.minLength', () {
    test('null and empty are rejected', () {
      expect(Validators.minLength(null, 3), isNotNull);
      expect(Validators.minLength('', 3), isNotNull);
    });

    test('shorter than the limit is rejected', () {
      expect(Validators.minLength('ab', 3), isNotNull);
    });

    test('exactly the limit passes (boundary)', () {
      expect(Validators.minLength('abc', 3), isNull);
    });

    test('longer than the limit passes', () {
      expect(Validators.minLength('abcd', 3), isNull);
    });
  });

  group('Validators.phone', () {
    test('null and empty are valid (phone is optional)', () {
      expect(Validators.phone(null), isNull);
      expect(Validators.phone(''), isNull);
    });

    test('a formatted number passes', () {
      expect(Validators.phone('+49 (89) 123-45'), isNull);
    });

    test('letters and other junk are rejected', () {
      expect(Validators.phone('abc'), isNotNull);
      expect(Validators.phone('12a34'), isNotNull);
    });
  });
}
