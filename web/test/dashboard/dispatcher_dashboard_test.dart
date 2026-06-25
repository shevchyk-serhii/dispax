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
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/dashboard/dispatcher/dispatcher_dashboard.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// --- Fakes for registerFallbackValue ---

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeScheduleEvent extends Fake implements ScheduleEvent {}

class _FakeCreateRideFormEvent extends Fake implements CreateRideFormEvent {}

// --- Mock BLoCs ---

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockScheduleBloc extends MockBloc<ScheduleEvent, ScheduleState>
    implements ScheduleBloc {}

class _MockCreateRideFormBloc
    extends MockBloc<CreateRideFormEvent, CreateRideFormState>
    implements CreateRideFormBloc {}

class _MockApiClient extends Mock implements ApiClient {}

// --- Person fixtures ---

/// Dispatcher who also holds the driver role → canDrive == true.
Person _dispatcherWithDrive() => Person(
  id: 'disp-driver-1',
  name: 'Disp Driver',
  email: 'disp.driver@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher, PersonRole.driver},
);

/// Dispatcher without the driver role → canDrive == false.
Person _dispatcherOnly() => Person(
  id: 'disp-1',
  name: 'Dispatcher Anna',
  email: 'disp@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher},
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeScheduleEvent());
    registerFallbackValue(_FakeCreateRideFormEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockScheduleBloc scheduleBloc;
  late _MockCreateRideFormBloc createRideFormBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    scheduleBloc = _MockScheduleBloc();
    createRideFormBloc = _MockCreateRideFormBloc();
    apiClient = _MockApiClient();

    // Stub apiClient on authBloc so panels that call authBloc.apiClient don't throw.
    when(() => authBloc.apiClient).thenReturn(apiClient);

    // Stub every GET request to return an empty list — keeps panels happy.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    // RideBloc: idle loaded state, silently accept events.
    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(() => rideBloc.add(any())).thenAnswer((_) {});

    // ScheduleBloc: idle loaded state, silently accept events.
    when(() => scheduleBloc.state).thenReturn(ScheduleState.loaded(const []));
    when(() => scheduleBloc.add(any())).thenAnswer((_) {});

    // CreateRideFormBloc: default unmodified state.
    when(
      () => createRideFormBloc.state,
    ).thenReturn(CreateRideFormState.initial());
    when(() => createRideFormBloc.add(any())).thenAnswer((_) {});
  });

  /// Builds a [MaterialApp] with all required BLoCs for [DispatcherDashboard].
  Widget buildApp(Person user) {
    when(() => authBloc.state).thenReturn(AuthState.authenticated(user));

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RideBloc>.value(value: rideBloc),
          BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
          BlocProvider<CreateRideFormBloc>.value(value: createRideFormBloc),
        ],
        child: const DispatcherDashboard(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Case 1: "Driver Map" button is visible for a dispatcher who can drive
  // ---------------------------------------------------------------------------
  testWidgets(
    '"Driver Map" FilledButton is shown in split-view toolbar when canDrive == true',
    (tester) async {
      // Force the widget into split-view (>= 800 px logical).
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherWithDrive()));
      // Allow async initState work (ScheduleBloc/RideBloc events) to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.widgetWithText(FilledButton, 'Driver Map'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Case 2: "Driver Map" button is hidden for a pure dispatcher (no driver role)
  // ---------------------------------------------------------------------------
  testWidgets(
    '"Driver Map" text is absent in split-view toolbar when canDrive == false, '
    'but "Billing" button is still visible',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherOnly()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // "Driver Map" must not appear at all.
      expect(find.text('Driver Map'), findsNothing);

      // "Billing" confirms the toolbar was rendered (regression guard).
      expect(find.widgetWithText(FilledButton, 'Billing'), findsOneWidget);
    },
  );

  // ===========================================================================
  // Mobile bottom-nav layout tests (window < 800 px → mobile view)
  // ===========================================================================
  //
  // NOTE on tap-navigation tests: the IndexedStack builds all children eagerly.
  // TodayRidesScreen (screen 32), DriverMapScreen (screen 31), and
  // CalendarScheduleScreen (screen 33) depend on WebSocketService,
  // LocationService, and Mapbox platform channels that are not available in the
  // headless test environment. These screens throw on initState or during their
  // first build. Tap-navigation assertions that require switching to those
  // screens are therefore skipped; the tests below confirm only the bottom-nav
  // label composition and the More-menu grid contents which are safe to render.

  // ---------------------------------------------------------------------------
  // Mobile — canDrive=true: exact nav order
  //   0=Home | 1=Calendar | 2=My Rides | 3=New Ride | 4=More | 5=Settings
  // Settings replaced Billing as the last bottom-nav tab (Billing moved to More,
  // mirroring the driver dashboard's Settings-last layout).
  // ---------------------------------------------------------------------------
  testWidgets('mobile nav (canDrive=true): nav positions are '
      '0=Home 1=Calendar 2=MyRides 3=NewRide 4=More 5=Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp(_dispatcherWithDrive()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    final labels = nav.items.map((item) => item.label ?? '').toList();

    expect(labels.length, equals(6), reason: 'canDrive=true must have 6 tabs');
    expect(labels[0], equals('Home'));
    expect(labels[1], equals('Calendar'));
    expect(labels[2], equals('My Rides'));
    expect(labels[3], equals('New Ride'));
    expect(labels[4], equals('More'));
    expect(labels[5], equals('Settings'));
    // Billing is no longer a bottom-nav tab.
    expect(labels, isNot(contains('Billing')));
  });

  // ---------------------------------------------------------------------------
  // Mobile — canDrive=true: presence checks and relative ordering
  // ---------------------------------------------------------------------------
  testWidgets('mobile nav (canDrive=true): "Calendar" appears before "My Rides"; '
      '"Analytics" is absent from nav but present in More-menu', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp(_dispatcherWithDrive()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Both "Calendar" and "My Rides" must be in the bottom nav.
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Calendar'),
      ),
      findsOneWidget,
      reason: 'canDrive=true must show "Calendar" in bottom nav',
    );
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('My Rides'),
      ),
      findsOneWidget,
      reason: 'canDrive=true must show "My Rides" in bottom nav',
    );

    // Verify "Calendar" is at position 1 and "My Rides" is at position 2
    // (i.e., Calendar precedes My Rides).
    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    final labels = nav.items.map((item) => item.label ?? '').toList();
    expect(
      labels.indexOf('Calendar') < labels.indexOf('My Rides'),
      isTrue,
      reason: '"Calendar" (pos 1) must precede "My Rides" (pos 2)',
    );

    // "My Schedule" and "Schedule" must NOT be in the bottom nav (unified into "Calendar").
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('My Schedule'),
      ),
      findsNothing,
      reason:
          'canDrive=true must not show "My Schedule" (unified into Calendar)',
    );
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Schedule'),
      ),
      findsNothing,
      reason: 'canDrive=true must not show "Schedule" (unified into Calendar)',
    );

    // 'Analytics' must NOT be in the bottom nav (it moved to More-menu).
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Analytics'),
      ),
      findsNothing,
      reason: 'canDrive=true must hide "Analytics" from bottom nav',
    );

    // Navigate to the More menu (screen index 4) by tapping pos 4 'More'.
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('More'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The More-menu grid is lazy (GridView.builder): only items visible in the
    // viewport are built. 'Analytics' is near the end of a 27-item grid, so
    // we scroll the GridView until the Analytics label becomes visible.
    await tester.scrollUntilVisible(
      find.text('Analytics'),
      200.0,
      scrollable: find.byType(Scrollable).last,
    );

    // After scrolling, the 'Analytics' grid entry must be present.
    expect(
      find.text('Analytics'),
      findsOneWidget,
      reason: 'More-menu must have "Analytics" grid entry when canDrive=true',
    );
  });

  // ---------------------------------------------------------------------------
  // Mobile — canDrive=false: exact nav order
  //   0=Home | 1=Schedule | 2=Analytics | 3=New Ride | 4=More | 5=Settings
  // ---------------------------------------------------------------------------
  testWidgets('mobile nav (canDrive=false): nav positions are '
      '0=Home 1=Schedule 2=Analytics 3=NewRide 4=More 5=Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp(_dispatcherOnly()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    final labels = nav.items.map((item) => item.label ?? '').toList();

    expect(labels.length, equals(6), reason: 'canDrive=false must have 6 tabs');
    expect(labels[0], equals('Home'));
    expect(labels[1], equals('Schedule'));
    expect(labels[2], equals('Analytics'));
    expect(labels[3], equals('New Ride'));
    expect(labels[4], equals('More'));
    expect(labels[5], equals('Settings'));
    expect(labels, isNot(contains('Billing')));
  });

  // ---------------------------------------------------------------------------
  // Mobile — canDrive=false: no driver-only tabs
  // ---------------------------------------------------------------------------
  testWidgets(
    'mobile nav (canDrive=false): has "Analytics" tab, no "My Rides" or '
    '"My Schedule" tabs',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherOnly()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 'Analytics' must be in the bottom nav at position 2.
      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Analytics'),
        ),
        findsOneWidget,
        reason: 'canDrive=false must show "Analytics" in bottom nav',
      );

      // 'My Rides' must not appear in nav.
      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('My Rides'),
        ),
        findsNothing,
        reason: 'canDrive=false must not show "My Rides" in bottom nav',
      );

      // 'My Schedule' must not appear in nav.
      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('My Schedule'),
        ),
        findsNothing,
        reason: 'canDrive=false must not show "My Schedule" in bottom nav',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Mobile — nav index consistency: More at pos 4, Settings (the new last tab)
  // at pos 5, for both canDrive values.
  // ---------------------------------------------------------------------------
  testWidgets(
    'mobile nav (canDrive=false): "More" is at pos 4 and "Settings" is at pos 5',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherOnly()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      final labels = nav.items.map((item) => item.label ?? '').toList();

      expect(
        labels[4],
        equals('More'),
        reason: '"More" must be at nav position 4 (canDrive=false)',
      );
      expect(
        labels[5],
        equals('Settings'),
        reason: '"Settings" must be at nav position 5 (canDrive=false)',
      );
    },
  );

  testWidgets(
    'mobile nav (canDrive=true): "More" is at pos 4 and "Settings" is at pos 5',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherWithDrive()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      final labels = nav.items.map((item) => item.label ?? '').toList();

      expect(
        labels[4],
        equals('More'),
        reason: '"More" must be at nav position 4 (canDrive=true)',
      );
      expect(
        labels[5],
        equals('Settings'),
        reason: '"Settings" must be at nav position 5 (canDrive=true)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Mobile — More-menu grid contents after the refactor:
  //   * "Billing" now lives in the More grid (it left the bottom nav);
  //   * "Settings" is gone from the More grid (it moved to the bottom nav);
  //   * "My Rides" is NOT duplicated in the More grid (it is a bottom-nav tab
  //     when canDrive).
  // ---------------------------------------------------------------------------
  testWidgets(
    'mobile More-menu (canDrive=true): contains "Billing", omits "Settings", '
    'and does not duplicate "My Rides"',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherWithDrive()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Open the More menu.
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final grid = find.byType(Scrollable).last;

      // Billing now appears as a More-grid tile.
      await tester.scrollUntilVisible(
        find.text('Billing'),
        200.0,
        scrollable: grid,
      );
      expect(
        find.text('Billing'),
        findsOneWidget,
        reason: 'Billing must now be a More-grid tile',
      );

      // The grid is a lazy GridView.builder, so off-screen tiles are not built.
      // To prove "My Rides" and "Settings" are NOT in the grid, scroll the grid
      // all the way to the bottom (forcing every tile to build at least once as
      // it passes through the viewport) and assert they were never found.
      // scrollUntilVisible throws StateError when the target never appears, so a
      // *successful* scroll-to-find would mean the tile IS present (a failure).
      Future<bool> gridContains(String label) async {
        // Reset to the top so each search scans the full grid deterministically.
        await tester.drag(grid, const Offset(0, 2000));
        await tester.pump();
        try {
          await tester.scrollUntilVisible(
            find.descendant(of: grid, matching: find.text(label)),
            200.0,
            scrollable: grid,
            maxScrolls: 60,
          );
          return true;
        } on StateError {
          return false;
        }
      }

      expect(
        await gridContains('My Rides'),
        isFalse,
        reason: 'My Rides must not be duplicated in the More grid',
      );
      expect(
        await gridContains('Settings'),
        isFalse,
        reason: 'Settings must not be in the More grid anymore',
      );

      // Sanity: a tile that IS in the grid is found by the same helper, proving
      // the helper can actually detect presence (guards against a false-negative
      // where everything "passes" because the scan never works).
      expect(
        await gridContains('GDPR'),
        isTrue,
        reason: 'control: a real More-grid tile must be detected',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Mobile — the driver-schedules tile is localized as "Driver Schedules"
  // (l10n.driverSchedules), not the bare hardcoded "Schedules" it used to be.
  // ---------------------------------------------------------------------------
  testWidgets(
    'mobile More-menu: driver-schedules tile is "Driver Schedules" (localized), '
    'not the bare "Schedules"',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp(_dispatcherWithDrive()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final grid = find.byType(Scrollable).last;

      // The localized label is present...
      await tester.scrollUntilVisible(
        find.text('Driver Schedules'),
        200.0,
        scrollable: grid,
      );
      expect(
        find.text('Driver Schedules'),
        findsOneWidget,
        reason: 'driver-schedules tile must use l10n.driverSchedules',
      );

      // ...and the old bare "Schedules" label is gone. (Reset to top first so
      // the search scans the whole grid; the lazy grid only builds in-viewport
      // tiles, so a fully-scrolled scan that never finds it proves absence.)
      await tester.drag(grid, const Offset(0, 2000));
      await tester.pump();
      var foundBare = false;
      try {
        await tester.scrollUntilVisible(
          find.descendant(of: grid, matching: find.text('Schedules')),
          200.0,
          scrollable: grid,
          maxScrolls: 60,
        );
        foundBare = true;
      } on StateError {
        foundBare = false;
      }
      expect(
        foundBare,
        isFalse,
        reason: 'the bare hardcoded "Schedules" label must no longer appear',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Mobile — "Manage Clients" tile is present in the More grid so a dispatcher
  // can reach client creation. Verified for BOTH canDrive values because the
  // tile's screen index must stay stable regardless of the canDrive-gated
  // driver screens appended after it.
  // ---------------------------------------------------------------------------
  for (final entry in {
    'canDrive=true': true,
    'canDrive=false': false,
  }.entries) {
    testWidgets(
      'mobile More-menu (${entry.key}): contains a "Manage Clients" tile',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildApp(entry.value ? _dispatcherWithDrive() : _dispatcherOnly()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('More'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final grid = find.byType(Scrollable).last;
        await tester.scrollUntilVisible(
          find.text('Manage Clients'),
          200.0,
          scrollable: grid,
        );
        expect(
          find.text('Manage Clients'),
          findsOneWidget,
          reason:
              'More grid must expose a "Manage Clients" tile (${entry.key})',
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile — tapping the "Manage Clients" tile actually opens ClientListPanel.
  // This proves the tile's screenIndex points at the right IndexedStack child
  // (the index-shift guard): a wrong index would surface a different screen.
  // ---------------------------------------------------------------------------
  testWidgets(
    'mobile More-menu: tapping "Manage Clients" opens the client list panel',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // canDrive=false keeps the index just past the always-present screens, so
      // this also guards against the canDrive append shifting it.
      await tester.pumpWidget(buildApp(_dispatcherOnly()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final grid = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('Manage Clients'),
        200.0,
        scrollable: grid,
      );
      await tester.tap(find.text('Manage Clients'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // ClientListPanel renders its own search field with this hint and an
      // "add client" FAB — both confirm we landed on the right screen.
      expect(find.byType(ClientListPanel), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    },
  );
}
