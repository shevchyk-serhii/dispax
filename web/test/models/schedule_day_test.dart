import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/schedule_management/models/schedule_day.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('ScheduleDay', () {
    test('fromJson creates ScheduleDay correctly', () {
      final json = TestFixtures.scheduleDayJson();
      final day = ScheduleDay.fromJson(json);

      expect(day.id, 'schedule-1');
      expect(day.driverId, 'driver-1');
      expect(day.companyId, 'company-1');
      expect(day.startTime, '08:00');
      expect(day.endTime, '17:00');
      expect(day.status, ScheduleDayStatus.scheduled);
    });

    test('toJson produces correct map', () {
      final day = TestFixtures.scheduleDay();
      final json = day.toJson();

      expect(json['id'], 'schedule-1');
      expect(json['driverId'], 'driver-1');
      expect(json['startTime'], '08:00');
      expect(json['endTime'], '17:00');
      expect(json['status'], 'Scheduled');
    });

    test('fromJson/toJson roundtrip preserves data', () {
      final original = TestFixtures.scheduleDay(notes: 'Test note');
      final json = original.toJson();
      final restored = ScheduleDay.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.driverId, original.driverId);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.notes, original.notes);
    });

    test('copyWith preserves unchanged fields', () {
      final original = TestFixtures.scheduleDay();
      final copied = original.copyWith(status: ScheduleDayStatus.cancelled);

      expect(copied.id, original.id);
      expect(copied.driverId, original.driverId);
      expect(copied.startTime, original.startTime);
      expect(copied.status, ScheduleDayStatus.cancelled);
    });

    test('equality by id', () {
      final a = TestFixtures.scheduleDay(id: 's1');
      final b = TestFixtures.scheduleDay(id: 's1', startTime: '09:00');
      final c = TestFixtures.scheduleDay(id: 's2');

      expect(a, b);
      expect(a, isNot(c));
    });

    test('hashCode based on id', () {
      final a = TestFixtures.scheduleDay(id: 's1');
      final b = TestFixtures.scheduleDay(id: 's1', endTime: '18:00');

      expect(a.hashCode, b.hashCode);
    });
  });

  group('ScheduleDayStatus.fromString', () {
    test('parses all known statuses', () {
      expect(
        ScheduleDayStatus.fromString('Scheduled'),
        ScheduleDayStatus.scheduled,
      );
      expect(ScheduleDayStatus.fromString('Active'), ScheduleDayStatus.active);
      expect(
        ScheduleDayStatus.fromString('Completed'),
        ScheduleDayStatus.completed,
      );
      expect(
        ScheduleDayStatus.fromString('Cancelled'),
        ScheduleDayStatus.cancelled,
      );
    });

    test('is case insensitive', () {
      expect(
        ScheduleDayStatus.fromString('scheduled'),
        ScheduleDayStatus.scheduled,
      );
      expect(ScheduleDayStatus.fromString('ACTIVE'), ScheduleDayStatus.active);
    });

    test('returns scheduled as fallback for unknown status', () {
      expect(
        ScheduleDayStatus.fromString('garbage'),
        ScheduleDayStatus.scheduled,
      );
    });
  });
}
