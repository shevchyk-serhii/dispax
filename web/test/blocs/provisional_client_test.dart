// Tests for the "from-chat" / provisional-client feature.
//
// Covers:
// 1. CreateRideFormState.isValid — valid WITHOUT a client name when
//    isProvisionalClient is true; invalid without a name or selectedClientId
//    when false.
// 2. CreateRideFormBloc.ProvisionalClientModeToggled — state transitions.
// 3. Equatable props: toggling isProvisionalClient produces a distinct state.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

// A minimal-valid state that would be invalid only because of the client check.
CreateRideFormState _validExceptClient({bool isProvisional = false}) =>
    CreateRideFormState.initial().copyWith(
      fromAddress: 'Pickup St',
      toAddress: 'Dropoff St',
      manualPickupDateTime: DateTime(2026, 6, 1, 10, 0),
      isProvisionalClient: isProvisional,
    );

void main() {
  group('CreateRideFormState.isValid — provisional client', () {
    test(
      'INVALID when no client selected and isProvisionalClient is false',
      () {
        final state = _validExceptClient(isProvisional: false);
        // No client selected → clientOk = false → invalid.
        expect(state.isValid, isFalse);
      },
    );

    test('VALID when isProvisionalClient is true (no client required)', () {
      final state = _validExceptClient(isProvisional: true);
      // Provisional mode: clientOk = true without a selected client.
      expect(state.isValid, isTrue);
    });

    test(
      'mutation check: reverting the isProvisionalClient branch breaks isValid',
      () {
        // When isProvisionalClient = true, the form SHOULD be valid.
        // If the branch were removed (always uses old logic), the same state
        // would be invalid because no client is selected.
        //
        // Simulate "reverted" logic: ignore isProvisionalClient.
        bool isValidWithoutFix(CreateRideFormState s) {
          // Old path: isNewClient branch only.
          final clientOk = s.isNewClient
              ? s.clientName.trim().isNotEmpty
              : s.selectedClientId != null;
          final pickupOk = s.isDepartureAutoCompute
              ? s.flightDepartureTime != null
              : s.manualPickupDateTime != null;
          return clientOk &&
              s.fromAddress.trim().isNotEmpty &&
              s.toAddress.trim().isNotEmpty &&
              (!s.isAirportTransfer || s.flightNumber.trim().isNotEmpty) &&
              s.fromAddress.trim().toLowerCase() !=
                  s.toAddress.trim().toLowerCase() &&
              pickupOk;
        }

        final state = _validExceptClient(isProvisional: true);
        // Without the fix the state is invalid:
        expect(isValidWithoutFix(state), isFalse);
        // With the fix (the real getter) it is valid:
        expect(state.isValid, isTrue);
      },
    );

    test('VALID when isNewClient and clientName not empty', () {
      final state = _validExceptClient().copyWith(
        isNewClient: true,
        clientName: 'Alice',
      );
      expect(state.isValid, isTrue);
    });

    test('INVALID when isNewClient and clientName is empty', () {
      final state = _validExceptClient().copyWith(
        isNewClient: true,
        clientName: '',
      );
      expect(state.isValid, isFalse);
    });

    test('VALID when selectedClientId is set (normal mode)', () {
      final state = _validExceptClient().copyWith(selectedClientId: 'client-1');
      expect(state.isValid, isTrue);
    });
  });

  group('CreateRideFormState Equatable — isProvisionalClient in props', () {
    test('toggling isProvisionalClient produces a distinct state', () {
      final s1 = CreateRideFormState.initial();
      final s2 = s1.copyWith(isProvisionalClient: true);
      // Equatable must see them as different (isProvisionalClient is in props).
      expect(s1, isNot(equals(s2)));
    });
  });

  group('CreateRideFormBloc — ProvisionalClientModeToggled', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'toggling ON sets isProvisionalClient=true and clears client fields',
      build: () => CreateRideFormBloc(),
      seed: () => CreateRideFormState.initial().copyWith(
        selectedClientId: 'client-1',
        clientName: 'Some Client',
        isNewClient: true,
      ),
      act: (bloc) => bloc.add(const ProvisionalClientModeToggled()),
      expect: () => [
        predicate<CreateRideFormState>(
          (s) =>
              s.isProvisionalClient == true &&
              s.isNewClient == false &&
              s.clientName == '' &&
              s.selectedClientId == null,
          'isProvisionalClient=true, client fields cleared',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'toggling OFF resets isProvisionalClient to false',
      build: () => CreateRideFormBloc(),
      seed: () =>
          CreateRideFormState.initial().copyWith(isProvisionalClient: true),
      act: (bloc) => bloc.add(const ProvisionalClientModeToggled()),
      expect: () => [
        predicate<CreateRideFormState>(
          (s) => s.isProvisionalClient == false,
          'isProvisionalClient=false after second toggle',
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'mutation check: without the handler the state would not change',
      build: () => CreateRideFormBloc(),
      act: (bloc) => bloc.add(const ProvisionalClientModeToggled()),
      expect: () => [
        predicate<CreateRideFormState>(
          (s) => s.isProvisionalClient == true,
          'state changed — handler is registered',
        ),
      ],
    );
  });
}
