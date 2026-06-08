import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';

void main() {
  group('CreateRideFormState.isModified', () {
    test('initial state is not modified', () {
      expect(CreateRideFormState.initial().isModified, isFalse);
    });

    test('clientName filled marks modified', () {
      final s = CreateRideFormState.initial().copyWith(clientName: 'Alice');
      expect(s.isModified, isTrue);
    });

    test('selectedClientId set marks modified', () {
      final s = CreateRideFormState.initial().copyWith(selectedClientId: 'c-1');
      expect(s.isModified, isTrue);
    });

    test('fromAddress filled marks modified', () {
      final s = CreateRideFormState.initial().copyWith(fromAddress: 'Airport');
      expect(s.isModified, isTrue);
    });

    test('toAddress filled marks modified', () {
      final s = CreateRideFormState.initial().copyWith(toAddress: 'Hotel');
      expect(s.isModified, isTrue);
    });

    test('flightNumber filled marks modified', () {
      final s = CreateRideFormState.initial().copyWith(flightNumber: 'LH123');
      expect(s.isModified, isTrue);
    });

    test('notes filled marks modified', () {
      final s = CreateRideFormState.initial().copyWith(notes: 'extra bags');
      expect(s.isModified, isTrue);
    });

    test('specialRequirements non-empty marks modified', () {
      final s = CreateRideFormState.initial()
          .copyWith(specialRequirements: ['wheelchair']);
      expect(s.isModified, isTrue);
    });

    test('whitespace-only fields are not modified', () {
      final s = CreateRideFormState.initial()
          .copyWith(clientName: '  ', fromAddress: ' ', notes: '\t');
      expect(s.isModified, isFalse);
    });
  });

  group('CreateRideFormState.isValid', () {
    CreateRideFormState makeState({
      String clientName = 'Client',
      String? selectedClientId = 'client-1',
      String fromAddress = 'From',
      String toAddress = 'To',
      String flightNumber = '',
      bool isAirportTransfer = false,
    }) {
      return CreateRideFormState(
        clientName: clientName,
        selectedClientId: selectedClientId,
        fromAddress: fromAddress,
        toAddress: toAddress,
        flightNumber: flightNumber,
        pickupDateTime: DateTime(2026, 3, 15),
        isAirportTransfer: isAirportTransfer,
        isArrival: false,
      );
    }

    test('all required fields filled returns true', () {
      expect(makeState().isValid, isTrue);
    });

    test('selectedClientId null returns false', () {
      expect(makeState(selectedClientId: null).isValid, isFalse);
    });

    test('empty fromAddress returns false', () {
      expect(makeState(fromAddress: '').isValid, isFalse);
    });

    test('empty toAddress returns false', () {
      expect(makeState(toAddress: '').isValid, isFalse);
    });

    test('airport transfer without flight number returns false', () {
      expect(
        makeState(isAirportTransfer: true, flightNumber: '').isValid,
        isFalse,
      );
    });

    test('airport transfer with flight number returns true', () {
      expect(
        makeState(isAirportTransfer: true, flightNumber: 'LH123').isValid,
        isTrue,
      );
    });

    test('non-airport transfer does not require flight number', () {
      expect(
        makeState(isAirportTransfer: false, flightNumber: '').isValid,
        isTrue,
      );
    });
  });
}
