// Regression: the client ride-history period filter (week/month) used
// `pickupDateTime.isAfter(start)`, which excludes a ride sitting exactly on the
// period start (midnight). Such a ride silently vanished from the filtered
// history. The fix uses `!isBefore(start)` (inclusive of the boundary).

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/client/client_ride_history_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/core/models/person.dart';
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

void main() {
  setUpAll(() => registerFallbackValue(_FakeRideEvent()));

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;

  // A completed ride sitting EXACTLY on the first instant of the current month
  // — the boundary the buggy isAfter() dropped.
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final boundaryRide = Ride(
    id: 'ride-boundary',
    clientId: 'client-self-1',
    creatorId: 'u1',
    companyId: 'company-1',
    pickupDateTime: monthStart,
    from: const Location(address: 'BOUNDARY-FROM'),
    to: const Location(address: 'BOUNDARY-TO'),
    clientName: 'Boundary Client',
    status: RideStatus.completed,
  );

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    when(() => rideBloc.state).thenReturn(RideState.loaded([boundaryRide]));
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
      child: const ClientRideHistoryScreen(),
    ),
  );

  testWidgets(
    'a completed ride exactly on the month boundary survives the Month filter',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // Visible under the default "All" filter (the past card shows the route).
      expect(find.text('BOUNDARY-FROM → BOUNDARY-TO'), findsOneWidget);

      // Switch to the Month filter.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.month));
      await tester.pumpAndSettle();

      // Must still be visible: the ride is at the month start (inclusive).
      expect(
        find.text('BOUNDARY-FROM → BOUNDARY-TO'),
        findsOneWidget,
        reason:
            'a ride at exactly the month start must not be dropped by the '
            'period filter',
      );
    },
  );
}
