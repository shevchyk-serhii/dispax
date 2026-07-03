// fromJson hardening for the calendar-sharing models: required fields go
// through JsonParse so a missing/malformed value throws a FormatException
// naming the field, instead of an opaque `type 'Null' is not a subtype of
// String` TypeError deep in the parser (see json_parse.dart).

import 'package:dispax/modules/schedule_management/models/calendar_share.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _formatExceptionNaming(String field) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', contains(field)),
);

void main() {
  group('CalendarShareInvite.fromJson', () {
    Map<String, dynamic> json0() => {
      'id': 'inv-1',
      'code': 'ABCD1234',
      'createdAt': '2026-06-01T10:00:00Z',
      'expiresAt': '2026-06-08T10:00:00Z',
    };

    test('parses required fields', () {
      final invite = CalendarShareInvite.fromJson(json0());
      expect(invite.id, 'inv-1');
      expect(invite.code, 'ABCD1234');
      expect(invite.createdAt, DateTime.parse('2026-06-01T10:00:00Z'));
      expect(invite.expiresAt, DateTime.parse('2026-06-08T10:00:00Z'));
    });

    for (final field in ['id', 'code', 'createdAt', 'expiresAt']) {
      test('missing $field throws a FormatException naming it', () {
        expect(
          () => CalendarShareInvite.fromJson(json0()..remove(field)),
          _formatExceptionNaming(field),
        );
      });
    }
  });

  group('CalendarShareGrant.fromJson', () {
    Map<String, dynamic> json0() => {
      'id': 'grant-1',
      'grantorName': 'Anna',
      'grantorCompanyName': 'Ext GmbH',
      'granteeName': 'Me',
      'granteeCompanyName': 'My GmbH',
      'createdAt': '2026-06-01T10:00:00Z',
    };

    test('parses required fields', () {
      final grant = CalendarShareGrant.fromJson(json0());
      expect(grant.id, 'grant-1');
      expect(grant.createdAt, DateTime.parse('2026-06-01T10:00:00Z'));
    });

    for (final field in ['id', 'createdAt']) {
      test('missing $field throws a FormatException naming it', () {
        expect(
          () => CalendarShareGrant.fromJson(json0()..remove(field)),
          _formatExceptionNaming(field),
        );
      });
    }

    test('optional display names degrade to empty strings', () {
      final grant = CalendarShareGrant.fromJson(
        json0()
          ..remove('grantorName')
          ..remove('granteeCompanyName'),
      );
      expect(grant.grantorName, '');
      expect(grant.granteeCompanyName, '');
    });
  });

  group('SharedShift.fromJson', () {
    Map<String, dynamic> json0() => {
      'date': '2026-06-22',
      'startTime': '08:00',
      'endTime': '16:00',
      'status': 'Scheduled',
    };

    test('parses the date', () {
      expect(SharedShift.fromJson(json0()).date, DateTime.parse('2026-06-22'));
    });

    test('missing date throws a FormatException naming it', () {
      expect(
        () => SharedShift.fromJson(json0()..remove('date')),
        _formatExceptionNaming('date'),
      );
    });
  });

  group('SharedBusySlot.fromJson', () {
    Map<String, dynamic> json0() => {
      'start': '2026-06-22T09:00:00Z',
      'end': '2026-06-22T10:00:00Z',
      'kind': 'Ride',
    };

    test('parses start/end to local time', () {
      final slot = SharedBusySlot.fromJson(json0());
      expect(slot.start, DateTime.parse('2026-06-22T09:00:00Z').toLocal());
      expect(slot.end, DateTime.parse('2026-06-22T10:00:00Z').toLocal());
    });

    for (final field in ['start', 'end']) {
      test('missing $field throws a FormatException naming it', () {
        expect(
          () => SharedBusySlot.fromJson(json0()..remove(field)),
          _formatExceptionNaming(field),
        );
      });
    }
  });

  group('SharedCalendar.fromJson', () {
    Map<String, dynamic> json0() => {
      'grantId': 'grant-1',
      'grantorName': 'Anna',
      'shifts': <dynamic>[],
      'busySlots': <dynamic>[],
    };

    test('parses the grant id', () {
      expect(SharedCalendar.fromJson(json0()).grantId, 'grant-1');
    });

    test('missing grantId throws a FormatException naming it', () {
      expect(
        () => SharedCalendar.fromJson(json0()..remove('grantId')),
        _formatExceptionNaming('grantId'),
      );
    });
  });
}
