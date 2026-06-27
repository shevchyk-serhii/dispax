// Regression test for the iOS crash "Could not find the correct
// Provider<RideBloc> above this ClientMapScreen widget".
//
// The app's RideBloc is provided below the root Navigator (in AppRoot), so a
// plain `MaterialPageRoute(builder: (_) => ClientMapScreen(...))` builds the
// screen in a context above the provider and crashes when ClientMapScreen reads
// RideBloc. `ClientMapScreen.route` fixes this by re-exposing the SAME bloc
// instance via BlocProvider.value inside the pushed route.
//
// This test inspects the route's built subtree directly (without rendering the
// Mapbox map) and asserts:
//   1. the route wraps ClientMapScreen in a BlocProvider<RideBloc>, and
//   2. it reuses the existing bloc instance (NOT a fresh one — a new bloc would
//      silently break live tracking).
//
// Mutation check: drop the BlocProvider wrapper in `ClientMapScreen.route` and
// this test fails (no BlocProvider<RideBloc> in the subtree); restore it and it
// passes.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/screens/client_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

void main() {
  testWidgets(
    'ClientMapScreen.route wraps the screen in BlocProvider with the same RideBloc',
    (tester) async {
      final rideBloc = _MockRideBloc();

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<RideBloc>.value(
            value: rideBloc,
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final route =
          ClientMapScreen.route(capturedContext, rideId: 'ride-1')
              as MaterialPageRoute<void>;

      // Build the route's subtree without mounting it (avoids spinning up the
      // Mapbox map / location services).
      final built = route.builder(capturedContext);

      // The top of the route subtree must re-provide RideBloc, otherwise
      // ClientMapScreen crashes when it reads RideBloc.
      expect(
        built,
        isA<BlocProvider<RideBloc>>(),
        reason: 'route() must wrap ClientMapScreen in a BlocProvider<RideBloc>',
      );

      final provider = built as BlocProvider<RideBloc>;
      expect(provider.child, isA<ClientMapScreen>());
      expect((provider.child as ClientMapScreen).rideId, 'ride-1');
    },
  );
}
