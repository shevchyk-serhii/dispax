// Tests for MultiColumnViewWidget.
//
// The widget creates a RideService internally from context.read<AuthBloc>().apiClient,
// so we inject a MockAuthBloc that returns a MockApiClient. HTTP responses are
// stubbed on the ApiClient — the pattern mirrors dispatcher_dashboard_test.dart.

import 'dart:convert';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/dashboard/driver/calendar/multi_column_view_widget.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _rideJson({
  String id = 'ride-1',
  String driverId = 'driver-1',
  String clientName = 'Client',
}) {
  return {
    'id': id,
    'clientId': 'client-1',
    'creatorId': 'creator-1',
    'driverId': driverId,
    'companyId': 'company-1',
    'pickupDateTime': '2026-06-22T10:00:00.000',
    'from': {'address': 'Pickup St', 'latitude': 48.1, 'longitude': 11.5},
    'to': {'address': 'Dropoff St', 'latitude': 48.2, 'longitude': 11.6},
    'status': 'Assigned',
    'clientName': clientName,
    'isAirportTransfer': false,
    'isArrival': false,
    'driverApproaching': false,
  };
}

Person _driver({String id = 'driver-1', String name = 'Hans Müller'}) {
  return Person(
    id: id,
    name: name,
    email: '$id@example.com',
    role: PersonRole.driver,
    companyId: 'company-1',
    phone: '+491234567890',
  );
}

// ── Test widget builder ───────────────────────────────────────────────────────

