import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';

void main() {
  group('CreateRideFormBloc — secretary client selection', () {
    test('initial state has null selectedClientId', () {
      final bloc = CreateRideFormBloc();
      expect(bloc.state.selectedClientId, isNull);
      bloc.close();
    });

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ClientSelected sets selectedClientId and clientName',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(
        const ClientSelected(clientId: 'client-42', clientName: 'Anna Müller'),
      ),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.selectedClientId, 'selectedClientId', 'client-42')
            .having((s) => s.clientName, 'clientName', 'Anna Müller'),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ClientSelected replaces previously selected client',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState(
        clientName: 'Old Client',
        selectedClientId: 'old-id',
        fromAddress: '',
        toAddress: '',
        flightNumber: '',
        manualPickupDateTime: DateTime(2026, 6, 1),
        isAirportTransfer: false,
        isArrival: false,
      ),
      act: (bloc) => bloc.add(
        const ClientSelected(clientId: 'new-id', clientName: 'New Client'),
      ),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.selectedClientId, 'selectedClientId', 'new-id')
            .having((s) => s.clientName, 'clientName', 'New Client'),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormCleared resets selectedClientId to null',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState(
        clientName: 'Anna',
        selectedClientId: 'client-42',
        fromAddress: 'From',
        toAddress: 'To',
        flightNumber: '',
        manualPickupDateTime: DateTime(2026, 6, 1),
        isAirportTransfer: false,
        isArrival: false,
      ),
      act: (bloc) => bloc.add(const FormCleared()),
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.selectedClientId, 'selectedClientId', isNull)
            .having((s) => s.clientName, 'clientName', ''),
      ],
    );
  });

  group('CreateRideFormState.isValid — secretary rules', () {
    CreateRideFormState baseValid() => CreateRideFormState(
      clientName: 'Anna',
      selectedClientId: 'client-42',
      fromAddress: 'Pickup St',
      toAddress: 'Dropoff St',
      flightNumber: '',
      manualPickupDateTime: DateTime(2026, 6, 1),
      isAirportTransfer: false,
      isArrival: false,
    );

    test('isValid is true when client selected and addresses filled', () {
      expect(baseValid().isValid, isTrue);
    });

    test('isValid is false when selectedClientId is null', () {
      final state = baseValid().copyWith(clearClientId: true);
      expect(state.isValid, isFalse);
    });

    test('isValid is false when fromAddress is empty', () {
      final state = baseValid().copyWith(fromAddress: '');
      expect(state.isValid, isFalse);
    });

    test('isValid is false when fromAddress is whitespace only', () {
      final state = baseValid().copyWith(fromAddress: '   ');
      expect(state.isValid, isFalse);
    });

    test('isValid is false when toAddress is empty', () {
      final state = baseValid().copyWith(toAddress: '');
      expect(state.isValid, isFalse);
    });

    test('isValid is false for airport transfer without flight number', () {
      final state = baseValid().copyWith(
        isAirportTransfer: true,
        flightNumber: '',
      );
      expect(state.isValid, isFalse);
    });

    test('isValid is true for airport transfer with flight number', () {
      final state = baseValid().copyWith(
        isAirportTransfer: true,
        flightNumber: 'LH123',
      );
      expect(state.isValid, isTrue);
    });

    test('isValid is false when all fields empty (initial state)', () {
      expect(CreateRideFormState.initial().isValid, isFalse);
    });
  });

  group('CreateRideFormState.copyWith — clearClientId', () {
    test('clearClientId: true resets selectedClientId to null', () {
      final state = CreateRideFormState(
        clientName: 'Anna',
        selectedClientId: 'client-42',
        fromAddress: '',
        toAddress: '',
        flightNumber: '',
        manualPickupDateTime: DateTime(2026, 6, 1),
        isAirportTransfer: false,
        isArrival: false,
      );
      final cleared = state.copyWith(clearClientId: true);
      expect(cleared.selectedClientId, isNull);
      expect(cleared.clientName, 'Anna');
    });

    test('clearClientId: false preserves existing selectedClientId', () {
      final state = CreateRideFormState(
        clientName: 'Anna',
        selectedClientId: 'client-42',
        fromAddress: '',
        toAddress: '',
        flightNumber: '',
        manualPickupDateTime: DateTime(2026, 6, 1),
        isAirportTransfer: false,
        isArrival: false,
      );
      final copy = state.copyWith(clearClientId: false);
      expect(copy.selectedClientId, 'client-42');
    });

    test(
      'passing selectedClientId updates value when clearClientId is false',
      () {
        final state = CreateRideFormState(
          clientName: 'Anna',
          selectedClientId: 'old-id',
          fromAddress: '',
          toAddress: '',
          flightNumber: '',
          manualPickupDateTime: DateTime(2026, 6, 1),
          isAirportTransfer: false,
          isArrival: false,
        );
        final copy = state.copyWith(selectedClientId: 'new-id');
        expect(copy.selectedClientId, 'new-id');
      },
    );
  });

  group('FormSubmitted — requires selectedClientId', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormSubmitted does not emit submitting when selectedClientId is null',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState(
        clientName: 'Anna',
        selectedClientId: null,
        fromAddress: 'From',
        toAddress: 'To',
        flightNumber: '',
        manualPickupDateTime: DateTime(2026, 6, 1),
        isAirportTransfer: false,
        isArrival: false,
      ),
      act: (bloc) => bloc.add(const FormSubmitted()),
      expect: () => [],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormSubmitted emits submitting when client selected and addresses filled',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState(
        clientName: 'Anna',
        selectedClientId: 'client-42',
        fromAddress: 'From',
        toAddress: 'To',
        flightNumber: '',
        manualPickupDateTime: DateTime(2026, 6, 1),
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
  });
}
