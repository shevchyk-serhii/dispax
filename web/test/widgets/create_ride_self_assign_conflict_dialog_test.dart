import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/screens/create_ride_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// When a driver creates a ride with "Assign to me" ON but the self-assignment
// hits a schedule conflict, the backend keeps the ride in the pool and returns
// it unassigned. RideBloc surfaces that as RideStateStatus.assignConflict, and
// the create screen must show a "Schedule conflict" dialog offering to assign
// anyway (override) or keep it in the pool.

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _driver() => Person(
  id: 'driver-self-1',
  name: 'Hans Weber',
  email: 'hans@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  phone: '+491111111111',
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeRideEvent()));

  late _MockRideBloc rideBloc;
  late _MockAuthBloc authBloc;
  late CreateRideFormBloc formBloc;

  setUp(() {
    rideBloc = _MockRideBloc();
    authBloc = _MockAuthBloc();
    formBloc = CreateRideFormBloc();
    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.apiClient).thenReturn(_MockApiClient());
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_driver()));
  });

  tearDown(() => formBloc.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RideBloc>.value(value: rideBloc),
            BlocProvider<CreateRideFormBloc>.value(value: formBloc),
          ],
          child: CreateRideScreenContent(onCreated: () {}),
        ),
      ),
    );
  }

  testWidgets('assignConflict shows the conflict dialog with "Assign anyway"', (
    tester,
  ) async {
    whenListen(
      rideBloc,
      Stream.fromIterable([
        const RideState(status: RideStateStatus.loading),
        const RideState(
          status: RideStateStatus.assignConflict,
          conflictRideId: 'ride-1',
          conflictDriverId: 'driver-1',
          errorMessage: 'Driver already has a ride at this time',
        ),
      ]),
      initialState: const RideState(),
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Schedule conflict'), findsOneWidget);
    expect(find.text('Assign anyway'), findsOneWidget);
    expect(find.text('Keep in pool'), findsOneWidget);
  });

  testWidgets('"Assign anyway" dispatches RideAssignRequested with override', (
    tester,
  ) async {
    whenListen(
      rideBloc,
      Stream.fromIterable([
        const RideState(status: RideStateStatus.loading),
        const RideState(
          status: RideStateStatus.assignConflict,
          conflictRideId: 'ride-1',
          conflictDriverId: 'driver-1',
        ),
      ]),
      initialState: const RideState(),
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign anyway'));
    await tester.pumpAndSettle();

    final captured = verify(() => rideBloc.add(captureAny())).captured;
    final assign = captured.whereType<RideAssignRequested>().toList();
    expect(assign, hasLength(1));
    expect(assign.first.rideId, 'ride-1');
    expect(assign.first.driverId, 'driver-1');
    expect(assign.first.overrideScheduleConflict, isTrue);
  });

  testWidgets('"Keep in pool" dispatches no assignment', (tester) async {
    whenListen(
      rideBloc,
      Stream.fromIterable([
        const RideState(status: RideStateStatus.loading),
        const RideState(
          status: RideStateStatus.assignConflict,
          conflictRideId: 'ride-1',
          conflictDriverId: 'driver-1',
        ),
      ]),
      initialState: const RideState(),
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep in pool'));
    await tester.pumpAndSettle();

    verifyNever(() => rideBloc.add(any(that: isA<RideAssignRequested>())));
  });
}
