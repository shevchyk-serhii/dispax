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
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/schedule_management/models/calendar_share.dart';
import 'package:dispax/modules/schedule_management/services/calendar_share_service.dart';
import 'package:dispax/dashboard/driver/calendar/multi_column_view_widget.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

class _MockCalendarShareService extends Mock implements CalendarShareService {}

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
  List<CalendarShareGrant> externalShares = const [],
  CalendarShareService? shareService,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: Scaffold(
        body: MultiColumnViewWidget(
          selectedDay: selectedDay ?? DateTime(2026, 6, 22),
          drivers: drivers,
          externalShares: externalShares,
          shareService: shareService,
          onRideSelected: onRideSelected ?? (_) {},
        ),
      ),
    ),
  );
}

CalendarShareGrant _externalGrant({
  String id = 'grant-1',
  String grantorName = 'Anna External',
  String grantorCompanyName = 'External GmbH',
}) {
  return CalendarShareGrant(
    id: id,
    grantorName: grantorName,
    grantorCompanyName: grantorCompanyName,
    granteeName: 'Me',
    granteeCompanyName: 'My GmbH',
    createdAt: DateTime.utc(2026, 6, 1),
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
    // The board issues several GETs (rides + company shifts) — collect them
    // all and assert on the rides one.
    final capturedPaths = <String>[];
    when(() => apiClient.get(any())).thenAnswer((invocation) async {
      capturedPaths.add(invocation.positionalArguments[0] as String);
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

    final ridesPath = capturedPaths.firstWhere(
      (p) => p.contains('driverIds='),
      orElse: () => '',
    );
    expect(ridesPath, contains('driverIds=abc,xyz'));
    expect(ridesPath, contains('from=2026-06-22'));
    // The company shifts for the day are fetched in the same pass.
    expect(
      capturedPaths.any((p) => p.contains('/schedules/day/2026-06-22')),
      isTrue,
    );
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

  // ── Driver-column day timeline (shift regions + ride blocks) ───────────────

  group('driver column timeline', () {
    Map<String, dynamic> shiftJson({
      String id = 'shift-1',
      String driverId = 'driver-1',
      String date = '2026-06-22',
      String start = '14:00',
      String end = '22:00',
    }) {
      return {
        'id': id,
        'driverId': driverId,
        'companyId': 'company-1',
        'date': date,
        'startTime': start,
        'endTime': end,
        'status': 'Scheduled',
        'createdAt': '2026-06-01T00:00:00.000Z',
        'updatedAt': '2026-06-01T00:00:00.000Z',
      };
    }

    void stubPaths({
      List<Map<String, dynamic>> shifts = const [],
      List<Map<String, dynamic>> rides = const [],
    }) {
      when(() => apiClient.get(any())).thenAnswer((invocation) async {
        final path = invocation.positionalArguments[0] as String;
        if (path.contains('/schedules/day/')) {
          return http.Response(jsonEncode(shifts), 200);
        }
        return http.Response(jsonEncode(rides), 200);
      });
    }

    testWidgets(
      'a company driver with a shift gets a stretched availability region',
      (tester) async {
        tester.view.physicalSize = const Size(1800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        stubPaths(shifts: [shiftJson()]);

        await tester.pumpWidget(
          _buildTestWidget(
            authBloc: authBloc,
            drivers: [_driver(name: 'Hans Müller')],
            selectedDay: DateTime(2026, 6, 22),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final region = find.byKey(
          const ValueKey('driver-shift-region-shift-1'),
        );
        expect(region, findsOneWidget);
        expect(find.text('14:00–22:00'), findsOneWidget);
        expect(find.text('Available'), findsOneWidget);
        // 8h of the 17h window: a stretched region, not a chip.
        expect(tester.getSize(region).height, greaterThan(100));
      },
    );

    testWidgets('rides render as tappable time blocks on the timeline', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      stubPaths(
        shifts: [shiftJson()],
        rides: [
          {
            ..._rideJson(id: 'r1', driverId: 'driver-1'),
            'pickupDateTime': '2026-06-22T15:00:00.000',
          },
        ],
      );

      dynamic tapped;
      await tester.pumpWidget(
        _buildTestWidget(
          authBloc: authBloc,
          drivers: [_driver(name: 'Hans Müller')],
          selectedDay: DateTime(2026, 6, 22),
          onRideSelected: (ride) => tapped = ride,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final block = find.byKey(const ValueKey('board-ride-r1'));
      expect(block, findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);

      await tester.tap(block);
      expect(tapped, isNotNull);
    });

    testWidgets(
      'shift fetch failure degrades to no availability regions, rides intact',
      (tester) async {
        tester.view.physicalSize = const Size(1800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => apiClient.get(any())).thenAnswer((invocation) async {
          final path = invocation.positionalArguments[0] as String;
          if (path.contains('/schedules/day/')) {
            return http.Response('boom', 500);
          }
          return http.Response(
            jsonEncode([
              {
                ..._rideJson(id: 'r1', driverId: 'driver-1'),
                'pickupDateTime': '2026-06-22T15:00:00.000',
              },
            ]),
            200,
          );
        });

        await tester.pumpWidget(
          _buildTestWidget(
            authBloc: authBloc,
            drivers: [_driver(name: 'Hans Müller')],
            selectedDay: DateTime(2026, 6, 22),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('board-ride-r1')), findsOneWidget);
        expect(find.text('Available'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ── External shared-calendar columns ────────────────────────────────────────

  group('external shared-calendar columns', () {
    late _MockCalendarShareService shareService;

    setUp(() {
      shareService = _MockCalendarShareService();
      when(
        () => apiClient.get(any()),
      ).thenAnswer((_) async => http.Response('[]', 200));
    });

    testWidgets(
      'renders an extra column with the grantor name, company, shift and busy slot',
      (tester) async {
        tester.view.physicalSize = const Size(1800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final day = DateTime(2026, 6, 22);
        when(
          () => shareService.getSharedCalendar(
            'grant-1',
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer(
          (_) async => SharedCalendar(
            grantId: 'grant-1',
            grantorName: 'Anna External',
            shifts: [
              SharedShift(
                date: day,
                startTime: '08:00',
                endTime: '16:00',
                status: 'Scheduled',
              ),
            ],
            busySlots: [
              SharedBusySlot(
                start: day.add(const Duration(hours: 9)),
                end: day.add(const Duration(hours: 10)),
                kind: 'Ride',
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          _buildTestWidget(
            authBloc: authBloc,
            drivers: [_driver(name: 'Hans Müller')],
            selectedDay: day,
            externalShares: [_externalGrant()],
            shareService: shareService,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Hans Müller'), findsOneWidget);
        expect(find.text('Anna External'), findsOneWidget);
        expect(find.text('External GmbH'), findsOneWidget);
        // The shift stretches as an availability region on the day timeline…
        expect(
          find.byKey(const ValueKey('share-shift-region-08:00')),
          findsOneWidget,
        );
        expect(find.text('08:00–16:00'), findsOneWidget);
        expect(find.text('Available'), findsOneWidget);
        // …with the busy slot lying on top of it as a block.
        expect(
          find.byKey(const ValueKey('share-busy-block-0')),
          findsOneWidget,
        );
        expect(find.textContaining('Busy'), findsOneWidget);
      },
    );

    testWidgets(
      'the availability region is time-proportional: an 8h shift spans ~8/17 of the timeline',
      (tester) async {
        tester.view.physicalSize = const Size(1800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final day = DateTime(2026, 6, 22);
        when(
          () => shareService.getSharedCalendar(
            'grant-1',
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer(
          (_) async => SharedCalendar(
            grantId: 'grant-1',
            grantorName: 'Anna External',
            shifts: [
              SharedShift(
                date: day,
                startTime: '14:00',
                endTime: '22:00',
                status: 'Scheduled',
              ),
            ],
            busySlots: const [],
          ),
        );

        await tester.pumpWidget(
          _buildTestWidget(
            authBloc: authBloc,
            drivers: [_driver(name: 'Hans Müller')],
            selectedDay: day,
            externalShares: [_externalGrant()],
            shareService: shareService,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final region = tester.getSize(
          find.byKey(const ValueKey('share-shift-region-14:00')),
        );
        // 8 hours of a 17-hour window (06:00–23:00): the band must be a large
        // stretched region (hundreds of px on this viewport), not a one-line
        // chip like before.
        expect(region.height, greaterThan(100));
      },
    );

    testWidgets('a failing share degrades only its own column', (tester) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        () => shareService.getSharedCalendar(
          'grant-1',
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenThrow(ApiException('boom'));

      await tester.pumpWidget(
        _buildTestWidget(
          authBloc: authBloc,
          drivers: [_driver(name: 'Hans Müller')],
          externalShares: [_externalGrant()],
          shareService: shareService,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Driver column intact, external column shows its own error marker.
      expect(find.text('Hans Müller'), findsOneWidget);
      expect(find.text('No rides'), findsOneWidget);
      expect(find.text('Anna External'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('external shares count toward the wide-screen column cap', (
      tester,
    ) async {
      final drivers = List.generate(
        3,
        (i) => _driver(id: 'driver-$i', name: 'Driver $i'),
      );
      when(
        () => shareService.getSharedCalendar(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer(
        (_) async => const SharedCalendar(
          grantId: 'grant-1',
          grantorName: 'Anna External',
          shifts: [],
          busySlots: [],
        ),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          authBloc: authBloc,
          drivers: drivers,
          externalShares: [_externalGrant()],
          shareService: shareService,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // 3 drivers fill the cap → the external column overflows into "+1 more".
      expect(find.text('Anna External'), findsNothing);
      expect(find.textContaining('+1 more'), findsOneWidget);
    });
  });

  // ── didUpdateWidget: no refetch on equal-content rebuilds ──────────────────

  group('parent rebuilds with equal content', () {
    testWidgets(
      'does NOT refetch (no spinner flash) when the parent rebuilds with '
      'equal-content but new-instance lists',
      (tester) async {
        tester.view.physicalSize = const Size(1800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var getCalls = 0;
        when(() => apiClient.get(any())).thenAnswer((_) async {
          getCalls++;
          return http.Response('[]', 200);
        });
        final shareService = _MockCalendarShareService();
        when(
          () => shareService.getSharedCalendar(
            any(),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer(
          (_) async => const SharedCalendar(
            grantId: 'grant-1',
            grantorName: 'Anna External',
            shifts: [],
            busySlots: [],
          ),
        );

        final day = DateTime(2026, 6, 22);
        await tester.pumpWidget(
          _buildTestWidget(
            authBloc: authBloc,
            drivers: [_driver(id: 'driver-1')],
            selectedDay: day,
            externalShares: [_externalGrant()],
            shareService: shareService,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final callsAfterFirstBuild = getCalls;
        expect(callsAfterFirstBuild, greaterThan(0));

        // The parent (calendar_schedule_screen) builds these lists FRESH on
        // every build, so didUpdateWidget always sees new instances. Rebuild
        // with equal content: same driver id, same grant id, same day.
        await tester.pumpWidget(
          _buildTestWidget(
            authBloc: authBloc,
            drivers: [_driver(id: 'driver-1')],
            selectedDay: day,
            externalShares: [_externalGrant()],
            shareService: shareService,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          getCalls,
          callsAfterFirstBuild,
          reason:
              'A rebuild with content-equal lists must not refetch the board '
              '(reference comparison made every parent rebuild flash the '
              'spinner and refetch everything)',
        );
        verify(
          () => shareService.getSharedCalendar(
            any(),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).called(1);
      },
    );

    testWidgets('still refetches when the driver set actually changes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var getCalls = 0;
      when(() => apiClient.get(any())).thenAnswer((_) async {
        getCalls++;
        return http.Response('[]', 200);
      });

      await tester.pumpWidget(
        _buildTestWidget(
          authBloc: authBloc,
          drivers: [_driver(id: 'a')],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final callsAfterFirstBuild = getCalls;

      await tester.pumpWidget(
        _buildTestWidget(
          authBloc: authBloc,
          drivers: [_driver(id: 'b')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        getCalls,
        greaterThan(callsAfterFirstBuild),
        reason: 'A real driver-set change must still trigger a refetch',
      );
    });
  });

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

    testWidgets('each card shows the pickup HH:mm in its header', (
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

      // The left time rail was removed (it was redundant and caused the card to
      // overflow on the right); the pickup time now comes from the compact card
      // header only.
      expect(find.text('14:00'), findsWidgets);
    });
  });
}
