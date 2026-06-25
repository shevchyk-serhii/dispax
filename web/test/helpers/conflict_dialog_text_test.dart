import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/l10n/app_localizations_en.dart';
import 'package:dispax/modules/core/services/api_client.dart'
    show ScheduleConflictInfo;
import 'package:dispax/modules/ride_management/helpers/conflict_dialog_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  test('rich body uses the conflicting ride route and LOCAL pickup time', () {
    // 09:18 UTC → render in local time. Build the expected local string from
    // the same instant so the test is timezone-independent.
    final info = ScheduleConflictInfo(
      from: 'Maximilianstrasse 10',
      to: 'Munich Airport T2',
      pickupAt: '2026-06-27T07:18:00Z',
    );
    final local = DateTime.parse('2026-06-27T07:18:00Z').toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final expectedTime =
        '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';

    final body = scheduleConflictDialogBody(l10n, info: info, message: 'raw');

    expect(body, contains('Maximilianstrasse 10'));
    expect(body, contains('Munich Airport T2'));
    expect(body, contains(expectedTime));
    // The raw server message is NOT used when structured details are present.
    expect(body, isNot(contains('raw')));
  });

  test('falls back to the raw message when no structured route', () {
    final body = scheduleConflictDialogBody(
      l10n,
      info: null,
      message: 'Driver already has a ride',
    );
    expect(body, contains('Driver already has a ride'));
  });

  test('falls back to the default when neither info nor message', () {
    final body = scheduleConflictDialogBody(l10n, info: null, message: null);
    expect(body, l10n.conflictDialogContentDefault);
  });

  test('partial info (missing to) falls back to message', () {
    final info = ScheduleConflictInfo(
      from: 'A',
      pickupAt: '2026-06-27T07:18:00Z',
    );
    final body = scheduleConflictDialogBody(l10n, info: info, message: 'msg');
    expect(body, contains('msg'));
  });

  test('unparseable pickup time renders a dash, never a raw timestamp', () {
    final info = ScheduleConflictInfo(
      from: 'A',
      to: 'B',
      pickupAt: 'not-a-date',
    );
    final body = scheduleConflictDialogBody(l10n, info: info, message: null);
    expect(body, contains('—'));
    expect(body, isNot(contains('not-a-date')));
  });
}
