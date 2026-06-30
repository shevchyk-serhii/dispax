// Wires the FormPrefilledFromRide event (the "Duplicate ride" flow) to its
// handler. CreateRideFormState.fromRide is unit-tested directly in
// create_ride_form_state_test.dart; this guards the event→handler dispatch so
// adding/removing the `on<FormPrefilledFromRide>` registration cannot silently
// regress the duplicate button.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/payment_method.dart';

void main() {
  Ride sourceRide() => Ride(
    id: 'ride-1',
    clientId: 'client-7',
    creatorId: 'creator-3',
    driverId: 'driver-9',
    companyId: 'company-1',
    pickupDateTime: DateTime(2026, 1, 1, 8, 0),
    from: Location(address: 'Marienplatz', latitude: 48.1, longitude: 11.5),
    to: Location(address: 'Flughafen', latitude: 48.3, longitude: 11.7),
    status: RideStatus.completed,
    clientName: 'BMW AG',
    flightNumber: 'LH123',
    isAirportTransfer: true,
    isArrival: true,
    notes: 'Two suitcases',
    specialRequirements: 'Child seat, Wheelchair',
    price: 62.5,
    paymentMethod: 'Cash',
    tags: const ['VIP', 'recurring'],
  );

  group('FormPrefilledFromRide (duplicate ride)', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'copies the reusable ride details into the form state',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(FormPrefilledFromRide(sourceRide())),
      verify: (bloc) {
        final s = bloc.state;
        expect(s.selectedClientId, 'client-7');
        expect(s.clientName, 'BMW AG');
        expect(s.fromAddress, 'Marienplatz');
        expect(s.toAddress, 'Flughafen');
        expect(s.isAirportTransfer, isTrue);
        expect(s.isArrival, isTrue);
        expect(s.flightNumber, 'LH123');
        expect(s.notes, 'Two suitcases');
        expect(s.showNotes, isTrue);
        expect(s.specialRequirements, ['Child seat', 'Wheelchair']);
        expect(s.tags, ['VIP', 'recurring']);
        expect(s.price, 62.5);
        expect(s.selectedPaymentMethod, PaymentMethod.cash);
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'replaces the whole state, dropping a prior in-progress edit',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        // Start typing a different ride, then duplicate an existing one.
        bloc.add(const FromAddressChanged('Somewhere else'));
        bloc.add(const ClientNameChanged('Different client'));
        bloc.add(FormPrefilledFromRide(sourceRide()));
      },
      verify: (bloc) {
        // The duplicate atomically overwrites the half-entered form.
        expect(bloc.state.fromAddress, 'Marienplatz');
        expect(bloc.state.clientName, 'BMW AG');
        expect(bloc.state.selectedClientId, 'client-7');
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'does NOT carry the source driver — the duplicate starts unassigned',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(FormPrefilledFromRide(sourceRide())),
      verify: (bloc) => expect(bloc.state.selectedDriverId, isNull),
    );
  });
}
