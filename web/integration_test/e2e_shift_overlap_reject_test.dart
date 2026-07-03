import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// A shift whose time overlaps an existing (non-cancelled) shift on the same day
/// is rejected with the localized overlap message — not the generic error, and
/// no second active shift is persisted.
///
/// We seed a full-day 00:00–23:59 shift over HTTP so the day is "packed". The
/// ShiftStrip create dialog then falls back to its plain 08:00–16:00 default
/// (see _CreateShiftDialog._firstFreeWindow), which overlaps the seeded shift,
/// so tapping Create hits the backend exclusion constraint → 409 → the UI shows
/// shiftOverlapSnack. This keeps the test off the fragile Material time-picker.
///
/// Backend state is asserted over HTTP: exactly ONE active shift for today
/// afterwards (the seeded one), proving the second create did not slip through.
void main() {
  patrolTest('overlapping shift on the same day is rejected in the UI', (
    $,
  ) async {
    await resetTestData();
    await bootstrapTestApp();
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    final token = await apiLogin(kDevDispatcher, kDevPassword);
    // Repeatable on a persistent test DB: cancel any leftover active shifts for
    // today, then seed a single full-day shift that packs the day.
    await _cancelActiveShiftsToday(token);
    final seed = await http.post(
      Uri.parse('$kApiBaseUrl/schedules'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'driverId': _dispatcherId,
        'date': _todayStr(),
        'startTime': '00:00',
        'endTime': '23:59',
      }),
    );
    expect(
      seed.statusCode,
      201,
      reason: 'seeding the full-day shift should work',
    );

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Calendar');
    final addBtn = find.byIcon(Icons.add_circle_outline);
    expect(
      await pumpUntilVisible($, addBtn),
      isTrue,
      reason: 'ShiftStrip add button should render on My Schedule',
    );

    // Open the create dialog and accept the (overlapping) default window.
    await $.tester.tap(addBtn.first, warnIfMissed: false);
    await pumpFor($);
    await $('Create').tap();
    await pumpFor($);

    // The UI must surface the localized overlap message, NOT the generic error.
    expect(
      await pumpUntilVisible(
        $,
        find.textContaining('overlaps an existing shift'),
      ),
      isTrue,
      reason: 'overlap should show the specific localized snackbar',
    );
    expect(
      find.text('Something went wrong. Please try again.'),
      findsNothing,
      reason: 'the backend reason must not collapse to the generic error',
    );

    // Backend: still exactly one active shift today — the seeded full-day one.
    final active = (await _shiftsToday(
      token,
    )).where((s) => s['status'] == 'Scheduled').toList();
    expect(
      active.length,
      1,
      reason: 'the overlapping create must not have persisted a second shift',
    );
    expect(active.single['startTime'], startsWith('00:00'));
  });
}

/// Max Müller (dispatcher@dispax.de) — seeded dev dispatcher with the Driver
/// role, so "My Schedule" shift management is available to him.
const String _dispatcherId = '11111111-1111-1111-1111-111111111111';

String _todayStr() {
  final d = DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$m-$day';
}

Future<List<Map<String, dynamic>>> _shiftsToday(String token) async {
  final r = await http.get(
    Uri.parse('$kApiBaseUrl/schedules/driver/$_dispatcherId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  expect(r.statusCode, 200, reason: 'schedule fetch over HTTP should succeed');
  final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  return list.where((s) => s['date'] == _todayStr()).toList();
}

Future<void> _cancelActiveShiftsToday(String token) async {
  for (final s in await _shiftsToday(token)) {
    if (s['status'] != 'Cancelled') {
      await http.delete(
        Uri.parse('$kApiBaseUrl/schedules/${s['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }
  }
}
