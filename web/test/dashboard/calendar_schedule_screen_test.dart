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
    // one colleague, everything else returns an empty list to keep the calendar
    // widgets happy.
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

  // Reference the unused fixture so analysis stays clean if it is later needed.
  test('colleague fixture is well-formed', () {
    expect(_colleague().name, 'Hans Weber');
  });
}
