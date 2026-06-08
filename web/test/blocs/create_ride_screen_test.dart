import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/blocs.dart';

// Tests for task #9 (close confirmation) and task #10 (retry on error).
//
// The Retry button in CreateRideScreenContent calls
//   context.read<CreateRideFormBloc>().add(FormSubmitted())
// We verify the effect: FormSubmitted on a valid form → status=submitting.
//
// The discard-confirmation dialog uses CreateRideFormState.isModified —
// covered by create_ride_form_state_test.dart.
// FormCleared (called on "Discard") is covered here.

void main() {
  group('Task 10 — Retry triggers FormSubmitted on valid form', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormSubmitted on fully filled form transitions to submitting',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const FromAddressChanged('Main Street 1')); // no "airport" → no auto-toggle
        bloc.add(const ToAddressChanged('Central Hotel'));
        bloc.add(FormSubmitted());
      },
      expect: () => [
        isA<CreateRideFormState>()
            .having((s) => s.selectedClientId, 'clientId', 'c-1'),
        isA<CreateRideFormState>()
            .having((s) => s.fromAddress, 'fromAddress', 'Main Street 1'),
        isA<CreateRideFormState>()
            .having((s) => s.toAddress, 'toAddress', 'Central Hotel'),
        isA<CreateRideFormState>()
            .having((s) => s.status, 'status', CreateRideFormStatus.submitting),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormSubmitted on incomplete form emits nothing (no retry effect)',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(FormSubmitted()),
      expect: () => [],
    );
  });

  group('Task 9 — Discard dialog clears form via FormCleared', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormCleared after partial fill resets isModified to false',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const FromAddressChanged('Main Street 1'));
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(FormCleared());
      },
      expect: () => [
        isA<CreateRideFormState>().having((s) => s.isModified, 'isModified', true),
        isA<CreateRideFormState>().having((s) => s.isModified, 'isModified', true),
        isA<CreateRideFormState>().having((s) => s.isModified, 'isModified', false),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormCleared resets all fields to initial values',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const FromAddressChanged('Main Street 1'));
        bloc.add(const ToAddressChanged('Central Hotel'));
        bloc.add(const FlightNumberChanged('LH123'));
        bloc.add(FormCleared());
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.clientName, '');
        expect(s.selectedClientId, isNull);
        expect(s.fromAddress, '');
        expect(s.toAddress, '');
        expect(s.flightNumber, '');
        expect(s.isModified, isFalse);
      },
    );
  });
}
