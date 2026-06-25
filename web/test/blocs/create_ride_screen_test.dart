import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/modules/ride_management/models/payment_method.dart';

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
        bloc.add(
          const FromAddressChanged('Main Street 1'),
        ); // no "airport" → no auto-toggle
        bloc.add(const ToAddressChanged('Central Hotel'));
        bloc.add(FormSubmitted());
      },
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.selectedClientId,
          'clientId',
          'c-1',
        ),
        isA<CreateRideFormState>().having(
          (s) => s.fromAddress,
          'fromAddress',
          'Main Street 1',
        ),
        isA<CreateRideFormState>().having(
          (s) => s.toAddress,
          'toAddress',
          'Central Hotel',
        ),
        isA<CreateRideFormState>().having(
          (s) => s.status,
          'status',
          CreateRideFormStatus.submitting,
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'FormSubmitted on incomplete form emits nothing (no retry effect)',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(FormSubmitted()),
      expect: () => [],
    );
  });

  group('Button stays disabled after a failed submit (regression)', () {
    // Repro of the reported bug: a driver submits a valid form, the backend
    // rejects it (e.g. "pickup and dropoff must be different"), the user fixes
    // the address — but the "Create Ride" button never re-enables.
    //
    // The button is disabled iff status == submitting (see
    // CreateRideActionButtons.onPressed). FormSubmitted moves the form to
    // submitting and nothing ever moves it back, so once a submit is attempted
    // the form is stuck in submitting forever and the button stays dead even
    // though the form is valid again.
    //
    // Correct behaviour: after the user edits an address following a failed
    // submit, the form must leave the submitting state so the button re-enables.
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'editing an address after a failed submit re-enables the button '
      '(status leaves submitting)',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        // 1. Fill a valid form (pickup == dropoff to provoke the backend error).
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const FromAddressChanged('Marienplatz 1'));
        bloc.add(const ToAddressChanged('Marienplatz 1'));
        // 2. Submit → form goes to submitting, button disables.
        bloc.add(FormSubmitted());
        // 3. Backend rejects it. The user fixes the dropoff address.
        bloc.add(const ToAddressChanged('Flughafen München'));
      },
      verify: (bloc) {
        final s = bloc.state;
        // The form is valid again...
        expect(s.isValid, isTrue, reason: 'form is valid after the fix');
        // ...so it must NOT be stuck in submitting (which keeps the button
        // disabled). This currently FAILS — the bug.
        expect(
          s.status,
          isNot(CreateRideFormStatus.submitting),
          reason:
              'after fixing the address the button must re-enable, but the '
              'form is stuck in submitting',
        );
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'SubmissionFailed leaves the submitting state (button re-enables)',
      build: CreateRideFormBloc.new,
      act: (bloc) {
        bloc.add(const ClientSelected(clientId: 'c-1', clientName: 'Alice'));
        bloc.add(const FromAddressChanged('Marienplatz 1'));
        bloc.add(const ToAddressChanged('Marienplatz 1'));
        bloc.add(FormSubmitted());
        bloc.add(const SubmissionFailed());
      },
      verify: (bloc) {
        expect(bloc.state.status, CreateRideFormStatus.initial);
      },
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
        isA<CreateRideFormState>().having(
          (s) => s.isModified,
          'isModified',
          true,
        ),
        isA<CreateRideFormState>().having(
          (s) => s.isModified,
          'isModified',
          true,
        ),
        isA<CreateRideFormState>().having(
          (s) => s.isModified,
          'isModified',
          false,
        ),
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

  group('Payment method selection', () {
    test('initial state defaults to Invoice (Rechnung)', () {
      final bloc = CreateRideFormBloc();
      expect(bloc.state.selectedPaymentMethod, PaymentMethod.invoice);
      bloc.close();
    });

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'PaymentMethodSelected updates selectedPaymentMethod',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const PaymentMethodSelected(PaymentMethod.cash)),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.selectedPaymentMethod,
          'selectedPaymentMethod',
          PaymentMethod.cash,
        ),
      ],
    );
  });
}
