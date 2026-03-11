import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktopus/modules/core/models/location.dart';
import 'package:oktopus/modules/core/models/person.dart';
import 'package:oktopus/modules/ride_management/models/ride.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('Ride', () {
    test('fromJson creates Ride correctly', () {
      final json = TestFixtures.rideJson();
      final ride = Ride.fromJson(json);

      expect(ride.id, 'ride-1');
      expect(ride.clientId, 'client-1');
      expect(ride.creatorId, 'creator-1');
      expect(ride.companyId, 'company-1');
      expect(ride.status, RideStatus.requested);
      expect(ride.clientName, 'Test Client');
      expect(ride.isAirportTransfer, isFalse);
    });

    test('toJson produces correct map', () {
      final ride = TestFixtures.ride();
      final json = ride.toJson();

      expect(json['id'], 'ride-1');
      expect(json['clientId'], 'client-1');
      expect(json['status'], 'Requested');
      expect(json['from'], isA<Map>());
      expect(json['to'], isA<Map>());
    });

    test('fromJson/toJson roundtrip preserves data', () {
      final original = TestFixtures.ride(
        flightNumber: 'LH100',
        isAirportTransfer: true,
        isArrival: true,
        gate: 'G5',
        terminal: 'T1',
        flightStatus: 'On Time',
        price: 45.50,
      );

      final restored = Ride.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.flightNumber, original.flightNumber);
      expect(restored.isAirportTransfer, original.isAirportTransfer);
      expect(restored.isArrival, original.isArrival);
      expect(restored.gate, original.gate);
      expect(restored.terminal, original.terminal);
      expect(restored.flightStatus, original.flightStatus);
      expect(restored.price, original.price);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'r1',
        'clientId': 'c1',
        'creatorId': 'cr1',
        'companyId': 'co1',
        'pickupDateTime': '2026-03-15T10:00:00.000',
        'from': {'address': 'A'},
        'to': {'address': 'B'},
        'clientName': 'Client',
      };

      final ride = Ride.fromJson(json);

      expect(ride.driverId, isNull);
      expect(ride.flightNumber, isNull);
      expect(ride.gate, isNull);
      expect(ride.terminal, isNull);
      expect(ride.flightStatus, isNull);
      expect(ride.driverName, isNull);
      expect(ride.price, isNull);
    });
  });

  group('RideStatus.fromString', () {
    test('parses all known statuses', () {
      expect(RideStatus.fromString('Requested'), RideStatus.requested);
      expect(RideStatus.fromString('Assigned'), RideStatus.assigned);
      expect(RideStatus.fromString('InProgress'), RideStatus.inProgress);
      expect(RideStatus.fromString('Completed'), RideStatus.completed);
      expect(RideStatus.fromString('Cancelled'), RideStatus.cancelled);
    });

    test('is case insensitive', () {
      expect(RideStatus.fromString('requested'), RideStatus.requested);
      expect(RideStatus.fromString('ASSIGNED'), RideStatus.assigned);
    });

    test('returns requested as fallback for unknown status', () {
      expect(RideStatus.fromString('Unknown'), RideStatus.requested);
      expect(RideStatus.fromString('garbage'), RideStatus.requested);
    });
  });

  group('Ride.copyWith', () {
    test('preserves unchanged fields', () {
      final original = TestFixtures.ride(price: 30.0);
      final copied = original.copyWith(status: RideStatus.completed);

      expect(copied.id, original.id);
      expect(copied.clientId, original.clientId);
      expect(copied.from, original.from);
      expect(copied.to, original.to);
      expect(copied.price, original.price);
      expect(copied.status, RideStatus.completed);
    });

    test('overrides specified fields', () {
      final original = TestFixtures.ride();
      final copied = original.copyWith(
        clientName: 'New Name',
        price: 99.99,
      );

      expect(copied.clientName, 'New Name');
      expect(copied.price, 99.99);
    });
  });

  group('Ride computed getters', () {
    test('flightIcon returns arrival icon for airport arrival', () {
      final ride = TestFixtures.airportRide(isArrival: true);
      expect(ride.flightIcon, '✈️↓');
    });

    test('flightIcon returns departure icon for airport departure', () {
      final ride = TestFixtures.airportRide(isArrival: false);
      expect(ride.flightIcon, '✈️↑');
    });

    test('flightIcon returns empty string for non-airport ride', () {
      final ride = TestFixtures.ride();
      expect(ride.flightIcon, '');
    });

    test('flightIconData returns flight_land for arrival', () {
      final ride = TestFixtures.airportRide(isArrival: true);
      expect(ride.flightIconData, Icons.flight_land);
    });

    test('flightIconData returns flight_takeoff for departure', () {
      final ride = TestFixtures.airportRide(isArrival: false);
      expect(ride.flightIconData, Icons.flight_takeoff);
    });

    test('flightIconData returns null for non-airport ride', () {
      final ride = TestFixtures.ride();
      expect(ride.flightIconData, isNull);
    });

    test('flightTypeText returns Arrival for arrival', () {
      final ride = TestFixtures.airportRide(isArrival: true);
      expect(ride.flightTypeText, 'Arrival');
    });

    test('flightTypeText returns Departure for departure', () {
      final ride = TestFixtures.airportRide(isArrival: false);
      expect(ride.flightTypeText, 'Departure');
    });

    test('flightTypeText returns empty for non-airport', () {
      final ride = TestFixtures.ride();
      expect(ride.flightTypeText, '');
    });

    test('flightStatusIcon maps known statuses', () {
      expect(TestFixtures.airportRide(flightStatus: 'On Time').flightStatusIcon, '✅');
      expect(TestFixtures.airportRide(flightStatus: 'Delayed').flightStatusIcon, '⏰');
      expect(TestFixtures.airportRide(flightStatus: 'Cancelled').flightStatusIcon, '❌');
      expect(TestFixtures.airportRide(flightStatus: 'Other').flightStatusIcon, '❓');
    });

    test('flightStatusIcon returns empty for null flightStatus', () {
      final ride = TestFixtures.airportRide(flightStatus: null);
      expect(ride.flightStatusIcon, '');
    });

    test('fullFlightInfo includes flight number, gate, terminal, status', () {
      final ride = TestFixtures.airportRide(
        flightNumber: 'LH1234',
        gate: 'G12',
        terminal: 'T2',
        flightStatus: 'On Time',
        isArrival: true,
      );

      final info = ride.fullFlightInfo;
      expect(info, contains('LH1234'));
      expect(info, contains('Gate G12'));
      expect(info, contains('Terminal T2'));
      expect(info, contains('On Time'));
    });

    test('fullFlightInfo shows only gate when no terminal', () {
      final ride = TestFixtures.airportRide(gate: 'G5', terminal: null);
      expect(ride.fullFlightInfo, contains('Gate G5'));
      expect(ride.fullFlightInfo, isNot(contains('Terminal')));
    });

    test('fullFlightInfo shows only terminal when no gate', () {
      final ride = TestFixtures.airportRide(gate: null, terminal: 'T1');
      expect(ride.fullFlightInfo, contains('Terminal T1'));
      expect(ride.fullFlightInfo, isNot(contains('Gate')));
    });

    test('fullFlightInfo returns empty for non-airport ride', () {
      expect(TestFixtures.ride().fullFlightInfo, '');
    });

    test('fullFlightInfo returns empty when no flight number', () {
      final ride = TestFixtures.ride(isAirportTransfer: true, flightNumber: null);
      expect(ride.fullFlightInfo, '');
    });

    test('flightInfo returns FlightInfo for airport transfer', () {
      final ride = TestFixtures.airportRide();
      final info = ride.flightInfo;

      expect(info, isNotNull);
      expect(info!.flightNumber, 'LH1234');
      expect(info.gate, 'G12');
      expect(info.terminal, 'T2');
      expect(info.isArrival, isTrue);
    });

    test('flightInfo returns null for non-airport ride', () {
      expect(TestFixtures.ride().flightInfo, isNull);
    });

    test('driver returns Person when driverId and driverName set', () {
      final ride = TestFixtures.ride(driverId: 'driver-1', driverName: 'Hans');
      final driver = ride.driver;

      expect(driver, isNotNull);
      expect(driver!.id, 'driver-1');
      expect(driver.name, 'Hans');
      expect(driver.role, PersonRole.driver);
    });

    test('driver returns null when no driverId', () {
      expect(TestFixtures.ride().driver, isNull);
    });

    test('driver returns null when no driverName', () {
      final ride = TestFixtures.ride(driverId: 'driver-1', driverName: null);
      expect(ride.driver, isNull);
    });
  });

  group('Ride equality', () {
    test('same fields are equal', () {
      final a = TestFixtures.ride();
      final b = TestFixtures.ride();
      expect(a, b);
    });

    test('different id means not equal', () {
      final a = TestFixtures.ride(id: 'ride-1');
      final b = TestFixtures.ride(id: 'ride-2');
      expect(a, isNot(b));
    });

    test('hashCode is consistent with equality', () {
      final a = TestFixtures.ride();
      final b = TestFixtures.ride();
      expect(a.hashCode, b.hashCode);
    });
  });
}