Widget _buildTestWidget({
  required _MockAuthBloc authBloc,
  required List<Person> drivers,
  DateTime? selectedDay,
  void Function(dynamic)? onRideSelected,
}) {
  return MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: Scaffold(
        body: MultiColumnViewWidget(
          selectedDay: selectedDay ?? DateTime(2026, 6, 22),
          drivers: drivers,
          onRideSelected: onRideSelected ?? (_) {},
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUpAll(() {
    // No extra fallback values needed for these tests.
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(() => authBloc.state).thenReturn(
      AuthState.authenticated(_driver(id: 'dispatcher-1', name: 'Dispatcher')),
    );
  });

  // ── Column headers ─────────────────────────────────────────────────────────

  testWidgets('renders one column per driver headed by driver name', (
    tester,
  ) async {
    // Widen the viewport so 3 columns have enough room and do not overflow.
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final driver1 = _driver(id: 'driver-1', name: 'Hans Müller');
    final driver2 = _driver(id: 'driver-2', name: 'Anna Bauer');
    final driver3 = _driver(id: 'driver-3', name: 'Max Huber');

    // Stub: server returns rides for driver-1 and driver-2; driver-3 gets empty.
    when(() => apiClient.get(any())).thenAnswer((_) async {
      return http.Response(
        jsonEncode([
          _rideJson(id: 'r1', driverId: 'driver-1'),
          _rideJson(id: 'r2', driverId: 'driver-2'),
        ]),
        200,
      );
    });

    await tester.pumpWidget(
      _buildTestWidget(
        authBloc: authBloc,
        drivers: [driver1, driver2, driver3],
      ),
    );

    // FutureBuilder starts in waiting state — show progress indicator first.
    await tester.pump(); // trigger initState
    await tester.pumpAndSettle(); // wait for future to complete

    expect(find.text('Hans Müller'), findsOneWidget);
    expect(find.text('Anna Bauer'), findsOneWidget);
    expect(find.text('Max Huber'), findsOneWidget);
  });

  testWidgets('shows "+N more" indicator when more than 3 drivers are passed', (
    tester,
  ) async {
    // 5 drivers → 3 columns + "+2 more" banner.
    final drivers = List.generate(
      5,
      (i) => _driver(id: 'driver-$i', name: 'Driver $i'),
    );

    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    await tester.pumpWidget(
      _buildTestWidget(authBloc: authBloc, drivers: drivers),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // Column headers for first 3 drivers.
    expect(find.text('Driver 0'), findsOneWidget);
    expect(find.text('Driver 1'), findsOneWidget);
    expect(find.text('Driver 2'), findsOneWidget);
    // Driver 3 and 4 are NOT shown as columns.
    expect(find.text('Driver 3'), findsNothing);
    expect(find.text('Driver 4'), findsNothing);

    // "+2 more" indicator is visible.
    expect(find.textContaining('+2 more'), findsOneWidget);
  });

  testWidgets('3 drivers produces no +N more indicator', (tester) async {
    final drivers = List.generate(
      3,
      (i) => _driver(id: 'driver-$i', name: 'Driver $i'),
    );

    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    await tester.pumpWidget(
      _buildTestWidget(authBloc: authBloc, drivers: drivers),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // No "+N more" text when exactly 3 drivers.
    expect(find.textContaining('more'), findsNothing);
  });

  // ── Loading state ──────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator while waiting for rides', (
    tester,
  ) async {
    // Use a completer so we can check the loading state before it resolves.
    when(() => apiClient.get(any())).thenAnswer((_) async {
      // Simulate a slow response.
      await Future<void>.delayed(const Duration(seconds: 10));
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(
      _buildTestWidget(authBloc: authBloc, drivers: [_driver()]),
    );

    await tester.pump(); // start future

    // Still waiting — progress indicator must be visible.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Drain the timer so the test doesn't leak.
    await tester.pump(const Duration(seconds: 11));
  });

  // ── Empty column ────────────────────────────────────────────────────────────

  testWidgets('shows "No rides" for a driver with no rides on that day', (
    tester,
  ) async {
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    await tester.pumpWidget(
      _buildTestWidget(
        authBloc: authBloc,
        drivers: [_driver(name: 'Lonely Driver')],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('No rides'), findsOneWidget);
  });

  // ── Request URL ────────────────────────────────────────────────────────────

  testWidgets('passes correct driverIds and date to getRidesByDrivers', (
    tester,
  ) async {
    String? capturedPath;
    when(() => apiClient.get(any())).thenAnswer((invocation) async {
      capturedPath = invocation.positionalArguments[0] as String;
      return http.Response('[]', 200);
    });

    final driver1 = _driver(id: 'abc', name: 'Driver A');
    final driver2 = _driver(id: 'xyz', name: 'Driver B');

    await tester.pumpWidget(
      _buildTestWidget(
        authBloc: authBloc,
        drivers: [driver1, driver2],
        selectedDay: DateTime(2026, 6, 22),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(capturedPath, isNotNull);
    expect(capturedPath, contains('driverIds=abc,xyz'));
    expect(capturedPath, contains('from=2026-06-22'));
  });

  // ── Tenant isolation: API returns [] for foreign driver ────────────────────

  testWidgets(
    'renders empty column when server returns no rides for driver (tenant isolation)',
    (tester) async {
      // Simulate server returning [] for a foreign driver — no data should appear.
      when(
        () => apiClient.get(any()),
      ).thenAnswer((_) async => http.Response('[]', 200));

      final foreignDriver = _driver(id: 'foreign-id', name: 'Foreign Driver');

      await tester.pumpWidget(
        _buildTestWidget(authBloc: authBloc, drivers: [foreignDriver]),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Column header present (the driver is in the requested list), but no rides.
      expect(find.text('Foreign Driver'), findsOneWidget);
      expect(find.text('No rides'), findsOneWidget);
    },
  );

  // ── Compact board layout ───────────────────────────────────────────────────

  group('_DriverColumn — compact board layout', () {
    Map<String, dynamic> longRideJson() {
      return {
        'id': 'long-ride-1',
        'clientId': 'client-1',
        'creatorId': 'creator-1',
        'driverId': 'driver-1',
        'companyId': 'company-1',
        'pickupDateTime': '2026-06-22T14:00:00.000',
        'from': {
          'address': 'Flughafenstraße 100, Terminal 2, München-Flughafen',
          'latitude': 48.35,
          'longitude': 11.78,
        },
        'to': {
          'address': 'Maximilianstraße 1, München-Innenstadt, Bayern',
          'latitude': 48.14,
          'longitude': 11.58,
        },
        'status': 'Assigned',
        'clientName': 'BMWAG-HerrSchneiderVonMünchenGmbHLongName',
        'isAirportTransfer': true,
        'isArrival': true,
        'driverApproaching': false,
      };
    }

    testWidgets(
      'cards render without overflow in narrow viewport (compact regression)',
      (tester) async {
        // Force a narrow viewport that would have caused overflow before the fix.
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Two drivers → each column is ~200 px wide (400 / 2), well within the
        // old overflow trigger zone.
        final driver1 = _driver(id: 'driver-1', name: 'Hans Müller');
        final driver2 = _driver(id: 'driver-2', name: 'Anna Bauer');

        when(() => apiClient.get(any())).thenAnswer((_) async {
          return http.Response(jsonEncode([longRideJson()]), 200);
        });

        await tester.pumpWidget(
          _buildTestWidget(authBloc: authBloc, drivers: [driver1, driver2]),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // No RenderFlex overflow exceptions must occur.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('time rail renders HH:mm text beside each card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final driver1 = _driver(id: 'driver-1', name: 'Hans Müller');

      when(() => apiClient.get(any())).thenAnswer((_) async {
        return http.Response(jsonEncode([longRideJson()]), 200);
      });

      await tester.pumpWidget(
        _buildTestWidget(authBloc: authBloc, drivers: [driver1]),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // "14:00" must appear — either from the time rail or the compact card header.
      expect(find.text('14:00'), findsWidgets);
    });
  });
}
