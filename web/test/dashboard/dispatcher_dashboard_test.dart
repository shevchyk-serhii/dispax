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
  // TodayRidesScreen (screen 30), DriverMapScreen (screen 29), and
  // CalendarScheduleScreen (screen 31) depend on WebSocketService,
  // LocationService, and Mapbox platform channels that are not available in the
  // headless test environment. These screens throw on initState or during their
  // first build. Tap-navigation assertions that require switching to those
  // screens are therefore skipped; the tests below confirm only the bottom-nav
  // label composition and the More-menu grid contents which are safe to render.

  // ---------------------------------------------------------------------------
  // Mobile — canDrive=true: exact nav order
  //   0=Home | 1=Calendar | 2=My Rides | 3=New Ride | 4=More | 5=Billing
  // ---------------------------------------------------------------------------
  testWidgets('mobile nav (canDrive=true): nav positions are '
      '0=Home 1=Calendar 2=MyRides 3=NewRide 4=More 5=Billing', (tester) async {
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
    expect(labels[5], equals('Billing'));
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
  //   0=Home | 1=Schedule | 2=Analytics | 3=New Ride | 4=More | 5=Billing
  // ---------------------------------------------------------------------------
  testWidgets('mobile nav (canDrive=false): nav positions are '
      '0=Home 1=Schedule 2=Analytics 3=NewRide 4=More 5=Billing', (
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
    expect(labels[5], equals('Billing'));
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
  // Mobile — nav index consistency: More at pos 5 (canDrive=true) / pos 4 (canDrive=false),
  // Billing at pos 6 (canDrive=true) / pos 5 (canDrive=false).
  // ---------------------------------------------------------------------------
  testWidgets(
    'mobile nav (canDrive=false): "More" is at pos 4 and "Billing" is at pos 5',
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
        equals('Billing'),
        reason: '"Billing" must be at nav position 5 (canDrive=false)',
      );
    },
  );

  testWidgets(
    'mobile nav (canDrive=true): "More" is at pos 4 and "Billing" is at pos 5',
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
        equals('Billing'),
        reason: '"Billing" must be at nav position 5 (canDrive=true)',
      );
    },
  );
}
