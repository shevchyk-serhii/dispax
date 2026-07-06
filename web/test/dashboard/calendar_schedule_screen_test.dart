import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/blocs/schedule/schedule_event.dart';
import 'package:dispax/blocs/schedule/schedule_state.dart';
import 'package:dispax/dashboard/driver/calendar/calendar_schedule_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// --- Fakes for registerFallbackValue ---

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeScheduleEvent extends Fake implements ScheduleEvent {}

// --- Mock BLoCs ---

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockScheduleBloc extends MockBloc<ScheduleEvent, ScheduleState>
    implements ScheduleBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// --- Person fixtures ---

/// A driver who is allowed to view colleagues' schedules.
Person _selfDriver() => Person(
  id: 'self-driver-1',
  name: 'Self Driver',
  email: 'self.driver@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  roles: {PersonRole.driver, PersonRole.dispatcher},
);

/// A plain driver who may NOT view colleagues' schedules.
Person _plainDriver() => Person(
  id: 'plain-driver-1',
  name: 'Plain Driver',
  email: 'plain.driver@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  roles: {PersonRole.driver},
);

Person _colleague() => Person(
  id: 'colleague-1',
  name: 'Hans Weber',
  email: 'hans.weber@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  roles: {PersonRole.driver},
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeScheduleEvent());
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockScheduleBloc scheduleBloc;
  late _MockApiClient apiClient;

  // Drives the mocked /schedules/visibility/me response per test.
  late bool canViewOthers;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    scheduleBloc = _MockScheduleBloc();
    apiClient = _MockApiClient();
    canViewOthers = true;

    when(() => authBloc.apiClient).thenReturn(apiClient);

    // Route GETs by path: visibility reflects [canViewOthers], drivers returns
    // one colleague, the colleague's rides endpoint returns one ride, and
    // everything else returns an empty list to keep the calendar widgets happy.
    when(() => apiClient.get(any())).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/schedules/visibility/me') {
        return http.Response('{"canViewOtherSchedules": $canViewOthers}', 200);
      }
      if (path == '/users/drivers') {
        return http.Response(
          '[{"id":"colleague-1","name":"Hans Weber",'
          '"email":"hans.weber@example.com","role":"DRIVER"}]',
          200,
        );
      }
      if (path == '/rides/driver/colleague-1') {
        // One ride assigned to the selected colleague on 2026-03-15.
        return http.Response(
          '[{"id":"col-ride-1","clientId":"client-1","creatorId":"creator-1",'
          '"companyId":"company-1","driverId":"colleague-1",'
          '"pickupDateTime":"2026-03-15T10:00:00.000",'
          '"from":{"address":"Pickup St","latitude":48.1,"longitude":11.5},'
          '"to":{"address":"Dropoff St","latitude":48.2,"longitude":11.6},'
          '"status":"Assigned","clientName":"Colleague Client",'
          '"isAirportTransfer":false,"isArrival":false,'
          '"driverApproaching":false}]',
          200,
        );
      }
      return http.Response('[]', 200);
    });

    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(() => rideBloc.add(any())).thenAnswer((_) {});

    when(() => scheduleBloc.state).thenReturn(ScheduleState.loaded(const []));
    when(() => scheduleBloc.add(any())).thenAnswer((_) {});

    // The view type lives in a static notifier shared across the screen's
    // lifetime, so reset it to a known value before each test to keep them
    // order-independent.
    CalendarScheduleScreen.viewTypeNotifierForTest.value =
        CalendarViewType.month;
    CalendarScheduleScreen.selectedDayNotifierForTest.value = DateTime(
      2026,
      3,
      15,
    );
  });

  Widget buildApp(Person user) {
    when(() => authBloc.state).thenReturn(AuthState.authenticated(user));

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RideBloc>.value(value: rideBloc),
          BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
        ],
        child: const CalendarScheduleScreen(),
      ),
    );
  }

  testWidgets(
    'driver dropdown is shown in month view when colleagues are visible',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_selfDriver()));
      // Let _initVisibility() resolve the async colleague fetch.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byType(DropdownButton<String?>),
        findsOneWidget,
        reason: 'month view must offer the driver picker',
      );
    },
  );

  testWidgets('driver dropdown is hidden in Board (multiColumn) view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp(_selfDriver()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Sanity: picker present in the default (month) view.
    expect(find.byType(DropdownButton<String?>), findsOneWidget);

    // Switch to the Board view.
    CalendarScheduleScreen.viewTypeNotifierForTest.value =
        CalendarViewType.multiColumn;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The picker must disappear; a plain title takes its place.
    expect(
      find.byType(DropdownButton<String?>),
      findsNothing,
      reason: 'Board view lists every driver in columns; the picker is moot',
    );
    expect(
      find.text('My Schedule'),
      findsOneWidget,
      reason: 'Board view falls back to a plain AppBar title',
    );
  });

  testWidgets(
    'driver dropdown is absent in every view when the user may not view others',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      canViewOthers = false;

      await tester.pumpWidget(buildApp(_plainDriver()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // No picker in the month view...
      expect(
        find.byType(DropdownButton<String?>),
        findsNothing,
        reason: 'no permission → no driver picker',
      );

      // ...and none in the Board view either.
      CalendarScheduleScreen.viewTypeNotifierForTest.value =
          CalendarViewType.multiColumn;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(DropdownButton<String?>), findsNothing);
      expect(find.text('My Schedule'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a colleague loads and renders THEIR rides, not the shared '
    'RideBloc',
    (tester) async {
      // A roomy viewport so the day-view ride card's action row lays out
      // without a RenderFlex overflow (unrelated to what we assert).
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // The shared RideBloc holds NO rides for the logged-in dispatcher — this
      // is the bug scenario: before the fix the grid read this empty list and
      // stayed blank when a colleague was picked.
      when(() => rideBloc.state).thenReturn(RideState.loaded(const []));

      await tester.pumpWidget(buildApp(_selfDriver()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Switch to the day view so individual ride cards (with the client name)
      // are rendered rather than month markers.
      CalendarScheduleScreen.viewTypeNotifierForTest.value =
          CalendarViewType.day;
      await tester.pump();

      // Open the driver picker and choose the colleague.
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hans Weber').last);
      await tester.pump(); // dropdown closes, _loadDriverRides starts
      await tester.pump(const Duration(milliseconds: 50)); // load resolves
      await tester.pumpAndSettle();

      // The colleague's rides endpoint was hit...
      verify(() => apiClient.get('/rides/driver/colleague-1')).called(1);
      // ...and their ride is rendered even though the shared RideBloc is empty.
      expect(
        find.text('Colleague Client'),
        findsOneWidget,
        reason:
            'the selected colleague\'s ride must show, sourced from '
            '/rides/driver/{id}, not the empty shared RideBloc',
      );
    },
  );

  // Regression (defect #2): setting a price on a SELECTED COLLEAGUE's ride only
  // refreshed the shared RideBloc, never the parent-owned _driverRides override
  // the colleague view actually renders — so their card kept the stale price.
  // After the fix, a successful price edit must re-fetch /rides/driver/{id}.
  testWidgets(
    'editing a colleague ride price re-loads their rides (override refresh)',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // The colleague's ride has no price yet, so the card shows "Set price".
      // The price PUT succeeds and returns the same ride enriched with a price.
      when(() => apiClient.put('/rides/col-ride-1/price', any())).thenAnswer((
        _,
      ) async {
        return http.Response(
          '{"id":"col-ride-1","clientId":"client-1","creatorId":"creator-1",'
          '"companyId":"company-1","driverId":"colleague-1",'
          '"pickupDateTime":"2026-03-15T10:00:00.000",'
          '"from":{"address":"Pickup St","latitude":48.1,"longitude":11.5},'
          '"to":{"address":"Dropoff St","latitude":48.2,"longitude":11.6},'
          '"status":"Assigned","clientName":"Colleague Client","price":75.0,'
          '"isAirportTransfer":false,"isArrival":false,'
          '"driverApproaching":false}',
          200,
        );
      });

      await tester.pumpWidget(buildApp(_selfDriver()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      CalendarScheduleScreen.viewTypeNotifierForTest.value =
          CalendarViewType.day;
      await tester.pump();

      // Pick the colleague — first /rides/driver/colleague-1 load.
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hans Weber').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      verify(() => apiClient.get('/rides/driver/colleague-1')).called(1);

      // Open the price dialog on the colleague's card and confirm a new price.
      await tester.tap(find.text('Set price'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '75.00');
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // The price was submitted...
      verify(() => apiClient.put('/rides/col-ride-1/price', any())).called(1);
      // ...and the override was refetched so the new price can surface.
      verify(() => apiClient.get('/rides/driver/colleague-1')).called(1);
    },
  );

  // Regression: the calendar shares the global ScheduleBloc with the dispatcher's
  // DriverSchedulePanel. It used to dispatch ScheduleLoadDriverSchedule for the
  // logged-in driver on init — a driver with no own schedule_days emits
  // loaded([]), which clobbered the 3 drivers the panel had loaded for the date
  // (the "No drivers scheduled" bug). The calendar never reads scheduleDays, so
  // that dispatch is dead code; it must not fire.
  testWidgets('calendar never dispatches ScheduleLoadDriverSchedule on init '
      '(would clobber the shared ScheduleBloc)', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp(_selfDriver()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verifyNever(
      () => scheduleBloc.add(any(that: isA<ScheduleLoadDriverSchedule>())),
    );
  });

  testWidgets(
    'selecting a colleague does not dispatch ScheduleLoadDriverSchedule',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_selfDriver()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      CalendarScheduleScreen.viewTypeNotifierForTest.value =
          CalendarViewType.day;
      await tester.pump();

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hans Weber').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      verifyNever(
        () => scheduleBloc.add(any(that: isA<ScheduleLoadDriverSchedule>())),
      );
    },
  );

  // Error-UX regression: a failed colleague-rides load used to render the raw
  // 'Failed to load driver rides: ApiException(...)' string. The screen must
  // route the stored error through friendlyError instead.
  testWidgets(
    'driver rides load failure renders the friendly localized error, not the raw exception',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Re-stub: the colleague's rides endpoint fails with a server error.
      when(() => apiClient.get(any())).thenAnswer((invocation) async {
        final path = invocation.positionalArguments.first as String;
        if (path == '/schedules/visibility/me') {
          return http.Response('{"canViewOtherSchedules": true}', 200);
        }
        if (path == '/users/drivers') {
          return http.Response(
            '[{"id":"colleague-1","name":"Hans Weber",'
            '"email":"hans.weber@example.com","role":"DRIVER"}]',
            200,
          );
        }
        if (path == '/rides/driver/colleague-1') {
          throw ApiException('boom', statusCode: 500);
        }
        return http.Response('[]', 200);
      });

      await tester.pumpWidget(buildApp(_selfDriver()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      CalendarScheduleScreen.viewTypeNotifierForTest.value =
          CalendarViewType.day;
      await tester.pump();

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hans Weber').last);
      await tester.pump(); // dropdown closes, _loadDriverRides starts
      await tester.pump(const Duration(milliseconds: 50)); // load fails
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Something went wrong on our side. Please try again in a moment.',
        ),
        findsOneWidget,
        reason: 'the error placeholder must show the friendlyError mapping',
      );
      expect(
        find.textContaining('ApiException'),
        findsNothing,
        reason: 'raw exception text must never reach the UI',
      );
      expect(find.textContaining('Failed to load driver rides:'), findsNothing);
    },
  );

  // Reference the unused fixture so analysis stays clean if it is later needed.
  test('colleague fixture is well-formed', () {
    expect(_colleague().name, 'Hans Weber');
  });
}
