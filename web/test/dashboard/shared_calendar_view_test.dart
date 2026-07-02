import 'package:dispax/dashboard/driver/calendar/shared_calendar_view.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/schedule_management/models/calendar_share.dart';
import 'package:dispax/modules/schedule_management/services/calendar_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCalendarShareService extends Mock implements CalendarShareService {}

void main() {
  late _MockCalendarShareService service;

  setUp(() {
    service = _MockCalendarShareService();
  });

  Widget wrap() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SharedCalendarView(
        grantId: 'grant-1',
        grantorName: 'Anna External',
        grantorCompanyName: 'External GmbH',
        service: service,
      ),
    ),
  );

  DateTime mondayOfThisWeek() {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  testWidgets('renders shift chips and busy bars for the current week', (
    tester,
  ) async {
    final monday = mondayOfThisWeek();
    when(
      () => service.getSharedCalendar(
        'grant-1',
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => SharedCalendar(
        grantId: 'grant-1',
        grantorName: 'Anna External',
        shifts: [
          SharedShift(
            date: monday,
            startTime: '08:00',
            endTime: '16:00',
            status: 'Scheduled',
          ),
        ],
        busySlots: [
          SharedBusySlot(
            start: monday.add(const Duration(hours: 9)),
            end: monday.add(const Duration(hours: 10)),
            kind: 'Ride',
          ),
        ],
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('Shift 08:00–16:00'), findsOneWidget);
    expect(find.textContaining('Busy'), findsOneWidget);
    expect(find.textContaining('External GmbH'), findsOneWidget);
  });

  testWidgets('shows the empty state when the week has no data', (
    tester,
  ) async {
    when(
      () => service.getSharedCalendar(
        'grant-1',
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => const SharedCalendar(
        grantId: 'grant-1',
        grantorName: 'Anna External',
        shifts: [],
        busySlots: [],
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No shifts or busy slots this week'), findsOneWidget);
  });

  testWidgets('paging to the next week issues a new request', (tester) async {
    when(
      () => service.getSharedCalendar(
        'grant-1',
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => const SharedCalendar(
        grantId: 'grant-1',
        grantorName: 'Anna External',
        shifts: [],
        busySlots: [],
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    final captured = verify(
      () => service.getSharedCalendar(
        'grant-1',
        from: captureAny(named: 'from'),
        to: captureAny(named: 'to'),
      ),
    ).captured;
    // Two loads: initial week and the next week, 7 days apart.
    expect(captured.length, 4);
    final firstFrom = captured[0] as DateTime;
    final secondFrom = captured[2] as DateTime;
    expect(secondFrom.difference(firstFrom).inDays, 7);
  });

  testWidgets('shows an error with retry when the load fails', (tester) async {
    when(
      () => service.getSharedCalendar(
        'grant-1',
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenThrow(ApiException('boom'));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
