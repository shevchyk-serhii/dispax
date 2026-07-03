// Regression: with a shared calendar selected, switching the view to Board
// (multiColumn) stranded the user — the body keeps rendering
// SharedCalendarView whenever _selectedShare != null regardless of the view
// type, while Board hides the driver dropdown (the only control that resets
// the share). Switching to Board must reset the selected share.

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
import 'package:dispax/dashboard/driver/calendar/shared_calendar_view.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeScheduleEvent extends Fake implements ScheduleEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockScheduleBloc extends MockBloc<ScheduleEvent, ScheduleState>
    implements ScheduleBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _selfDriver() => Person(
  id: 'self-driver-1',
  name: 'Self Driver',
  email: 'self.driver@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  roles: {PersonRole.driver, PersonRole.dispatcher},
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

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    scheduleBloc = _MockScheduleBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.apiClient).thenReturn(apiClient);

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
      if (path == '/calendar-shares/shared-with-me') {
        return http.Response(
          '[{"id":"grant-1","grantorName":"Erika","grantorCompanyName":'
          '"OtherCo","granteeName":"Self Driver","granteeCompanyName":'
          '"MyCo","createdAt":"2026-06-01T10:00:00.000"}]',
          200,
        );
      }
      return http.Response('[]', 200);
    });

    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => scheduleBloc.state).thenReturn(ScheduleState.loaded(const []));
    when(() => scheduleBloc.add(any())).thenAnswer((_) {});

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

  testWidgets('switching to Board resets a selected shared calendar '
      'instead of stranding the user on it', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(_selfDriver()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Select the shared calendar from the driver dropdown.
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Erika · OtherCo').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(SharedCalendarView),
      findsOneWidget,
      reason: 'selecting a share must show the shared calendar',
    );

    // Switch the view to Board via the view menu.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.byIcon(Icons.view_module));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.board));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(SharedCalendarView),
      findsNothing,
      reason:
          'Board hides the share dropdown, so a still-selected share would '
          'be a dead end — it must be reset when switching to Board',
    );
  });
}
