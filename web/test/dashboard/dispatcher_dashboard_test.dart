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
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/dashboard/dispatcher/dispatcher_dashboard.dart';
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

class _FakeCreateRideFormEvent extends Fake implements CreateRideFormEvent {}

// --- Mock BLoCs ---

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockScheduleBloc extends MockBloc<ScheduleEvent, ScheduleState>
    implements ScheduleBloc {}

class _MockCreateRideFormBloc
    extends MockBloc<CreateRideFormEvent, CreateRideFormState>
    implements CreateRideFormBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// --- Person fixtures ---

/// Dispatcher who also holds the driver role → canDrive == true.
Person _dispatcherWithDrive() => Person(
  id: 'disp-driver-1',
  name: 'Disp Driver',
  email: 'disp.driver@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher, PersonRole.driver},
);

/// Dispatcher without the driver role → canDrive == false.
Person _dispatcherOnly() => Person(
  id: 'disp-1',
  name: 'Dispatcher Anna',
  email: 'disp@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher},
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeScheduleEvent());
    registerFallbackValue(_FakeCreateRideFormEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockScheduleBloc scheduleBloc;
  late _MockCreateRideFormBloc createRideFormBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    scheduleBloc = _MockScheduleBloc();
    createRideFormBloc = _MockCreateRideFormBloc();
    apiClient = _MockApiClient();

    // Stub apiClient on authBloc so panels that call authBloc.apiClient don't throw.
    when(() => authBloc.apiClient).thenReturn(apiClient);

    // Stub every GET request to return an empty list — keeps panels happy.
    when(() => apiClient.get(any())).thenAnswer(
      (_) async => http.Response('[]', 200),
    );

    // RideBloc: idle loaded state, silently accept events.
    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(
      () => rideBloc.add(any()),
    ).thenAnswer((_) {});

    // ScheduleBloc: idle loaded state, silently accept events.
    when(() => scheduleBloc.state).thenReturn(ScheduleState.loaded(const []));
    when(
      () => scheduleBloc.add(any()),
    ).thenAnswer((_) {});

    // CreateRideFormBloc: default unmodified state.
    when(() => createRideFormBloc.state).thenReturn(
      CreateRideFormState.initial(),
    );
    when(
      () => createRideFormBloc.add(any()),
    ).thenAnswer((_) {});
  });

  /// Builds a [MaterialApp] with all required BLoCs for [DispatcherDashboard].
  Widget buildApp(Person user) {
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(user));

    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RideBloc>.value(value: rideBloc),
          BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
          BlocProvider<CreateRideFormBloc>.value(value: createRideFormBloc),
        ],
        child: const DispatcherDashboard(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Case 1: "Driver Map" button is visible for a dispatcher who can drive
  // ---------------------------------------------------------------------------
  testWidgets(
    '"Driver Map" FilledButton is shown in split-view toolbar when canDrive == true',
    (tester) async {
      // Force the widget into split-view (>= 800 px logical).
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherWithDrive()));
      // Allow async initState work (ScheduleBloc/RideBloc events) to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.widgetWithText(FilledButton, 'Driver Map'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Case 2: "Driver Map" button is hidden for a pure dispatcher (no driver role)
  // ---------------------------------------------------------------------------
  testWidgets(
    '"Driver Map" text is absent in split-view toolbar when canDrive == false, '
    'but "Billing" button is still visible',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherOnly()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // "Driver Map" must not appear at all.
      expect(find.text('Driver Map'), findsNothing);

      // "Billing" confirms the toolbar was rendered (regression guard).
      expect(find.widgetWithText(FilledButton, 'Billing'), findsOneWidget);
    },
  );
}
