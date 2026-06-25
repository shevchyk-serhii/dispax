// Widget tests for payment method display in the secretary ClientDetailScreen
// _buildRideCard method.
//
// The ride card shows Icons.payments_outlined + the localized label when
// PaymentMethod.labelForWire resolves; the row is absent when paymentMethod is
// null or unknown.
//
// Two cases:
//   (a) paymentMethod='Invoice' -> label 'Invoice' visible in the ride card
//   (b) paymentMethod=null      -> payment label absent

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_detail_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// ─── Local fakes / mocks ─────────────────────────────────────────────────────

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _FakeRideEvent extends Fake implements RideEvent {}

// ─── Test data ───────────────────────────────────────────────────────────────

Person _client() => Person(
  id: 'client-1',
  name: 'Test Client',
  email: 'client@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
);

/// Returns a minimal serialised ride JSON that the RideService will parse.
Map<String, dynamic> _rideJson({String? paymentMethod}) => {
  'id': 'ride-pay-1',
  'clientId': 'client-1',
  'creatorId': 'creator-1',
  'companyId': 'company-1',
  'pickupDateTime': '2026-03-15T10:00:00.000',
  'from': {'address': 'Pickup St 1', 'latitude': 48.1, 'longitude': 11.5},
  'to': {'address': 'Dropoff St 2', 'latitude': 48.2, 'longitude': 11.6},
  'status': 'Requested',
  'clientName': 'Test Client',
  'isAirportTransfer': false,
  'isArrival': false,
  'driverApproaching': false,
  if (paymentMethod != null) 'paymentMethod': paymentMethod,
};

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockApiClient api;
  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;

  setUp(() {
    api = _MockApiClient();
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    when(() => authBloc.apiClient).thenReturn(api);
    when(() => authBloc.state)
        .thenReturn(AuthState.authenticated(_client()));
    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => api.put(any(), any()))
        .thenAnswer((_) async => http.Response('{}', 200));
  });

  Widget host({String? paymentMethod}) {
    // ClientDetailScreen calls GET /rides/client/{id} to load the ride list.
    when(() => api.get(any())).thenAnswer(
      (_) async => http.Response(
        jsonEncode([_rideJson(paymentMethod: paymentMethod)]),
        200,
      ),
    );

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RideBloc>.value(value: rideBloc),
        ],
        child: ClientDetailScreen(client: _client()),
      ),
    );
  }

  testWidgets(
    'ClientDetailScreen ride card shows "Invoice" label when paymentMethod is Invoice',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host(paymentMethod: 'Invoice'));
      await tester.pumpAndSettle();

      expect(
        find.text('Invoice'),
        findsOneWidget,
        reason:
            'a ride card with paymentMethod=Invoice must show the label "Invoice"',
      );
    },
  );

  testWidgets(
    'ClientDetailScreen ride card does not show payment label when paymentMethod is null',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host(paymentMethod: null));
      await tester.pumpAndSettle();

      expect(find.text('Invoice'), findsNothing);
      expect(find.text('Credit Card'), findsNothing);
      expect(find.text('Cash'), findsNothing);
      expect(find.text('Payment'), findsNothing);
    },
  );
}
