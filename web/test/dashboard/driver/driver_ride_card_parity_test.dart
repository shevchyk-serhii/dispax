// The driver ride card (DriverRideCard → DriverRideActionsRow) exposes the same
// role-appropriate actions as the dispatcher: on top of navigate/map/call/
// share/duplicate it now surfaces Chat, an explicit Details affordance, and Edit
// (for the driver who created the ride).
//
// Chat is gated to active rides (Assigned/InProgress), and Edit is gated to an
// editable ride (Requested/Assigned) that the current driver created — mirroring
// ride_details_screen._canEditRide minus the dispatcher branch.
//
// Mutation checks:
// - remove the chat button from DriverRideActionsRow → "chat invokes onChat" and
//   "chat icon shows for assigned" go red;
// - drop the `_chatAvailable` status gate → "chat hidden for requested" goes red;
// - remove the details button → "details invokes onViewDetails" goes red;
// - remove the edit button → "edit invokes onEditRide" goes red;
// - weaken `_canDriverEdit` to ignore the creator check → "edit hidden for a
//   non-creator driver" goes red.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/driver/today_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_fixtures.dart';

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
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(TestFixtures.driver(id: 'driver-1')));
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: SizedBox(width: 360, child: child)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Chat', () {
    testWidgets('chat icon shows for an assigned ride and invokes onChat', (
      tester,
    ) async {
      var chatTapped = 0;
      await pump(
        tester,
        DriverRideActionsRow(
          ride: TestFixtures.ride(status: RideStatus.assigned),
          isDark: false,
          onNavigate: () {},
          onChat: () => chatTapped++,
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      expect(chatTapped, 1);
    });

    testWidgets('chat icon shows for an in-progress ride', (tester) async {
      await pump(
        tester,
        DriverRideActionsRow(
          ride: TestFixtures.ride(status: RideStatus.inProgress),
          isDark: false,
          onNavigate: () {},
          onChat: () {},
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });

    testWidgets('chat icon is hidden for a requested ride', (tester) async {
      await pump(
        tester,
        DriverRideActionsRow(
          ride: TestFixtures.ride(status: RideStatus.requested),
          isDark: false,
          onNavigate: () {},
          onChat: () {},
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    });
  });

  group('Details', () {
    testWidgets('details icon shows and invokes onViewDetails', (tester) async {
      var detailsTapped = 0;
      await pump(
        tester,
        DriverRideActionsRow(
          ride: TestFixtures.ride(status: RideStatus.assigned),
          isDark: false,
          onNavigate: () {},
          onViewDetails: () => detailsTapped++,
        ),
      );

      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      expect(detailsTapped, 1);
    });
  });

  group('Edit', () {
    testWidgets('edit icon shows and invokes onEditRide', (tester) async {
      var editTapped = 0;
      await pump(
        tester,
        DriverRideActionsRow(
          ride: TestFixtures.ride(status: RideStatus.assigned),
          isDark: false,
          onNavigate: () {},
          onEditRide: () => editTapped++,
        ),
      );

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      expect(editTapped, 1);
    });

    testWidgets('edit icon is hidden when onEditRide is not wired', (
      tester,
    ) async {
      await pump(
        tester,
        DriverRideActionsRow(
          ride: TestFixtures.ride(status: RideStatus.assigned),
          isDark: false,
          onNavigate: () {},
        ),
      );

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets(
      'DriverRideCard shows edit for a ride the current driver created',
      (tester) async {
        await pump(
          tester,
          DriverRideCard(
            ride: TestFixtures.ride(
              status: RideStatus.assigned,
              creatorId: 'driver-1',
              driverId: 'driver-1',
            ),
            onEditRide: () {},
          ),
        );

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'DriverRideCard hides edit for a ride the driver did not create',
      (tester) async {
        await pump(
          tester,
          DriverRideCard(
            ride: TestFixtures.ride(
              status: RideStatus.assigned,
              creatorId: 'someone-else',
              driverId: 'driver-1',
            ),
            onEditRide: () {},
          ),
        );

        expect(find.byIcon(Icons.edit_outlined), findsNothing);
      },
    );

    testWidgets('DriverRideCard hides edit for a completed ride', (
      tester,
    ) async {
      await pump(
        tester,
        DriverRideCard(
          ride: TestFixtures.ride(
            status: RideStatus.completed,
            creatorId: 'driver-1',
            driverId: 'driver-1',
          ),
          onEditRide: () {},
        ),
      );

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });
}
