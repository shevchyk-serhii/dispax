import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/ride_management/models/payment_method.dart';

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

    test('price set marks modified', () {
      final s = CreateRideFormState.initial().copyWith(price: 45.5);
      expect(s.isModified, isTrue);
    });
  });

  group('CreateRideFormState.copyWith price', () {
    test('copyWith sets the price', () {
      final s = CreateRideFormState.initial().copyWith(price: 45.5);
      expect(s.price, 45.5);
    });

    test('copyWith without price preserves the existing value', () {
      final s = CreateRideFormState.initial()
          .copyWith(price: 45.5)
          .copyWith(notes: 'unrelated change');
      expect(s.price, 45.5);
    });

    test('clearPrice sentinel resets the price to null', () {
      final s = CreateRideFormState.initial()
          .copyWith(price: 45.5)
          .copyWith(clearPrice: true);
      expect(s.price, isNull);
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
      bool isArrival = false,
      DateTime? flightDepartureTime,
    }) {
      return CreateRideFormState(
        clientName: clientName,
        selectedClientId: selectedClientId,
        fromAddress: fromAddress,
        toAddress: toAddress,
        flightNumber: flightNumber,
        manualPickupDateTime: DateTime(2026, 3, 15),
        flightDepartureTime: flightDepartureTime,
        isAirportTransfer: isAirportTransfer,
        isArrival: isArrival,
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

    // Airport DEPARTURE (isAirportTransfer=true, isArrival=false): flightDepartureTime required.
    test(
      'airport departure with flight number and flightDepartureTime returns true',
      () {
        expect(
          makeState(
            isAirportTransfer: true,
            flightNumber: 'LH123',
            flightDepartureTime: DateTime(2026, 3, 15, 8, 0),
          ).isValid,
          isTrue,
        );
      },
    );

    test(
      'airport departure with flight number but no flightDepartureTime returns false',
      () {
        // flightDepartureTime is required for departure auto-compute rides;
        // a flight number alone is not sufficient.
        expect(
          makeState(
            isAirportTransfer: true,
            flightNumber: 'LH123',
            flightDepartureTime: null,
          ).isValid,
          isFalse,
        );
      },
    );

    // Airport ARRIVAL (isAirportTransfer=true, isArrival=true): uses manualPickupDateTime,
    // not flightDepartureTime — same rule as a regular ride.
    test(
      'airport arrival with flight number and manualPickupDateTime returns true',
      () {
        expect(
          makeState(
            isAirportTransfer: true,
            isArrival: true,
            flightNumber: 'LH123',
            // manualPickupDateTime is set by default inside makeState
          ).isValid,
          isTrue,
        );
      },
    );

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

  group('CreateRideFormState.fromRide (duplicate ride)', () {
    Ride sourceRide({
      String? driverId = 'driver-9',
      RideStatus status = RideStatus.completed,
      String? notes = 'Two suitcases',
      String? specialRequirements = 'Child seat, Wheelchair',
      bool isAirportTransfer = true,
      bool isArrival = true,
      String? flightNumber = 'LH123',
      String? gate = 'H38',
      String? terminal = 'T2',
      double? price = 62.5,
      String? paymentMethod = 'Cash',
      List<String> tags = const ['VIP', 'recurring'],
    }) {
      return Ride(
        id: 'ride-1',
        clientId: 'client-7',
        creatorId: 'creator-3',
        driverId: driverId,
        companyId: 'company-1',
        pickupDateTime: DateTime(2026, 1, 1, 8, 0),
        from: Location(address: 'Marienplatz', latitude: 48.1, longitude: 11.5),
        to: Location(address: 'Flughafen', latitude: 48.3, longitude: 11.7),
        status: status,
        clientName: 'BMW AG',
        flightNumber: flightNumber,
        isAirportTransfer: isAirportTransfer,
        isArrival: isArrival,
        gate: gate,
        terminal: terminal,
        notes: notes,
        specialRequirements: specialRequirements,
        price: price,
        paymentMethod: paymentMethod,
        tags: tags,
      );
    }

    test('copies the reusable ride details', () {
      final s = CreateRideFormState.fromRide(sourceRide());
      expect(s.selectedClientId, 'client-7');
      expect(s.clientName, 'BMW AG');
      expect(s.fromAddress, 'Marienplatz');
      expect(s.toAddress, 'Flughafen');
      expect(s.isAirportTransfer, isTrue);
      expect(s.isArrival, isTrue);
      expect(s.flightNumber, 'LH123');
      expect(s.notes, 'Two suitcases');
      expect(s.showNotes, isTrue);
      expect(s.specialRequirements, ['Child seat', 'Wheelchair']);
      expect(s.tags, ['VIP', 'recurring']);
      expect(s.price, 62.5);
      expect(s.selectedPaymentMethod, PaymentMethod.cash);
    });

    test('does NOT copy the driver (new ride is unassigned)', () {
      final s = CreateRideFormState.fromRide(sourceRide(driverId: 'driver-9'));
      expect(s.selectedDriverId, isNull);
    });

    test('does NOT copy gate/terminal (off-list values crash the picker)', () {
      // Real airport gates ("K14") / terminals ("T2") come from the flight
      // monitor and are not in the form's fixed gate/terminal option lists;
      // copying them would crash DropdownButtonFormField. They must stay null.
      final s = CreateRideFormState.fromRide(
        sourceRide(gate: 'K14', terminal: 'T2'),
      );
      expect(s.selectedGate, isNull);
      expect(s.selectedTerminal, isNull);
    });

    test('uses a fresh pickup time, not the source ride pickup', () {
      final s = CreateRideFormState.fromRide(sourceRide());
      // Default is initial() = now + 1h, never the source's 2026-01-01 08:00.
      expect(s.manualPickupDateTime, isNotNull);
      expect(s.manualPickupDateTime, isNot(DateTime(2026, 1, 1, 8, 0)));
      expect(s.manualPickupDateTime!.isAfter(DateTime.now()), isTrue);
    });

    test('treats the copied client as baseline (not an unsaved change)', () {
      final s = CreateRideFormState.fromRide(sourceRide());
      expect(s.baselineClientId, 'client-7');
      expect(s.baselineClientName, 'BMW AG');
    });

    test('null notes/requirements collapse to empty, notes stay hidden', () {
      final s = CreateRideFormState.fromRide(
        sourceRide(notes: null, specialRequirements: null),
      );
      expect(s.notes, '');
      expect(s.showNotes, isFalse);
      expect(s.specialRequirements, isEmpty);
    });

    test('unknown payment method falls back to invoice', () {
      final s = CreateRideFormState.fromRide(sourceRide(paymentMethod: null));
      expect(s.selectedPaymentMethod, PaymentMethod.invoice);
    });
  });
}
