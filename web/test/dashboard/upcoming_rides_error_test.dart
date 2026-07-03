// Regression guard for the "Null check operator used on a null value" crash on
// the driver's Upcoming screen.
//
// An error RideState can reach the UI with a null errorMessage (e.g. after a
// RideState.copyWith that scopes the rides while leaving the error status set —
// see the sentinel comment in ride_state.dart). UpcomingRidesScreen rendered
// that message with `rideState.errorMessage!` in two places (the body's
// ErrorDisplayWidget and the BlocListener snackbar), so a null message threw and
// crashed the screen. Its twin, TodayRidesScreen, already guards both with
// `rideErrorMessageOrFallback`. These tests pin the same safety on Upcoming.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/driver/upcoming_rides_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    when(() => authBloc.state).thenReturn(const AuthState());
    when(() => authBloc.apiClient).thenReturn(_MockApiClient());
  });

  tearDown(() {
    authBloc.close();
    rideBloc.close();
  });

  Future<void> pumpScreen(WidgetTester tester, RideState state) async {
    whenListen(rideBloc, Stream<RideState>.empty(), initialState: state);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RideBloc>.value(value: rideBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const UpcomingRidesScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'error state with a null errorMessage renders the fallback, never crashes',
    (tester) async {
      // An error state reached via copyWith scoping: status == error but the
      // message was dropped to null. Before the fix this threw at
      // `rideState.errorMessage!`.
      const state = RideState(
        status: RideStateStatus.error,
        rides: [],
        errorMessage: null,
      );

      await pumpScreen(tester, state);

      // No exception was thrown building the body.
      expect(tester.takeException(), isNull);
      // The localized fallback is shown instead of crashing.
      expect(find.text('Failed to load rides'), findsOneWidget);
    },
  );

  // Error-UX: the screen must route the error through friendlyError. A typed
  // ApiException cause renders the localized friendly text; the raw
  // 'ApiException:' string must never reach the UI.
  testWidgets(
    'an ApiException cause renders the friendly localized text, not the raw exception',
    (tester) async {
      final state = RideState(
        status: RideStateStatus.error,
        rides: const [],
        errorMessage: 'Failed to load rides: ApiException: boom (500)',
        error: ApiException('boom', statusCode: 500),
      );

      await pumpScreen(tester, state);

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Something went wrong on our side. Please try again in a moment.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('ApiException'),
        findsNothing,
        reason: 'raw exception text must never reach the UI',
      );
    },
  );

  testWidgets('a raw technical message collapses to the generic text', (
    tester,
  ) async {
    const state = RideState(
      status: RideStateStatus.error,
      rides: [],
      errorMessage: 'Boom: server exploded',
    );

    await pumpScreen(tester, state);

    expect(tester.takeException(), isNull);
    expect(find.text('Something went wrong. Please try again.'), findsWidgets);
    expect(find.text('Boom: server exploded'), findsNothing);
  });
}
