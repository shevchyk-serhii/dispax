// The dispatcher "Pending requests" header sits on a light surface. The
// NotificationBell defaults to a white icon, which is invisible there — only
// its red unread badge showed, looking detached next to the refresh button.
// The panel must pass a theme-aware (non-white) icon colour.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/dashboard/dispatcher/widgets/pending_rides_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/widgets/common/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    // unread-count load in initState — return 0 so no badge, no real network.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{"count":0}', 200));
  });

  Color bellIconColor(WidgetTester tester) {
    final icon = tester.widget<Icon>(find.byIcon(Icons.notifications_outlined));
    return icon.color!;
  }

  Future<void> pumpBell(WidgetTester tester, {required Color iconColor}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Scaffold(body: NotificationBell(iconColor: iconColor)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the bell icon in the colour it is given', (
    tester,
  ) async {
    const visible = Color(0xFF6B7280); // a grey, like onSurfaceVariant
    await pumpBell(tester, iconColor: visible);
    expect(bellIconColor(tester), visible);
  });

  testWidgets(
    'on a light surface the bell must not be left at the invisible white default',
    (tester) async {
      // This is the regression guard: the dispatcher header passes
      // colorScheme.onSurfaceVariant, which is never plain white.
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F2937));
      await pumpBell(tester, iconColor: scheme.onSurfaceVariant);
      expect(bellIconColor(tester), isNot(Colors.white));
    },
  );

  group('PendingRidesPanel header bell', () {
    late MockRideService mockRideService;
    late MockScheduleService mockScheduleService;
    late RideBloc rideBloc;
    late ScheduleBloc scheduleBloc;

    setUp(() {
      mockRideService = MockRideService();
      mockScheduleService = MockScheduleService();
      when(() => mockRideService.dispose()).thenReturn(null);
      when(() => mockRideService.getPendingRides()).thenAnswer((_) async => []);
      when(() => mockScheduleService.getScheduleForDate(any())).thenAnswer(
        (_) async => [TestFixtures.scheduleDay(driverId: 'driver-1')],
      );
      rideBloc = RideBloc(rideService: mockRideService);
      scheduleBloc = ScheduleBloc(scheduleService: mockScheduleService);
    });

    tearDown(() {
      rideBloc.close();
      scheduleBloc.close();
    });

    testWidgets('uses a visible (non-white) icon colour on the light header', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: authBloc),
                BlocProvider<RideBloc>.value(value: rideBloc),
                BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
              ],
              child: const PendingRidesPanel(),
            ),
          ),
        ),
      );
      await tester.pump();

      // The header NotificationBell must not keep the default white icon, or it
      // is invisible on the light surface (only the red badge would show).
      final bell = tester.widget<NotificationBell>(
        find.byType(NotificationBell),
      );
      expect(bell.iconColor, isNot(Colors.white));
    });
  });
}
