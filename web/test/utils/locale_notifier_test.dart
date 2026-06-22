import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/locale_notifier.dart';

void main() {
  group('localeFromString', () {
    test('returns Locale("en") for "en"', () {
      expect(localeFromString('en'), const Locale('en'));
    });

    test('returns Locale("de") for "de"', () {
      expect(localeFromString('de'), const Locale('de'));
    });

    test('returns Locale("uk") for "uk"', () {
      expect(localeFromString('uk'), const Locale('uk'));
    });

    // Mutation-critical: if the switch loses an arm (e.g. 'uk' removed),
    // the test for 'uk' would fail. If the default clause is removed, 'fr' would
    // map to a real Locale instead of null.
    test('returns null for unsupported code "fr"', () {
      expect(localeFromString('fr'), isNull);
    });

    test('returns null for unsupported code "ru"', () {
      expect(localeFromString('ru'), isNull);
    });

    test('returns null for empty string', () {
      expect(localeFromString(''), isNull);
    });

    test('returns null for null input', () {
      expect(localeFromString(null), isNull);
    });

    test('is case-sensitive — "DE" is not the same as "de"', () {
      // The backend validates the code and stores lowercase; a mis-cased value
      // that somehow reaches the client should not silently apply the wrong locale.
      expect(localeFromString('DE'), isNull);
    });
  });

  group('localeNotifier', () {
    setUp(() => localeNotifier.value = null);
    tearDown(() => localeNotifier.value = null);

    test('initial value is null (system locale)', () {
      expect(localeNotifier.value, isNull);
    });

    test('setting to a Locale is reflected immediately', () {
      localeNotifier.value = const Locale('de');
      expect(localeNotifier.value, const Locale('de'));
    });

    test('can be reset to null', () {
      localeNotifier.value = const Locale('uk');
      localeNotifier.value = null;
      expect(localeNotifier.value, isNull);
    });
  });
}
