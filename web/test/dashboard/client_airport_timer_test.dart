// Regression: the client MyRidesTab only showed the AirportEntryTimer for
// airport transfers in `assigned`/`inProgress`. A `confirmed` (or `handedOff`)
// airport ride is still active and upcoming, so the client got no
// departure-time alert for it and could miss the flight. The timer must show
// for assigned/confirmed/inProgress/handedOff.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/client/client_dashboard.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/flight_management/widgets/airport_entry_timer.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

Person _client() => Person(
  id: 'client-self-1',
  name: 'Bruno Aldi',
  email: 'bruno@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
);

Ride _airportRide(RideStatus status) => Ride(
  id: 'ride-${status.value}',
  clientId: 'client-self-1',
  creatorId: 'u1',
  companyId: 'company-1',
  pickupDateTime: DateTime.now().add(const Duration(hours: 3)),
  from: const Location(address: 'Home'),
  to: const Location(address: 'MUC Terminal 2'),
  clientName: 'Bruno Aldi',
  status: status,
  isAirportTransfer: true,
  isArrival: false,
  flightTime: DateTime.now().add(const Duration(hours: 4)),
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeRideEvent()));

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    when(() => rideBloc.add(any())).thenAnswer((_) {});
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RideBloc>.value(value: rideBloc),
      ],
      child: const Scaffold(body: MyRidesTab()),
    ),
  );

  Future<void> pumpWith(WidgetTester tester, RideStatus status) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(
      () => rideBloc.state,
    ).thenReturn(RideState.loaded([_airportRide(status)]));
    await tester.pumpWidget(host());
    await tester.pump();
  }

  testWidgets('shows the airport entry timer for a CONFIRMED transfer', (
    tester,
  ) async {
    await pumpWith(tester, RideStatus.confirmed);
    expect(find.byType(AirportEntryTimer), findsOneWidget);
  });

  testWidgets('shows the airport entry timer for a HANDED-OFF transfer', (
    tester,
  ) async {
    await pumpWith(tester, RideStatus.handedOff);
    expect(find.byType(AirportEntryTimer), findsOneWidget);
  });

  testWidgets('still shows the timer for an ASSIGNED transfer', (tester) async {
    await pumpWith(tester, RideStatus.assigned);
    expect(find.byType(AirportEntryTimer), findsOneWidget);
  });
}
