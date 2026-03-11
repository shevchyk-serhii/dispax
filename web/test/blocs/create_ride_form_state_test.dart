import 'package:flutter_test/flutter_test.dart';
import 'package:oktopus/blocs/create_ride_form/create_ride_form_state.dart';

void main() {
  group('CreateRideFormState.isValid', () {
    CreateRideFormState makeState({
      String clientName = 'Client',
      String fromAddress = 'From',
      String toAddress = 'To',
      String flightNumber = '',
      bool isAirportTransfer = false,
    }) {
      return CreateRideFormState(
        clientName: clientName,
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

    test('empty clientName returns false', () {
      expect(makeState(clientName: '').isValid, isFalse);
    });

    test('whitespace-only clientName returns false', () {
      expect(makeState(clientName: '   ').isValid, isFalse);
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
