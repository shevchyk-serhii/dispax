import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/json_parse.dart';

void main() {
  group('JsonParse.requiredDateTime', () {
    test('parses a valid ISO-8601 string', () {
      final dt = JsonParse.requiredDateTime({
        'pickupDateTime': '2026-06-18T18:18:00Z',
      }, 'pickupDateTime');
      expect(dt.toUtc(), DateTime.utc(2026, 6, 18, 18, 18));
    });

    test('throws FormatException naming the field when missing', () {
      expect(
        () => JsonParse.requiredDateTime({}, 'pickupDateTime'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('pickupDateTime'),
          ),
        ),
      );
    });

    test('throws on a malformed value instead of an opaque error', () {
      expect(
        () => JsonParse.requiredDateTime({
          'pickupDateTime': 'not-a-date',
        }, 'pickupDateTime'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('JsonParse.optionalDateTime', () {
    test('returns null for missing, null, empty, and malformed values', () {
      expect(JsonParse.optionalDateTime({}, 'x'), isNull);
      expect(JsonParse.optionalDateTime({'x': null}, 'x'), isNull);
      expect(JsonParse.optionalDateTime({'x': ''}, 'x'), isNull);
      expect(JsonParse.optionalDateTime({'x': 'garbage'}, 'x'), isNull);
    });

    test('parses a valid value', () {
      final dt = JsonParse.optionalDateTime({'x': '2026-01-02T03:04:05Z'}, 'x');
      expect(dt!.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    });
  });

  group('JsonParse.requiredDouble', () {
    test('accepts num and numeric string', () {
      expect(JsonParse.requiredDouble({'p': 12}, 'p'), 12.0);
      expect(JsonParse.requiredDouble({'p': 12.5}, 'p'), 12.5);
      expect(JsonParse.requiredDouble({'p': '7.5'}, 'p'), 7.5);
    });

    test('throws naming the field when missing or not a number', () {
      expect(
        () => JsonParse.requiredDouble({}, 'price'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('price'),
          ),
        ),
      );
      expect(
        () => JsonParse.requiredDouble({'price': 'abc'}, 'price'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('JsonParse.optionalDouble', () {
    test('falls back when missing or invalid', () {
      expect(JsonParse.optionalDouble({}, 'p'), 0);
      expect(JsonParse.optionalDouble({'p': 'x'}, 'p', fallback: -1), -1);
      expect(JsonParse.optionalDouble({'p': 3}, 'p'), 3.0);
    });
  });

  group('JsonParse.requiredString / optionalString', () {
    test('requiredString returns the string or throws', () {
      expect(JsonParse.requiredString({'s': 'hi'}, 's'), 'hi');
      expect(
        () => JsonParse.requiredString({'s': 5}, 's'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => JsonParse.requiredString({}, 'name'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('name'),
          ),
        ),
      );
    });

    test('optionalString returns null for missing or non-string', () {
      expect(JsonParse.optionalString({'s': 'hi'}, 's'), 'hi');
      expect(JsonParse.optionalString({}, 's'), isNull);
      expect(JsonParse.optionalString({'s': 5}, 's'), isNull);
    });
  });
}
