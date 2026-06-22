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
      final s = CreateRideFormState.initial().copyWith(
        specialRequirements: ['wheelchair'],
      );
      expect(s.isModified, isTrue);
    });

    test('whitespace-only fields are not modified', () {
      final s = CreateRideFormState.initial().copyWith(
        clientName: '  ',
        fromAddress: ' ',
        notes: '\t',
      );
      expect(s.isModified, isFalse);
    });

    test('client matching baseline is not modified', () {
      final s = CreateRideFormState.initial().copyWith(
        selectedClientId: 'self-1',
        clientName: 'Self',
        baselineClientId: 'self-1',
        baselineClientName: 'Self',
      );
      expect(s.isModified, isFalse);
    });

    test('driver matching baseline is not modified', () {
      final s = CreateRideFormState.initial().copyWith(
        selectedDriverId: 'self-1',
        baselineDriverId: 'self-1',
      );
      expect(s.isModified, isFalse);
    });

    test('client differing from baseline marks modified', () {
      final s = CreateRideFormState.initial()
          .copyWith(
            selectedClientId: 'self-1',
            clientName: 'Self',
            baselineClientId: 'self-1',
            baselineClientName: 'Self',
          )
          .copyWith(selectedClientId: 'other-2', clientName: 'Other');
      expect(s.isModified, isTrue);
    });

    test('driver differing from baseline marks modified', () {
      final s = CreateRideFormState.initial()
          .copyWith(selectedDriverId: 'self-1', baselineDriverId: 'self-1')
          .copyWith(selectedDriverId: 'other-2');
      expect(s.isModified, isTrue);
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

    test('client preselected as self (client booking flow) returns true', () {
      // ClientBookScreen preselects the current user as the client, which
      // sets both selectedClientId and baselineClientId to self.
      final state = CreateRideFormState.initial().copyWith(
        selectedClientId: 'self-1',
        clientName: 'Self',
        baselineClientId: 'self-1',
        baselineClientName: 'Self',
        fromAddress: 'Maximilianstrasse 10',
        toAddress: 'Flughafen Muenchen Terminal 2',
      );
      expect(state.isValid, isTrue);
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

    test('identical fromAddress and toAddress returns false', () {
      expect(
        makeState(fromAddress: 'Main St 1', toAddress: 'Main St 1').isValid,
        isFalse,
      );
    });

    test('case-insensitive same address returns false', () {
      expect(
        makeState(fromAddress: 'main st 1', toAddress: 'MAIN ST 1').isValid,
        isFalse,
      );
    });

    test('trimmed same address returns false', () {
      expect(
        makeState(fromAddress: '  Main St 1  ', toAddress: 'Main St 1').isValid,
        isFalse,
      );
    });

    test('different addresses returns true', () {
      expect(
        makeState(fromAddress: 'Airport', toAddress: 'Hotel').isValid,
        isTrue,
      );
    });
  });
}
