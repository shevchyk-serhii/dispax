// Coverage for the airport auto-address behaviour of CreateRideFormBloc:
// enabling the airport transfer auto-fills the airport endpoint (arrival → From,
// departure → To); switching direction moves the airport address between fields
// without disturbing the operator-typed address; disabling the transfer clears
// only the auto-filled airport address (a hand-typed address survives). Also
// guards that prefill (edit/duplicate) keeps a saved airport address intact.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/modules/ride_management/helpers/airport_catalog.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';

void main() {
  final mucAddress = defaultAirport.address;

  group('AirportTransferToggled — auto-fill airport address', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'enabling on a fresh form fills From with the airport and marks arrival',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const AirportTransferToggled(true)),
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isAirportTransfer, isTrue);
        expect(s.isArrival, isTrue);
        expect(s.fromAddress, mucAddress);
        expect(s.toAddress, isEmpty);
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'disabling clears the auto-filled airport address but keeps the '
      'hand-typed drop-off',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const AirportTransferToggled(true));
        bloc.add(const ToAddressChanged('Hotel Bayerischer Hof'));
        bloc.add(const AirportTransferToggled(false));
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isAirportTransfer, isFalse);
        // Auto-filled MUC address removed from From…
        expect(s.fromAddress, isEmpty);
        // …but the operator's manual drop-off survives.
        expect(s.toAddress, 'Hotel Bayerischer Hof');
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      're-toggling on while already on does not flip the direction',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        // Typing an airport into "to" auto-enables the flag as a departure.
        bloc.add(const ToAddressChanged('Flughafen MUC'));
        // A redundant toggle-on must not change the departure direction.
        bloc.add(const AirportTransferToggled(true));
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isAirportTransfer, isTrue);
        expect(s.isArrival, isFalse, reason: 'stays a departure');
        expect(s.toAddress, 'Flughafen MUC');
      },
    );
  });

  group('ArrivalToggled — move airport address between fields', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'switching arrival→departure moves the airport from From to To and '
      'frees From',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const AirportTransferToggled(true)); // arrival, From = MUC
        bloc.add(const ArrivalToggled(false)); // → departure
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isArrival, isFalse);
        expect(s.toAddress, mucAddress);
        expect(s.fromAddress, isEmpty);
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'switching direction swaps fields, keeping the operator-entered address',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const AirportTransferToggled(true)); // arrival: From=MUC
        bloc.add(const ToAddressChanged('Hotel Bayerischer Hof')); // To=Hotel
        bloc.add(const ArrivalToggled(false)); // → departure: swap
      },
      verify: (bloc) {
        final s = bloc.state;
        // Departure: airport is the destination (To); the operator's address is
        // preserved as the new pick-up (From) rather than being lost.
        expect(s.toAddress, mucAddress);
        expect(s.fromAddress, 'Hotel Bayerischer Hof');
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ArrivalToggled without an active transfer only sets the flag',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const FromAddressChanged('Marienplatz 1'));
        bloc.add(const ArrivalToggled(true));
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isArrival, isTrue);
        expect(s.isAirportTransfer, isFalse);
        // No airport auto-fill when the transfer is off.
        expect(s.fromAddress, 'Marienplatz 1');
        expect(s.toAddress, isEmpty);
      },
    );
  });

  group('isValid with auto-filled airport', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'arrival transfer is valid once client, drop-off, flight and pickup are '
      'set (airport From is auto-filled and non-empty)',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const AirportTransferToggled(true)); // From = MUC, arrival
        bloc.add(const ToAddressChanged('Hotel Bayerischer Hof'));
        bloc.add(const FlightNumberChanged('LH123'));
        bloc.add(ManualPickupTimeChanged(DateTime.utc(2026, 7, 1, 9, 0)));
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.fromAddress, mucAddress);
        expect(s.toAddress, 'Hotel Bayerischer Hof');
        expect(
          s.isValid,
          isTrue,
          reason: 'both endpoints non-empty and distinct, flight + pickup set',
        );
      },
    );
  });

  group('prefill keeps a saved airport address', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormPrefilledFromRide does not overwrite a saved airport address',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(
        FormPrefilledFromRide(
          Ride(
            id: 'r-1',
            clientId: 'c-1',
            creatorId: 'u-1',
            companyId: 'co-1',
            clientName: 'Alice',
            pickupDateTime: DateTime.utc(2026, 7, 1, 9, 0),
            from: const Location(address: 'Munich Airport Terminal 2'),
            to: const Location(address: 'Hotel Bayerischer Hof'),
            isAirportTransfer: true,
            isArrival: true,
          ),
        ),
      ),
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isAirportTransfer, isTrue);
        expect(s.isArrival, isTrue);
        // The legacy saved airport wording is preserved, not replaced by the
        // canonical catalog MUC address.
        expect(s.fromAddress, 'Munich Airport Terminal 2');
        expect(s.toAddress, 'Hotel Bayerischer Hof');
      },
    );
  });
}
