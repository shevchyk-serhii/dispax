// Unit tests for the shared money-input parser: German decimal comma and
// dot decimals must both parse; garbage must return null (never 0).

import 'package:dispax/utils/parse_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmount', () {
    test('parses the German decimal comma', () {
      expect(parseAmount('12,50'), 12.50);
      expect(parseAmount('19,5'), 19.5);
      expect(parseAmount('0,99'), 0.99);
    });

    test('parses German thousands + decimal comma', () {
      expect(parseAmount('1.234,56'), 1234.56);
      expect(parseAmount('1.234.567,89'), 1234567.89);
    });

    test('parses plain dot decimals (US style)', () {
      expect(parseAmount('12.50'), 12.50);
      expect(parseAmount('1,234.56'), 1234.56);
      expect(parseAmount('1,234,567.89'), 1234567.89);
    });

    test('parses plain integers and trims whitespace', () {
      expect(parseAmount('42'), 42);
      expect(parseAmount(' 7,5 '), 7.5);
    });

    test('multiple separators of one kind are thousands separators', () {
      expect(parseAmount('1.234.567'), 1234567);
      expect(parseAmount('1,234,567'), 1234567);
    });

    test('garbage returns null, not 0', () {
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('12,5a'), isNull);
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount(','), isNull);
    });
  });
}
