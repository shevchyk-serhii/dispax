// Widget tests for payment method display in RideDetailsScreen.
//
// The screen shows a payment-status banner when ride.paymentStatus != null.
// The banner text is '$paymentStatus ($methodLabel)' when paymentMethod resolves
// to a known label; when paymentMethod is null the banner shows the status alone.
//
// Two cases:
//   (a) paymentMethod='Card' + paymentStatus='Pending' -> 'Credit Card' visible
//   (b) paymentMethod=null  + paymentStatus='Pending' -> '(Credit Card)' absent

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_details_screen.dart';
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

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// A Ride fixture that includes paymentStatus and paymentMethod. TestFixtures
/// does not expose paymentStatus, so we build the Ride directly here.
Ride _ride({required String? paymentMethod, String paymentStatus = 'Pending'}) {
  return Ride(
    id: 'ride-pay-1',
    clientId: 'client-1',
    creatorId: 'creator-1',
    companyId: 'company-1',
    pickupDateTime: DateTime(2026, 3, 15, 10, 0),
    from: const Location(address: 'Pickup St 1', latitude: 48.1, longitude: 11.5),
    to: const Location(address: 'Dropoff St 2', latitude: 48.2, longitude: 11.6),
    status: RideStatus.assigned,
    clientName: 'Test Client',
    paymentStatus: paymentStatus,
    paymentMethod: paymentMethod,
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockRideBloc rideBloc;
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    rideBloc = _MockRideBloc();
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.state).thenReturn(
      AuthState.authenticated(
        TestFixtures.driver(id: 'driver-1', name: 'Driver Hans'),
      ),
    );
    when(() => authBloc.apiClient).thenReturn(apiClient);
    // The screen calls getDriverProximity in a post-frame callback; stub it.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
    when(
      () => apiClient.put(any(), any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
  });

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildSubject(Ride ride) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: BlocProvider<RideBloc>.value(
        value: rideBloc,
        child: RideDetailsScreen(ride: ride),
      ),
    ),
  );

  testWidgets(
    'RideDetailsScreen shows "Credit Card" in payment banner when paymentMethod is Card',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        buildSubject(_ride(paymentMethod: 'Card')),
      );
      await tester.pump(); // settle post-frame callback

      expect(
        find.textContaining('Credit Card'),
        findsOneWidget,
        reason:
            'payment banner for Card method must contain the localized label "Credit Card"',
      );
    },
  );

  testWidgets(
    'RideDetailsScreen does not show "(Credit Card)" in banner when paymentMethod is null',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        buildSubject(_ride(paymentMethod: null)),
      );
      await tester.pump();

      expect(
        find.textContaining('Credit Card'),
        findsNothing,
        reason:
            'payment banner without a paymentMethod must not show any method label',
      );
    },
  );
}
