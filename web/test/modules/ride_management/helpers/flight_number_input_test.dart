// Unit tests for the pure flight-number helpers and the uppercase input formatter.

import 'package:dispax/modules/ride_management/helpers/flight_number_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightNumber.normalize', () {
    test('strips whitespace and upper-cases (matches the backend)', () {
      expect(FlightNumber.normalize('lh 429'), 'LH429');
      expect(FlightNumber.normalize('  4y 1410 '), '4Y1410');
      expect(FlightNumber.normalize('de1811'), 'DE1811');
    });
  });

  group('FlightNumber.isValid', () {
    test('accepts plausible IATA/ICAO numbers', () {
      for (final n in [
        'LH429',
        'BA1',
        'DE1811',
        '4Y1410',
        'DLH123',
        'LH429A',
      ]) {
        expect(FlightNumber.isValid(n), isTrue, reason: '$n should be valid');
      }
    });

    test('accepts lower-case / spaced input (it normalizes first)', () {
      expect(FlightNumber.isValid('lh 429'), isTrue);
      expect(FlightNumber.isValid('de1811'), isTrue);
    });

    test('treats empty as valid (the number is optional)', () {
      expect(FlightNumber.isValid(''), isTrue);
      expect(FlightNumber.isValid('   '), isTrue);
    });

    test('rejects implausible values', () {
      for (final n in [
        'L1', // 1-char airline code
        'LH', // no digits
        '429', // no airline code
        'LH12345', // too many digits
        'LHBA1', // 4-char alpha prefix
        'LH-429', // punctuation
        'L@429',
      ]) {
        expect(
          FlightNumber.isValid(n),
          isFalse,
          reason: '$n should be invalid',
        );
      }
    });
  });

  group('UpperCaseTextFormatter', () {
    const fmt = UpperCaseTextFormatter();
    TextEditingValue v(String t) => TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );

    test('upper-cases new input', () {
      final out = fmt.formatEditUpdate(v('lh4'), v('lh42'));
      expect(out.text, 'LH42');
    });

    test('preserves the cursor position', () {
      final out = fmt.formatEditUpdate(const TextEditingValue(), v('lh429'));
      expect(out.text, 'LH429');
      expect(out.selection.baseOffset, 5);
    });

    test('leaves already-upper text untouched', () {
      final value = v('LH429');
      final out = fmt.formatEditUpdate(v('LH42'), value);
      expect(out, value);
    });
  });
}
