// Regression guard: raw ride UUIDs must not be shown to users.
//
// Follows the ride-details-title fix: every UI surface that used to render
// "#<uuid-prefix>" now shows human-readable data instead:
//   - AssignmentDialog title      -> "Assign Ride · <client name>"
//   - BulkReassignDialog title    -> "Reassign ride · <client name>"
//   - ChatScreen AppBar subtitle  -> "Online · ride at <dd.MM HH:mm>"
//   - FlightScreen linked ride    -> "<client name>" (no "#id · " prefix)

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
import 'package:dispax/dashboard/dispatcher/widgets/assignment_dialog.dart';
import 'package:dispax/dashboard/dispatcher/widgets/bulk_reassign_dialog.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/flight_management/services/flight_service.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/chat_screen.dart';
import 'package:dispax/screens/flight_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

// ─── Local fakes / mocks ─────────────────────────────────────────────────────

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockScheduleBloc extends MockBloc<ScheduleEvent, ScheduleState>
    implements ScheduleBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

class _MockFlightService extends Mock implements FlightService {}

// ─── Shared fixture ──────────────────────────────────────────────────────────

const _rideId = 'e4e4e4e4-e4e4-e4e4-e4e4-e4e4e4e4e4e4';
const _idPrefix = 'e4e4e4e4';

Ride _ride({String? driverId, String? flightNumber}) => TestFixtures.ride(
  id: _rideId,
  clientName: 'Max Mustermann',
  driverId: driverId,
  flightNumber: flightNumber,
  pickupDateTime: DateTime(2026, 3, 15, 10, 30),
);

Widget _wrap(Widget child, {List<BlocProvider> providers = const []}) {
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
  if (providers.isEmpty) return app;
  return MultiBlocProvider(providers: providers, child: app);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeAuthEvent());
  });

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('AssignmentDialog title shows client name, not the ride id', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      _wrap(
        AssignmentDialog(
          ride: _ride(),
          driverLabel: 'Driver Hans',
          driverId: 'driver-1',
          conflicts: const [],
          onConfirm: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Assign Ride · Max Mustermann'), findsOneWidget);
    expect(find.textContaining(_idPrefix), findsNothing);
  });

  testWidgets(
    'BulkReassignDialog title shows the first ride client name, not the id',
    (tester) async {
      useTallViewport(tester);
      final rideBloc = _MockRideBloc();
      final scheduleBloc = _MockScheduleBloc();
      final ride = _ride(driverId: 'driver-1');
      when(() => rideBloc.state).thenReturn(RideState.loaded([ride]));
      when(() => rideBloc.add(any())).thenAnswer((_) {});
      when(() => scheduleBloc.state).thenReturn(
        ScheduleState.loaded([
          TestFixtures.scheduleDay(id: 'sd-1', driverId: 'driver-1'),
          TestFixtures.scheduleDay(id: 'sd-2', driverId: 'driver-2'),
        ]),
      );

      await tester.pumpWidget(
        _wrap(
          BulkReassignDialog(
            fromDriverId: 'driver-1',
            fromDriverLabel: 'Driver Hans',
            rides: [ride],
          ),
          providers: [
            BlocProvider<RideBloc>.value(value: rideBloc),
            BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Reassign ride · Max Mustermann'), findsOneWidget);
      expect(find.textContaining(_idPrefix), findsNothing);
    },
  );

  testWidgets(
    'ChatScreen subtitle shows the pickup date/time, not the ride id',
    (tester) async {
      useTallViewport(tester);
      final authBloc = _MockAuthBloc();
      final apiClient = _MockApiClient();
      when(() => authBloc.add(any())).thenAnswer((_) {});
      when(() => authBloc.state).thenReturn(
        AuthState.authenticated(
          TestFixtures.driver(id: 'driver-1', name: 'Driver Hans'),
        ),
      );
      when(() => authBloc.apiClient).thenReturn(apiClient);
      when(
        () => apiClient.get(any()),
      ).thenAnswer((_) async => http.Response('[]', 200));

      await tester.pumpWidget(
        _wrap(
          ChatScreen(ride: _ride(driverId: 'driver-1')),
          providers: [BlocProvider<AuthBloc>.value(value: authBloc)],
        ),
      );
      await tester.pump();

      expect(find.text('Online · ride at 15.03 10:30'), findsOneWidget);
      expect(find.textContaining(_idPrefix), findsNothing);
    },
  );

  testWidgets(
    'FlightScreen linked-ride cell shows the client name without an id prefix',
    (tester) async {
      useTallViewport(tester);
      final rideBloc = _MockRideBloc();
      final flightService = _MockFlightService();
      final ride = _ride(flightNumber: 'LH1671');
      when(() => rideBloc.state).thenReturn(RideState.loaded([ride]));
      when(() => rideBloc.add(any())).thenAnswer((_) {});
      when(
        () => flightService.getMunichArrivals(hours: any(named: 'hours')),
      ).thenAnswer(
        (_) async => [
          FlightData(
            icao24: 'abc123',
            firstSeen: 1770000000,
            estDepartureAirport: 'FRA',
            lastSeen: 1770007200,
            estArrivalAirport: 'MUC',
            callsign: 'LH1671',
          ),
        ],
      );
      when(
        () => flightService.getMunichDepartures(hours: any(named: 'hours')),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        _wrap(
          FlightScreen(flightService: flightService),
          providers: [BlocProvider<RideBloc>.value(value: rideBloc)],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Max Mustermann'), findsOneWidget);
      expect(find.textContaining('#$_idPrefix'), findsNothing);
    },
  );
}
