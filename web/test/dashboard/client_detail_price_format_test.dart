// Regression (billing currency consistency): the secretary client-detail ride
// card hardcoded the period currency format '€${price.toStringAsFixed(2)}'
// while the rest of the billing feature uses the German fmtEur formatter. The
// price must render through fmtEur.

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_detail_screen.dart';
import 'package:dispax/dashboard/superadmin/widgets/billing_widgets.dart'
    show fmtEur;
import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late MockApiClient api;
  late _MockAuthBloc authBloc;

  setUp(() {
    api = MockApiClient();
    authBloc = _MockAuthBloc();
    when(() => authBloc.apiClient).thenReturn(api);
    when(() => authBloc.state).thenReturn(AuthState.initial());
  });

  testWidgets('client ride card renders the price via fmtEur, not the '
      'hardcoded period format', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rideJson = {
      'id': 'ride-1',
      'clientId': 'person-1',
      'creatorId': 'creator-1',
      'companyId': 'company-1',
      'pickupDateTime': '2026-03-15T10:00:00.000',
      'from': {'address': 'Pickup St', 'latitude': 48.1, 'longitude': 11.5},
      'to': {'address': 'Dropoff St', 'latitude': 48.2, 'longitude': 11.6},
      'status': 'Completed',
      'clientName': 'John Doe',
      'price': 1234.56,
      'isAirportTransfer': false,
      'isArrival': false,
      'driverApproaching': false,
    };
    when(
      () => api.get(any()),
    ).thenAnswer((_) async => http.Response(jsonEncode([rideJson]), 200));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: ClientDetailScreen(client: TestFixtures.person()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(fmtEur(1234.56)), findsOneWidget);
    expect(find.text('€1234.56'), findsNothing);
  });
}
