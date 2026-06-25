// Regression guard: clearing the From or To address must drop any previously
// fetched price estimate.
//
// Estimates are fetched in parallel per vehicle class once both addresses are
// set; the result is held in state.estimateBusiness / estimateVan and rendered
// directly by ClientBookScreen. Before the fix, FromAddressChanged /
// ToAddressChanged only updated the address — they never cleared the estimates.
// So emptying an address left the old price on screen even though the route was
// now incomplete (and the form invalid): a stale, misleading price.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/modules/ride_management/models/ride_estimate.dart';

void main() {
  const businessEstimate = RideEstimate(
    distanceKm: 25.0,
    durationMinutes: 30,
    estimatedPrice: 62.0,
    currency: 'EUR',
  );
  const vanEstimate = RideEstimate(
    distanceKm: 25.0,
    durationMinutes: 30,
    estimatedPrice: 88.0,
    currency: 'EUR',
  );

  // A populated form with both estimates already fetched for a full route.
  CreateRideFormState withEstimates() => CreateRideFormState.initial().copyWith(
    fromAddress: 'Munich Airport',
    toAddress: 'Marienplatz',
    estimateBusiness: businessEstimate,
    estimateVan: vanEstimate,
  );

  group('CreateRideFormBloc — clearing an address clears estimates', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'emptying To clears both estimates',
      build: CreateRideFormBloc.new,
      seed: withEstimates,
      act: (bloc) => bloc.add(const ToAddressChanged('')),
      verify: (bloc) {
        expect(bloc.state.estimateBusiness, isNull);
        expect(bloc.state.estimateVan, isNull);
        expect(bloc.state.estimateUnavailable, isFalse);
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'emptying From clears both estimates',
      build: CreateRideFormBloc.new,
      seed: withEstimates,
      act: (bloc) => bloc.add(const FromAddressChanged('')),
      verify: (bloc) {
        expect(bloc.state.estimateBusiness, isNull);
        expect(bloc.state.estimateVan, isNull);
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'changing To to another non-empty address keeps estimates '
      '(a fresh fetch will replace them)',
      build: CreateRideFormBloc.new,
      seed: withEstimates,
      act: (bloc) => bloc.add(const ToAddressChanged('Olympiapark')),
      verify: (bloc) {
        // Both addresses are still present, so the stale-clear must NOT fire;
        // the screen re-triggers the estimate fetch for the new route.
        expect(bloc.state.estimateBusiness, isNotNull);
        expect(bloc.state.estimateVan, isNotNull);
      },
    );
  });
}
