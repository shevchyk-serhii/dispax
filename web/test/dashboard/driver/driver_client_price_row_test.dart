import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/widgets/avatar_circle.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_fixtures.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

Person _person(PersonRole role) => Person(
  id: 'user-1',
  name: 'Test User',
  email: 'user@example.com',
  role: role,
  companyId: 'company-1',
  roles: {role},
);

/// Pumps the driver ride card's client-name + fare row in isolation.
Future<void> pumpRow(
  WidgetTester tester, {
  String clientName = 'Test Client',
  double? price,
  bool clientHasAvatar = false,
}) async {
  final apiClient = _MockApiClient();
  // The avatar widget fetches bytes when the client has a photo; return null so
  // it falls back to initials without a real network call.
  when(() => apiClient.getBytes(any())).thenAnswer((_) async => null);

  final Ride ride = TestFixtures.ride(
    driverId: 'driver-1',
    status: RideStatus.assigned,
    clientName: clientName,
    price: price,
    clientHasAvatar: clientHasAvatar,
  );
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: DriverClientPriceRow(
              ride: ride,
              isDark: false,
              apiClient: apiClient,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DriverClientPriceRow', () {
    testWidgets('shows the client name', (tester) async {
      await pumpRow(tester, clientName: 'BMW AG - Herr Schneider');
      expect(find.text('BMW AG - Herr Schneider'), findsOneWidget);
    });

    testWidgets('shows a whole-euro fare without a trailing .0', (
      tester,
    ) async {
      await pumpRow(tester, price: 45.0);
      // The euro symbol is the Icons.euro icon; the text holds only the amount.
      expect(find.byIcon(Icons.euro), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('45.0'), findsNothing);
      // Regression: the amount text must NOT prefix '€' (that produced '€ €100').
      expect(find.text('€45'), findsNothing);
    });

    testWidgets('shows a fractional fare with its decimals', (tester) async {
      await pumpRow(tester, price: 45.5);
      expect(find.text('45.5'), findsOneWidget);
      expect(find.text('€45.5'), findsNothing);
    });

    testWidgets('renders nothing when there is no name and no price', (
      tester,
    ) async {
      await pumpRow(tester, clientName: 'Unknown Client', price: null);
      // 'Unknown Client' is the model fallback and must not be shown.
      expect(find.text('Unknown Client'), findsNothing);
      expect(find.byIcon(Icons.euro), findsNothing);
      // No client → no avatar either.
      expect(find.byType(AvatarCircle), findsNothing);
    });

    testWidgets('shows the price even when the client name is unknown', (
      tester,
    ) async {
      await pumpRow(tester, clientName: 'Unknown Client', price: 30.0);
      expect(find.text('Unknown Client'), findsNothing);
      expect(find.byIcon(Icons.euro), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('renders the client avatar next to the name', (tester) async {
      await pumpRow(tester, clientName: 'Anna Schmidt', clientHasAvatar: true);
      expect(find.byType(AvatarCircle), findsOneWidget);
      expect(find.text('Anna Schmidt'), findsOneWidget);
    });

    // Without an ambient AuthBloc (the isolation pump above) the row must not
    // crash and must not offer the photo affordance.
    testWidgets('no camera badge when there is no AuthBloc', (tester) async {
      await pumpRow(tester, clientName: 'Anna Schmidt');
      expect(find.byIcon(Icons.photo_camera), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('DriverClientPriceRow — client-photo affordance', () {
    late _MockAuthBloc authBloc;
    late _MockApiClient apiClient;

    setUp(() {
      authBloc = _MockAuthBloc();
      apiClient = _MockApiClient();
      when(() => apiClient.getBytes(any())).thenAnswer((_) async => null);
    });

    Future<void> pumpWithRole(
      WidgetTester tester,
      PersonRole role, {
      bool provisional = false,
    }) async {
      when(
        () => authBloc.state,
      ).thenReturn(AuthState.authenticated(_person(role)));
      final ride = TestFixtures.ride(
        driverId: 'driver-1',
        status: RideStatus.assigned,
        clientName: 'Anna Schmidt',
        clientProvisional: provisional,
      );
      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: DriverClientPriceRow(
                    ride: ride,
                    isDark: false,
                    apiClient: apiClient,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('driver sees a camera badge to attach a client photo', (
      tester,
    ) async {
      await pumpWithRole(tester, PersonRole.driver);
      expect(find.byIcon(Icons.photo_camera), findsOneWidget);
    });

    testWidgets('dispatcher sees a camera badge', (tester) async {
      await pumpWithRole(tester, PersonRole.dispatcher);
      expect(find.byIcon(Icons.photo_camera), findsOneWidget);
    });

    // A logged-in client viewing the row must NOT be able to edit a photo.
    testWidgets('client role sees no camera badge', (tester) async {
      await pumpWithRole(tester, PersonRole.client);
      expect(find.byIcon(Icons.photo_camera), findsNothing);
    });

    // Provisional (walk-in) rides render a different label and must not offer
    // photo editing here.
    testWidgets('no camera badge on a provisional ride even for a driver', (
      tester,
    ) async {
      await pumpWithRole(tester, PersonRole.driver, provisional: true);
      expect(find.byIcon(Icons.photo_camera), findsNothing);
    });
  });
}
