import 'package:dispax/dashboard/driver/calendar/widgets/shift_strip.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/schedule_management/models/schedule_day.dart';
import 'package:dispax/modules/schedule_management/services/schedule_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockScheduleService extends Mock implements ScheduleService {}

void main() {
  late _MockScheduleService service;
  final day = DateTime(2026, 7, 3);

  ScheduleDay shift({
    String id = 'shift-1',
    DateTime? date,
    String start = '08:00',
    String end = '16:00',
    ScheduleDayStatus status = ScheduleDayStatus.scheduled,
  }) {
    return ScheduleDay(
      id: id,
      driverId: 'driver-1',
      companyId: 'company-1',
      date: date ?? day,
      startTime: start,
      endTime: end,
      status: status,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
  }

  setUp(() {
    service = _MockScheduleService();
    when(
      () => service.getDriverSchedule('driver-1'),
    ).thenAnswer((_) async => [shift()]);
  });

  Widget wrap({bool canManage = true}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: ShiftStrip(
        driverId: 'driver-1',
        selectedDay: day,
        canManage: canManage,
        service: service,
      ),
    ),
  );

  testWidgets('renders the shifts of the selected day as chips', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('08:00–16:00'), findsOneWidget);
  });

  testWidgets('cancelled shifts and other days are excluded', (tester) async {
    when(() => service.getDriverSchedule('driver-1')).thenAnswer(
      (_) async => [
        shift(id: 's1', status: ScheduleDayStatus.cancelled),
        shift(id: 's2', date: DateTime(2026, 7, 4), start: '10:00'),
      ],
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('08:00–16:00'), findsNothing);
    expect(find.text('10:00–16:00'), findsNothing);
    expect(find.text('No shifts'), findsOneWidget);
  });

  testWidgets('creating a shift with the dialog defaults calls the service', (
    tester,
  ) async {
    when(
      () => service.createScheduleDay(
        driverId: any(named: 'driverId'),
        date: any(named: 'date'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer((_) async => shift());

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verify(
      () => service.createScheduleDay(
        driverId: 'driver-1',
        date: '2026-07-03',
        startTime: '08:00',
        endTime: '16:00',
        notes: null,
      ),
    ).called(1);
    // The strip reloads after a successful create.
    verify(() => service.getDriverSchedule('driver-1')).called(2);
  });

  testWidgets('tapping a chip cancels the shift after confirmation', (
    tester,
  ) async {
    when(
      () => service.cancelScheduleDay('shift-1'),
    ).thenAnswer((_) async => shift(status: ScheduleDayStatus.cancelled));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('08:00–16:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel shift'));
    await tester.pumpAndSettle();

    verify(() => service.cancelScheduleDay('shift-1')).called(1);
    verify(() => service.getDriverSchedule('driver-1')).called(2);
  });

  testWidgets('read-only mode hides the add button and disables chips', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(canManage: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_circle_outline), findsNothing);

    // Tapping the chip must NOT open the cancel dialog.
    await tester.tap(find.text('08:00–16:00'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel shift'), findsNothing);
  });

  testWidgets('a failing load degrades to the empty label, not an error', (
    tester,
  ) async {
    when(
      () => service.getDriverSchedule('driver-1'),
    ).thenThrow(ApiException('boom'));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No shifts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
