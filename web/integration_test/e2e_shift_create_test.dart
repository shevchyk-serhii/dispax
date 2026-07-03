import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Regression e2e for the "cancelled shift blocks its day" bug.
///
/// Cancelling a shift is a soft-delete (the row stays with status=Cancelled and
/// the ShiftStrip hides it), but the old UNIQUE (driver_id, date) constraint
/// still counted that row — so re-creating a shift on such a day always failed
/// with 409 while the strip showed "No shifts", and the UI collapsed the reason
/// into the generic "Something went wrong" snackbar.
///
/// Flow: dispatcher opens Calendar (My Schedule), creates today's shift via the
/// ShiftStrip ⊕ dialog, cancels it through the chip, and creates it AGAIN —
/// the step that used to be impossible. Backend state is asserted over HTTP
/// after every step, so the test goes red if any UI action is a no-op.
void main() {
  patrolTest('dispatcher re-creates a shift on a day with a cancelled one', (
    $,
  ) async {
    await resetTestData();
    await bootstrapTestApp();
    // Don't pumpAndSettle at boot: while auth state is restored the app may
    // show a spinner, so settle can time out. Pump bounded frames instead.
    for (var i = 0; i < 5; i++) {
      await $.pump(const Duration(milliseconds: 300));
    }

    final token = await apiLogin(kDevDispatcher, kDevPassword);
    // POST /api/dev/reset leaves schedule_days intact (reference-ish data), so
    // cancel any leftover ACTIVE shifts for today from previous runs. The
    // cancelled rows that pile up are harmless — freeing the day despite them
    // is exactly what this test locks in.
    await _cancelActiveShiftsToday(token);

    await loginViaUi($, kDevDispatcher, kDevPassword);
    if (skipIfBackendDown($)) return;

    // Open Calendar (My Schedule): the ShiftStrip renders above the calendar
    // with the ⊕ add-shift button for the viewer's own schedule.
    await tapNav($, 'Calendar');
    final addBtn = find.byIcon(Icons.add_circle_outline);
    expect(
      await pumpUntilVisible($, addBtn),
      isTrue,
      reason: 'ShiftStrip add button should render on My Schedule',
    );

    // 1. Create today's shift with the dialog defaults (08:00–16:00).
    await $.tester.tap(addBtn.first, warnIfMissed: false);
    await pumpFor($);
    await $('Create').tap();
    await pumpFor($);

    var today = await _shiftsToday(token);
    final created = today.where((s) => s['status'] == 'Scheduled').toList();
    expect(
      created.length,
      1,
      reason: 'UI create should persist one Scheduled shift for today',
    );
    final firstId = created.single['id'];

    // 2. Cancel it via the chip → confirmation dialog (soft-delete).
    expect(await pumpUntilVisible($, find.text('08:00–16:00')), isTrue);
    await $.tester.tap(find.text('08:00–16:00').first, warnIfMissed: false);
    await pumpFor($);
    await $('Cancel shift').tap();
    await pumpFor($);

    today = await _shiftsToday(token);
    expect(
      today.singleWhere((s) => s['id'] == firstId)['status'],
      'Cancelled',
      reason: 'cancelling must soft-delete (row stays with status Cancelled)',
    );
    expect(
      await pumpUntilVisible($, find.text('No shifts')),
      isTrue,
      reason: 'the strip hides cancelled shifts, so the day reads empty',
    );

    // 3. Re-create the same shift on the same day — the regression step: with
    // the old UNIQUE(driver_id, date) constraint this returned 409 forever.
    await $.tester.tap(
      find.byIcon(Icons.add_circle_outline).first,
      warnIfMissed: false,
    );
    await pumpFor($);
    await $('Create').tap();
    await pumpFor($);

    // No conflict / generic error snackbar…
    expect(
      find.text(
        'This day already has a shift that overlaps the selected time.',
      ),
      findsNothing,
      reason: 'a cancelled shift must free its slot',
    );
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
    // …the chip is back in the strip…
    expect(
      await pumpUntilVisible($, find.text('08:00–16:00')),
      isTrue,
      reason: 're-created shift should render in the strip',
    );

    // …and the backend holds a NEW Scheduled shift alongside the cancelled row.
    today = await _shiftsToday(token);
    final active = today.where((s) => s['status'] == 'Scheduled').toList();
    expect(
      active.length,
      1,
      reason: 'exactly one active shift after re-create',
    );
    expect(
      active.single['id'],
      isNot(firstId),
      reason:
          're-create must insert a new row, not resurrect the cancelled one',
    );
    expect(
      today.any((s) => s['id'] == firstId && s['status'] == 'Cancelled'),
      isTrue,
      reason: 'the cancelled row must survive as history',
    );
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

/// Fetches the dispatcher's own schedule over HTTP and keeps today's rows.
Future<List<Map<String, dynamic>>> _shiftsToday(String token) async {
  final r = await http.get(
    Uri.parse('$kApiBaseUrl/schedules/driver/$_dispatcherId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  expect(r.statusCode, 200, reason: 'schedule fetch over HTTP should succeed');
  final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  return list.where((s) => s['date'] == _todayStr()).toList();
}

/// Cancels every non-cancelled shift the dispatcher has today (DELETE is the
/// soft-cancel endpoint), so the suite is repeatable on a persistent test DB.
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
