import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';

void main() {
  group('CreateRideFormBloc', () {
    test('initial state has empty fields', () {
      final bloc = CreateRideFormBloc();
      expect(bloc.state.clientName, '');
      expect(bloc.state.fromAddress, '');
      expect(bloc.state.toAddress, '');
      expect(bloc.state.flightNumber, '');
      expect(bloc.state.isAirportTransfer, isFalse);
      expect(bloc.state.isArrival, isFalse);
      expect(bloc.state.selectedGate, isNull);
      expect(bloc.state.selectedTerminal, isNull);
      expect(bloc.state.status, CreateRideFormStatus.initial);
      bloc.close();
    });

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ClientNameChanged updates clientName',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const ClientNameChanged('Test Client')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.clientName,
          'clientName',
          'Test Client',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FromAddressChanged updates fromAddress',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const FromAddressChanged('Main St 1')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.fromAddress,
          'fromAddress',
          'Main St 1',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ToAddressChanged updates toAddress',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const ToAddressChanged('Oak Ave 2')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.toAddress,
          'toAddress',
          'Oak Ave 2',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FromAddressChanged with "airport" auto-enables isAirportTransfer',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const FromAddressChanged('Munich Airport')),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.isAirportTransfer, 'isAirportTransfer', true)
            .having((s) => s.isArrival, 'isArrival', true),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ToAddressChanged with "airport" auto-enables isAirportTransfer as departure',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const ToAddressChanged('Munich Airport')),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.isAirportTransfer, 'isAirportTransfer', true)
            .having((s) => s.isArrival, 'isArrival', false),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FromAddressChanged with "muc" auto-enables isAirportTransfer and detects arrival',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const FromAddressChanged('MUC Terminal 2')),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.isAirportTransfer, 'isAirportTransfer', true)
            .having((s) => s.isArrival, 'isArrival', true),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'AirportTransferToggled(false) clears flight fields',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState(
        clientName: 'Test',
        fromAddress: 'Airport',
        toAddress: 'Hotel',
        flightNumber: 'LH123',
        pickupDateTime: DateTime(2026, 3, 15),
        isAirportTransfer: true,
        isArrival: true,
        selectedGate: 'G1',
        selectedTerminal: 'T1',
      ),
      act: (bloc) => bloc.add(const AirportTransferToggled(false)),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.isAirportTransfer, 'isAirportTransfer', false)
            .having((s) => s.flightNumber, 'flightNumber', '')
            .having((s) => s.isArrival, 'isArrival', false),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'AirportTransferToggled(true) enables flag',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const AirportTransferToggled(true)),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.isAirportTransfer,
          'isAirportTransfer',
          true,
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FlightNumberChanged updates flightNumber',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const FlightNumberChanged('LH456')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.flightNumber,
          'flightNumber',
          'LH456',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'PickupDateTimeChanged updates pickupDateTime',
      build: CreateRideFormBloc.new,
      act: (bloc) =>
          bloc.add(PickupDateTimeChanged(DateTime(2026, 6, 1, 14, 0))),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.pickupDateTime,
          'pickupDateTime',
          DateTime(2026, 6, 1, 14, 0),
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'GateSelected updates selectedGate',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const GateSelected('G5')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.selectedGate,
          'selectedGate',
          'G5',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'TerminalSelected updates selectedTerminal',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const TerminalSelected('T2')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.selectedTerminal,
          'selectedTerminal',
          'T2',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormCleared resets to initial state',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState(
        clientName: 'Test',
        fromAddress: 'A',
        toAddress: 'B',
        flightNumber: 'LH123',
        pickupDateTime: DateTime(2026, 3, 15),
        isAirportTransfer: true,
        isArrival: true,
      ),
      act: (bloc) => bloc.add(const FormCleared()),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.clientName, 'clientName', '')
            .having((s) => s.fromAddress, 'fromAddress', '')
            .having((s) => s.toAddress, 'toAddress', '')
            .having((s) => s.isAirportTransfer, 'isAirportTransfer', false),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormSubmitted with valid state emits submitting',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState(
        clientName: 'Client',
        selectedClientId: 'client-1',
        fromAddress: 'From',
        toAddress: 'To',
        flightNumber: '',
        pickupDateTime: DateTime(2026, 3, 15),
        isAirportTransfer: false,
        isArrival: false,
      ),
      act: (bloc) => bloc.add(const FormSubmitted()),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.status,
          'status',
          CreateRideFormStatus.submitting,
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormSubmitted with invalid state emits nothing',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const FormSubmitted()),
      expect: () => [],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'DriverPreselected sets driver and baseline; not modified',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const DriverPreselected('self-1')),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.selectedDriverId, 'selectedDriverId', 'self-1')
            .having((s) => s.baselineDriverId, 'baselineDriverId', 'self-1')
            .having((s) => s.isModified, 'isModified', false),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ClientPreselected sets client and baseline; not modified',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(
        const ClientPreselected(clientId: 'self-1', clientName: 'Self'),
      ),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.selectedClientId, 'selectedClientId', 'self-1')
            .having((s) => s.clientName, 'clientName', 'Self')
            .having((s) => s.isModified, 'isModified', false),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'user input after preselect marks modified',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc
        ..add(const DriverPreselected('self-1'))
        ..add(const FromAddressChanged('Main St 1')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.isModified,
          'isModified',
          false,
        ),
        isA<CreateRideFormState>()
            .having((s) => s.fromAddress, 'fromAddress', 'Main St 1')
            .having((s) => s.isModified, 'isModified', true),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'selecting a different driver after preselect marks modified',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc
        ..add(const DriverPreselected('self-1'))
        ..add(const DriverSelected('other-2')),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.isModified,
          'isModified',
          false,
        ),
        isA<CreateRideFormState>()
            .having((s) => s.selectedDriverId, 'selectedDriverId', 'other-2')
            .having((s) => s.isModified, 'isModified', true),
      ],
    );
  });
}
