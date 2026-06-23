// Widget test for the driver's "Cancel Ride" button on RideDetailsScreen.
//
// Coverage gap this closes: the cancel-ride *logic* (backend, RideService HTTP
// layer, CancelRideDialog) was tested, but nothing exercised the driver's
// detail-screen flow end to end — the button rendering through
// RideActionsCard, the _cancelRide() handler showing the dialog, calling
// RideService.cancelRide(), and propagating the cancelled ride to the shared
// RideBloc via RideUpdated.
//
// The screen builds its own RideService from context.read<AuthBloc>().apiClient,
// so we stub the ApiClient (not the RideService) to get a faithful path through
// the real service.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/ride_details_screen.dart';
import 'package:dispax/widgets/common/cancel_ride_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _FakeRideEvent extends Fake implements RideEvent {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRideEvent());
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockRideBloc rideBloc;
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    rideBloc = _MockRideBloc();
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();

    when(() => rideBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.state).thenReturn(
      AuthState.authenticated(
        TestFixtures.driver(id: 'driver-1', name: 'Driver Hans'),
      ),
    );
    when(() => authBloc.apiClient).thenReturn(apiClient);
    // The screen calls getDriverProximity (GET) in a post-frame callback for
    // the non-client (driver) view; stub it so the screen renders cleanly.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
    // The cancel endpoint succeeds by default; individual tests can override.
    when(
      () => apiClient.put(any(), any()),
    ).thenAnswer((_) async => http.Response('{}', 200));
  });

  // The detail screen is tall; the default 800x600 test viewport pushes the
  // action card off the bottom, so tap() misses its buttons. Give the tests a
  // phone-sized viewport with room for the whole screen.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildSubject(Ride ride) => MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: BlocProvider<RideBloc>.value(
        value: rideBloc,
        child: RideDetailsScreen(ride: ride),
      ),
    ),
  );

  testWidgets(
    'Cancel Ride button is shown for an assigned ride viewed by the driver',
    (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        buildSubject(TestFixtures.ride(status: RideStatus.assigned)),
      );
      await tester.pump();

      expect(
        find.widgetWithText(TextButton, 'Cancel Ride'),
        findsOneWidget,
        reason: 'an assigned ride must offer the driver a way to cancel',
      );
    },
  );

  testWidgets('Cancel Ride button is hidden once the ride is in progress', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      buildSubject(TestFixtures.ride(status: RideStatus.inProgress)),
    );
    await tester.pump();

    expect(
      find.widgetWithText(TextButton, 'Cancel Ride'),
      findsNothing,
      reason: 'an in-progress ride can no longer be cancelled from this card',
    );
  });

  testWidgets(
    'tapping Cancel Ride, choosing a reason and confirming cancels the ride: '
    'it hits the cancel endpoint and pushes a cancelled RideUpdated',
    (tester) async {
      Map<String, dynamic>? sentBody;
      when(() => apiClient.put('/rides/ride-1/cancel', any())).thenAnswer((
        invocation,
      ) async {
        sentBody = invocation.positionalArguments[1] as Map<String, dynamic>;
        return http.Response('{}', 200);
      });

      useTallViewport(tester);
      await tester.pumpWidget(
        buildSubject(TestFixtures.ride(status: RideStatus.assigned)),
      );
      await tester.pump();

      // Open the cancel dialog from the driver's action card. The staff dialog
      // shows a fee TextField whose blinking cursor never settles, so drive the
      // animation with a bounded pump() instead of pumpAndSettle().
      await tester.tap(find.widgetWithText(TextButton, 'Cancel Ride'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CancelRideDialog), findsOneWidget);

      // Pick a (staff) reason: open the dropdown and select "Driver Unavailable".
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Driver Unavailable').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm — the dialog's confirm button is also labelled "Cancel Ride".
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Ride'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The cancel endpoint was hit with the canonical wire reason.
      verify(() => apiClient.put('/rides/ride-1/cancel', any())).called(1);
      expect(sentBody?['reason'], 'driver_unavailable');

      // The shared RideBloc received the cancelled ride so lists update.
      final captured = verify(
        () => rideBloc.add(captureAny(that: isA<RideUpdated>())),
      ).captured;
      expect(captured, hasLength(1));
      final event = captured.single as RideUpdated;
      expect(event.ride.id, 'ride-1');
      expect(event.ride.status, RideStatus.cancelled);
      expect(event.ride.cancellationReason, 'driver_unavailable');
    },
  );

  testWidgets('dismissing the cancel dialog leaves the ride untouched', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      buildSubject(TestFixtures.ride(status: RideStatus.assigned)),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel Ride'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The dialog's "Back" button returns null without cancelling.
    await tester.tap(find.widgetWithText(TextButton, 'Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verifyNever(() => apiClient.put(any(), any()));
    verifyNever(() => rideBloc.add(any(that: isA<RideUpdated>())));
  });
}
