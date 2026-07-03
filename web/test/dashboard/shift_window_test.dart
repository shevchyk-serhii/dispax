// Regression tests for visibleShiftSegment — the pure clipping of a shift
// into the calendar's visible 06:00–23:00 window.
//
// The bug: both the week grid and the board timeline clamped start AND end
// into the window and dropped the region when `end - start <= 0`. A shift
// crossing midnight (e.g. 22:00–06:00) got its end clamped to the window
// start, producing a negative height — the whole shift silently vanished and
// the driver looked unavailable all evening.

import 'package:dispax/dashboard/driver/calendar/shift_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseShiftHour', () {
    test('parses HH:mm and HH:mm:ss to fractional hours', () {
      expect(parseShiftHour('06:00'), 6.0);
      expect(parseShiftHour('14:30'), 14.5);
      expect(parseShiftHour('22:15:00'), 22.25);
    });

    test('malformed input degrades to 0', () {
      expect(parseShiftHour('garbage'), 0.0);
    });
  });

  group('visibleShiftSegment', () {
    test('a fully in-window shift is unchanged', () {
      expect(visibleShiftSegment(9, 17), (start: 9.0, end: 17.0));
    });

    test(
      'an overnight shift renders its evening part (22:00–06:00 → 22–23)',
      () {
        expect(
          visibleShiftSegment(22, 6),
          (start: 22.0, end: 23.0),
          reason:
              'A shift crossing midnight must keep its in-window evening '
              'segment — it used to vanish entirely (negative height)',
        );
      },
    );

    test('a shift ending at midnight renders its evening part', () {
      expect(visibleShiftSegment(20, 0), (start: 20.0, end: 23.0));
    });

    test(
      'a shift starting before the window is clipped to the window start',
      () {
        expect(visibleShiftSegment(5, 8), (start: 6.0, end: 8.0));
      },
    );

    test('a shift ending after the window is clipped to the window end', () {
      expect(visibleShiftSegment(18, 23.5), (start: 18.0, end: 23.0));
    });

    test('a shift fully before the window has no visible part', () {
      expect(visibleShiftSegment(2, 5), isNull);
    });

    test('a zero-length shift has no visible part', () {
      expect(visibleShiftSegment(10, 10), isNull);
    });

    test('custom window bounds are honoured', () {
      expect(visibleShiftSegment(22, 6, windowStart: 0, windowEnd: 24), (
        start: 22.0,
        end: 24.0,
      ));
    });
  });
}
