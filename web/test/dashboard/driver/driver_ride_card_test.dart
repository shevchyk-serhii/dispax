import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_fixtures.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _driver() => Person(
  id: 'driver-1',
  name: 'Test Driver',
  email: 'driver@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  roles: {PersonRole.driver},
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_driver()));
  });

  /// Pumps [child] under the AuthBloc that [DriverRideCard]'s avatar row reads,
  /// at a fixed iPhone-ish width so the action buttons lay out as on device.
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: SizedBox(width: 360, child: child)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget card(Ride ride) => DriverRideCard(
    ride: ride,
    onConfirmRide: () {},
    onRejectRide: () {},
    onStartRide: () {},
    onCompleteRide: () {},
    onCallClient: () {},
  );

  group('DriverRideCard — detail parity across statuses', () {
    // Regression for the screenshot bug: the "next" (assigned) ride used to be
    // rendered by a minimalist card that omitted fare, payment method and the
    // action buttons. Every ride of the day now uses this detailed card, so an
    // assigned ride must surface all of them — not just the in-progress one.
    testWidgets('an assigned ride shows fare, payment method and actions', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        status: RideStatus.assigned,
        clientName: 'Herr Klein',
        price: 140,
        paymentMethod: 'Invoice',
      );

      await pump(tester, card(ride));

      // Fare (rendered without a "€" prefix — the euro icon carries it).
      expect(find.text('140'), findsOneWidget);
      // Payment method row is present and labelled.
      expect(find.byType(DriverPaymentRow), findsOneWidget);
      expect(find.text('Invoice'), findsOneWidget);
      // Status-aware actions for an assigned ride: Confirm + Reject + Navigate.
      expect(find.byType(DriverRideActionsRow), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('an in-progress ride shows fare, payment and the complete '
        'action', (tester) async {
      final ride = TestFixtures.ride(
        status: RideStatus.inProgress,
        clientName: 'Frau Meier',
        price: 140,
        paymentMethod: 'Invoice',
      );

      await pump(tester, card(ride));

      expect(find.text('140'), findsOneWidget);
      expect(find.text('Invoice'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
    });
  });

  group('DriverRideCard — airport flight info', () {
    testWidgets('shows the flight number for an airport ride', (tester) async {
      final ride = TestFixtures.ride(
        status: RideStatus.assigned,
        isAirportTransfer: true,
        flightNumber: 'LH1671',
        terminal: 'T2',
        gate: 'G18',
        flightStatus: 'On time',
      );

      await pump(tester, card(ride));

      expect(find.textContaining('LH1671'), findsOneWidget);
    });

    testWidgets('shows the terminal-entry time for an airport arrival', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        status: RideStatus.assigned,
        isAirportTransfer: true,
        isArrival: true,
        flightNumber: 'LH1671',
        optimalEntryTime: DateTime(2026, 6, 27, 17, 5),
      );

      await pump(tester, card(ride));

      // en default locale → "Entry at 17:05".
      expect(find.textContaining('17:05'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });
  });

  // These shared rows are reused by both the active and later ride cards.
  group('DriverEntryTimeRow', () {
    testWidgets('renders the entry time for an arrival with one', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        optimalEntryTime: DateTime(2026, 6, 27, 9, 40),
      );

      await pump(tester, DriverEntryTimeRow(ride: ride, isDark: false));

      expect(find.textContaining('09:40'), findsOneWidget);
    });

    testWidgets('self-hides when no entry time is present', (tester) async {
      final ride = TestFixtures.ride(isAirportTransfer: true, isArrival: true);

      await pump(tester, DriverEntryTimeRow(ride: ride, isDark: false));

      expect(find.byIcon(Icons.login), findsNothing);
    });
  });

  group('DriverArrivalTimeRow', () {
    testWidgets('shows the landing time for an airport ride', (tester) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightTime: DateTime(2026, 6, 27, 14, 5),
      );

      await pump(tester, DriverArrivalTimeRow(ride: ride, isDark: false));

      // en default → "Landing at 14:05".
      expect(find.textContaining('14:05'), findsOneWidget);
      expect(find.byIcon(Icons.flight_land), findsOneWidget);
    });

    testWidgets('shows the delay in minutes when the flight is late', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightScheduledTime: DateTime(2026, 6, 27, 14, 0),
        flightTime: DateTime(2026, 6, 27, 14, 30),
      );

      await pump(tester, DriverArrivalTimeRow(ride: ride, isDark: false));

      // "Landing at 14:30 • +30 min delay" (en).
      expect(find.textContaining('30'), findsWidgets);
      expect(find.textContaining('delay'), findsOneWidget);
    });

    testWidgets('self-hides without a flight time', (tester) async {
      final ride = TestFixtures.ride(isAirportTransfer: true, isArrival: true);

      await pump(tester, DriverArrivalTimeRow(ride: ride, isDark: false));

      expect(find.byIcon(Icons.flight_land), findsNothing);
    });

    testWidgets('labels the time as a forecast while the flight is airborne', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightStatus: 'departed', // still in the air → estimate, not fact
        flightTime: DateTime(2026, 6, 27, 14, 5),
      );

      await pump(tester, DriverArrivalTimeRow(ride: ride, isDark: false));

      // en: forecast → "Landing at 14:05" (NOT "Landed at").
      expect(find.textContaining('Landing at 14:05'), findsOneWidget);
      expect(find.textContaining('Landed at'), findsNothing);
    });

    testWidgets('labels the time as actual once the flight has landed', (
      tester,
    ) async {
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        isArrival: true,
        flightStatus: 'landed', // touched down → the time IS the actual landing
        flightTime: DateTime(2026, 6, 27, 14, 5),
      );

      await pump(tester, DriverArrivalTimeRow(ride: ride, isDark: false));

      // en: fact → "Landed at 14:05" (NOT the forecast "Landing at").
      expect(find.textContaining('Landed at 14:05'), findsOneWidget);
    });
  });

  // Screen-level test: locks in that the "Heute" tab renders EVERY ride of the
  // day with the same detailed [DriverRideCard]. The bug was that the second
  // (assigned) ride used to fall through to a minimalist card; this is the only
  // test that goes red if that per-status branching is re-introduced in
  // [_TodayRidesScreenState.buildBody].
  group('TodayRidesScreen — every Heute ride uses DriverRideCard', () {
    late _MockRideBloc rideBloc;

    Ride todayRide({
      required String id,
      required RideStatus status,
      double? price,
    }) {
      final now = DateTime.now();
      return TestFixtures.ride(
        id: id,
        status: status,
        // Scoped to the logged-in driver via ridesDrivenBy(...).
        driverId: 'driver-1',
        // Inside today's window so todayRidesFilter keeps it.
        pickupDateTime: DateTime(now.year, now.month, now.day, 11, 32),
        clientName: 'Frau Meier',
        price: price,
        paymentMethod: 'Invoice',
      );
    }

    setUp(() {
      rideBloc = _MockRideBloc();
    });

    Future<void> pumpScreen(WidgetTester tester, List<Ride> rides) async {
      when(() => rideBloc.state).thenReturn(RideState.loaded(rides));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RideBloc>.value(value: rideBloc),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TodayRidesScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an in-progress + an assigned ride both render a detailed '
        'card', (tester) async {
      await pumpScreen(tester, [
        todayRide(id: 'r1', status: RideStatus.inProgress, price: 140),
        todayRide(id: 'r2', status: RideStatus.assigned, price: 95),
      ]);

      // Both rides get the same detailed card — not a compact one for the
      // assigned ride.
      expect(find.byType(DriverRideCard), findsNWidgets(2));
      // The assigned ride surfaces its fare and its status-aware actions.
      expect(find.text('95'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });
  });
}
