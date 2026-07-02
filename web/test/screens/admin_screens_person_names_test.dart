// Regression guard: the admin screens (blacklist, ride pools, emergency
// reassignments, geofence alerts) must show the person names delivered by the
// enriched backend responses instead of shortened UUIDs. The raw id remains
// only as a fallback when the backend could not resolve a name.

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/blacklist_screen.dart';
import 'package:dispax/screens/emergency_reassignment_screen.dart';
import 'package:dispax/screens/geofence_screen.dart';
import 'package:dispax/screens/ride_pool_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

const _clientUuid = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const _driverUuid = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const _driver2Uuid = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.state).thenReturn(
      AuthState.authenticated(
        TestFixtures.person(
          id: 'dispatcher-1',
          name: 'Dispatcher',
          role: PersonRole.dispatcher,
        ),
      ),
    );
    when(() => authBloc.apiClient).thenReturn(apiClient);
    // Default: every unmocked path returns an empty list.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));
  });

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void mockGet(String path, Object body) {
    when(
      () => apiClient.get(path),
    ).thenAnswer((_) async => http.Response(jsonEncode(body), 200));
  }

  Widget wrap(Widget screen) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: Scaffold(body: screen),
    ),
  );

  testWidgets('BlacklistScreen shows client and driver names, not ids', (
    tester,
  ) async {
    useTallViewport(tester);
    mockGet('/blacklist', [
      {
        'id': 'b1',
        'companyId': 'co-1',
        'clientId': _clientUuid,
        'driverId': _driverUuid,
        'reason': 'No-show complaint',
        'createdBy': _driverUuid,
        'createdAt': '2026-03-15T10:00:00Z',
        'isActive': true,
        'clientName': 'Max Mustermann',
        'driverName': 'Hans Weber',
      },
    ]);

    await tester.pumpWidget(wrap(const BlacklistScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Client: Max Mustermann'), findsOneWidget);
    expect(find.text('Driver: Hans Weber'), findsOneWidget);
    expect(find.textContaining(_clientUuid.substring(0, 8)), findsNothing);
    expect(find.textContaining(_driverUuid.substring(0, 8)), findsNothing);
  });

  testWidgets(
    'RidePoolScreen card and details dialog show driver/client names',
    (tester) async {
      useTallViewport(tester);
      final pool = {
        'id': 'p1',
        'companyId': 'co-1',
        'name': null,
        'status': 'Open',
        'driverId': _driverUuid,
        'maxPassengers': 4,
        'currentPassengers': 1,
        'routeDirection': null,
        'scheduledTime': null,
        'createdAt': '2026-03-15T10:00:00Z',
        'createdBy': _driverUuid,
        'driverName': 'Hans Weber',
      };
      mockGet('/pools', [pool]);
      mockGet('/pools/p1', {
        'pool': pool,
        'members': [
          {
            'id': 'm1',
            'poolId': 'p1',
            'rideId': 'r1',
            'clientId': _clientUuid,
            'pickupOrder': 0,
            'status': 'Pending',
            'addedAt': '2026-03-15T10:00:00Z',
            'clientName': 'Max Mustermann',
          },
        ],
      });

      await tester.pumpWidget(wrap(const RidePoolScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Driver: Hans Weber'), findsOneWidget);
      expect(find.textContaining(_driverUuid.substring(0, 8)), findsNothing);

      // Open the details dialog: member row must show the client name.
      await tester.tap(find.text('Driver: Hans Weber'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Max Mustermann'), findsOneWidget);
      expect(find.textContaining(_clientUuid.substring(0, 8)), findsNothing);
    },
  );

  testWidgets('EmergencyReassignmentScreen shows driver names, not ids', (
    tester,
  ) async {
    useTallViewport(tester);
    mockGet('/emergency/reassignments', [
      {
        'id': 'e1',
        'rideId': 'r1',
        'companyId': 'co-1',
        'originalDriverId': _driverUuid,
        'newDriverId': _driver2Uuid,
        'reason': 'DriverIllness',
        'notes': null,
        'reassignedBy': _driverUuid,
        'createdAt': '2026-03-15T10:00:00Z',
        'status': 'REASSIGNED',
        'originalDriverName': 'Hans Weber',
        'newDriverName': 'Erika Musterfrau',
      },
    ]);

    await tester.pumpWidget(wrap(const EmergencyReassignmentScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Hans Weber'), findsOneWidget);
    expect(find.textContaining('Erika Musterfrau'), findsOneWidget);
    expect(find.textContaining(_driverUuid.substring(0, 8)), findsNothing);
    expect(find.textContaining(_driver2Uuid.substring(0, 8)), findsNothing);
  });

  testWidgets('GeofenceScreen alerts timeline shows the driver name', (
    tester,
  ) async {
    useTallViewport(tester);
    mockGet('/geofences/alerts?limit=20', [
      {
        'id': 'a1',
        'geofenceId': 'g1',
        'driverId': _driverUuid,
        'companyId': 'co-1',
        'alertType': 'entry',
        'geofenceName': 'Airport zone',
        'latitude': 48.35,
        'longitude': 11.78,
        'timestamp': '2026-03-15T10:00:00Z',
        'driverName': 'Hans Weber',
      },
    ]);

    await tester.pumpWidget(wrap(const GeofenceScreen()));
    await tester.pump();
    await tester.pump();

    // Alerts live on the second tab; pump the tab-switch animation through.
    await tester.tap(find.byType(Tab).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(() => apiClient.get('/geofences/alerts?limit=20')).called(1);
    expect(find.textContaining('Airport zone'), findsWidgets);
    expect(find.textContaining('Hans Weber'), findsOneWidget);
    expect(find.textContaining(_driverUuid.substring(0, 8)), findsNothing);
  });
}
