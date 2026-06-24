import 'package:dispax/modules/schedule_management/models/driver_unavailability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validJson() => {
    'id': 'u1',
    'driverId': 'd1',
    'companyId': 'co1',
    'fromTime': '2026-03-15T08:00:00.000Z',
    'toTime': '2026-03-15T09:00:00.000Z',
    'reason': 'Lunch',
    'note': 'Break',
    'createdAt': '2026-03-10T07:00:00.000Z',
  };

  group('DriverUnavailability.fromJson', () {
    test('parses a valid record and converts datetimes to local', () {
      final u = DriverUnavailability.fromJson(validJson());

      expect(u.id, 'u1');
      expect(u.driverId, 'd1');
      expect(u.reason, DriverUnavailabilityReason.lunch);
      expect(u.note, 'Break');
      expect(u.fromTime.isUtc, isFalse);
      expect(u.toTime.isUtc, isFalse);
      expect(u.createdAt.isUtc, isFalse);
      expect(u.fromTime.toUtc().toIso8601String(), '2026-03-15T08:00:00.000Z');
    });

    // Regression: fromTime/toTime/createdAt used to call raw DateTime.parse,
    // so a single malformed or null datetime threw an opaque TypeError /
    // FormatException that took down the entire driver-schedule load. It must
    // now throw a FormatException that names the offending field instead.
    test('throws a named FormatException on a malformed fromTime', () {
      final json = validJson()..['fromTime'] = 'not-a-date';

      expect(
        () => DriverUnavailability.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('fromTime'),
          ),
        ),
      );
    });

    test('throws a named FormatException on a null toTime', () {
      final json = validJson()..['toTime'] = null;

      expect(
        () => DriverUnavailability.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('toTime'),
          ),
        ),
      );
    });

    test('throws a named FormatException on a missing createdAt', () {
      final json = validJson()..remove('createdAt');

      expect(
        () => DriverUnavailability.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('createdAt'),
          ),
        ),
      );
    });
  });
}
