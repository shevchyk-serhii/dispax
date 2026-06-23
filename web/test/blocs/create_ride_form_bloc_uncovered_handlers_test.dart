// Coverage for the CreateRideFormBloc event handlers that previously had no
// direct assertions: ClientCleared, NewClientModeToggled, NewClientPhoneChanged,
// AddressesSwapped, ArrivalToggled, NotesToggled, NotesChanged,
// SpecialRequirementToggled, ManualPickupTimeChanged, FlightDepartureTimeChanged,
// plus the airport-departure branch of isValid (flightDepartureTime gate).
//
// These guard the New Ride form's less-travelled paths (new-client entry,
// address swap, optional notes / special requirements, manual pickup overrides,
// and the departure-flight validation) against silent regressions.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/blocs.dart';

void main() {
  group('ClientCleared', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'clears the selected client, name and new-client phone',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const NewClientPhoneChanged('+49123'));
        bloc.add(const ClientCleared());
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.selectedClientId, isNull);
        expect(s.clientName, '');
        expect(s.newClientPhone, '');
      },
    );
  });

  group('NewClientModeToggled', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'entering new-client mode drops the previously selected client',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const NewClientModeToggled());
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isNewClient, isTrue);
        expect(s.selectedClientId, isNull);
        expect(s.clientName, '');
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'leaving new-client mode resets the new-client fields',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const NewClientModeToggled()); // → new-client mode
        bloc.add(const ClientNameChanged('Bob'));
        bloc.add(const NewClientPhoneChanged('+49555'));
        bloc.add(const NewClientModeToggled()); // → back to search
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isNewClient, isFalse);
        expect(s.newClientPhone, '');
        expect(s.clientName, '');
        expect(s.selectedClientId, isNull);
      },
    );
  });

  group('NewClientPhoneChanged', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'updates the new-client phone',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const NewClientPhoneChanged('+491701234567')),
      verify: (bloc) => expect(bloc.state.newClientPhone, '+491701234567'),
    );
  });

  group('AddressesSwapped', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'swaps from/to addresses',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const FromAddressChanged('Marienplatz 1'));
        bloc.add(const ToAddressChanged('Central Hotel'));
        bloc.add(const AddressesSwapped());
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.fromAddress, 'Central Hotel');
        expect(s.toAddress, 'Marienplatz 1');
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'keeps the airport-transfer flag after a swap (addresses are reversed)',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const FromAddressChanged('Hotel Bayerischer Hof'));
        bloc.add(const ToAddressChanged('Flughafen MUC'));
        bloc.add(const AddressesSwapped());
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.fromAddress, 'Flughafen MUC');
        expect(s.toAddress, 'Hotel Bayerischer Hof');
        // The transfer flag was already on (set by ToAddressChanged), so it
        // stays on after the swap. Note: _checkAirportTransfer only re-derives
        // isArrival while the flag is still off, so a swap does NOT flip an
        // already-detected arrival/departure — documented current behaviour.
        expect(s.isAirportTransfer, isTrue);
      },
    );
  });

  group('ArrivalToggled', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'sets isArrival explicitly',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ArrivalToggled(true));
        bloc.add(const ArrivalToggled(false));
      },
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.isArrival,
          'isArrival',
          true,
        ),
        isA<CreateRideFormState>().having(
          (s) => s.isArrival,
          'isArrival',
          false,
        ),
      ],
    );
  });

  group('Notes', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'NotesToggled flips showNotes',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const NotesToggled()),
      verify: (bloc) => expect(bloc.state.showNotes, isTrue),
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'NotesChanged stores the note text',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const NotesChanged('Call on arrival')),
      verify: (bloc) => expect(bloc.state.notes, 'Call on arrival'),
    );
  });

  group('SpecialRequirementToggled', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'adds a requirement, then removes it on a second toggle',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const SpecialRequirementToggled('child_seat'));
        bloc.add(const SpecialRequirementToggled('wheelchair'));
        bloc.add(const SpecialRequirementToggled('child_seat')); // remove
      },
      verify: (bloc) {
        expect(bloc.state.specialRequirements, ['wheelchair']);
      },
    );
  });

  group('ManualPickupTimeChanged', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'sets a concrete pickup time',
      build: CreateRideFormBloc.new,
      act: (bloc) =>
          bloc.add(ManualPickupTimeChanged(DateTime.utc(2026, 7, 1, 9, 30))),
      verify: (bloc) => expect(
        bloc.state.manualPickupDateTime,
        DateTime.utc(2026, 7, 1, 9, 30),
      ),
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'a null value clears the manual pickup time (departure auto-compute)',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const ManualPickupTimeChanged(null)),
      verify: (bloc) => expect(bloc.state.manualPickupDateTime, isNull),
    );
  });

  group('FlightDepartureTimeChanged', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'sets and clears the flight departure time',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(FlightDepartureTimeChanged(DateTime.utc(2026, 7, 1, 14, 0)));
        bloc.add(const FlightDepartureTimeChanged(null));
      },
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.flightDepartureTime,
          'flightDepartureTime',
          DateTime.utc(2026, 7, 1, 14, 0),
        ),
        isA<CreateRideFormState>().having(
          (s) => s.flightDepartureTime,
          'flightDepartureTime',
          isNull,
        ),
      ],
    );
  });

  group('isValid — airport departure requires flightDepartureTime', () {
    // For a departure ride (airport, not arrival) manualPickupDateTime is
    // optional but flightDepartureTime is mandatory. This guards the
    // isDepartureAutoCompute branch of isValid.
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'departure ride is invalid without a flight departure time, '
      'valid once it is set',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        // Airport in "to" → departure (not arrival).
        bloc.add(const FromAddressChanged('Hotel Bayerischer Hof'));
        bloc.add(const ToAddressChanged('Flughafen MUC'));
        bloc.add(const AirportTransferToggled(true));
        bloc.add(const FlightNumberChanged('LH123'));
        // No manual pickup, no flight departure → invalid.
      },
      verify: (bloc) {
        expect(bloc.state.isDepartureAutoCompute, isTrue);
        expect(
          bloc.state.isValid,
          isFalse,
          reason: 'departure ride needs a flight departure time',
        );
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'departure ride becomes valid once flightDepartureTime is provided',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const FromAddressChanged('Hotel Bayerischer Hof'));
        bloc.add(const ToAddressChanged('Flughafen MUC'));
        bloc.add(const AirportTransferToggled(true));
        bloc.add(const FlightNumberChanged('LH123'));
        bloc.add(FlightDepartureTimeChanged(DateTime.utc(2026, 7, 1, 14, 0)));
      },
      verify: (bloc) {
        expect(bloc.state.isValid, isTrue);
      },
    );
  });
}
