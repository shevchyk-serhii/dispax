import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
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

    test('fromJson reads the paymentMethod wire value', () {
      final json = TestFixtures.rideJson()..['paymentMethod'] = 'Card';
      final ride = Ride.fromJson(json);

      expect(ride.paymentMethod, 'Card');
    });

    test('fromJson leaves paymentMethod null when absent', () {
      final ride = Ride.fromJson(TestFixtures.rideJson());

      expect(ride.paymentMethod, isNull);
    });

    test('toJson serializes local DateTime as UTC (ends with Z)', () {
      final localTime = DateTime(2026, 3, 15, 10, 0); // local, not UTC
      final ride = TestFixtures.ride(pickupDateTime: localTime);

      final json = ride.toJson();
      final dateStr = json['pickupDateTime'] as String;

      expect(
        dateStr.endsWith('Z'),
        isTrue,
        reason:
            'pickupDateTime must be UTC ISO-8601 (ending with Z), got: $dateStr',
      );
    });

    test('toJson serializes UTC DateTime as UTC (ends with Z)', () {
      final utcTime = DateTime.utc(2026, 3, 15, 10, 0);
      final ride = TestFixtures.ride(pickupDateTime: utcTime);

      final json = ride.toJson();
      final dateStr = json['pickupDateTime'] as String;

      expect(
        dateStr.endsWith('Z'),
        isTrue,
        reason:
            'pickupDateTime must be UTC ISO-8601 (ending with Z), got: $dateStr',
      );
      expect(dateStr, '2026-03-15T10:00:00.000Z');
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

    // Regression: a missing/malformed pickupDateTime used to throw an opaque
    // "type 'Null' is not a subtype of String" deep in DateTime.parse and take
    // down the whole ride-list parse. It must now throw a FormatException that
    // names the field, and a bad optional date (flightTime) must not throw.
    test('fromJson throws a named FormatException on bad pickupDateTime', () {
      final base = {
        'id': 'r1',
        'clientId': 'c1',
        'creatorId': 'cr1',
        'companyId': 'co1',
        'from': {'address': 'A'},
        'to': {'address': 'B'},
        'clientName': 'Client',
      };

      expect(
        () => Ride.fromJson(base),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('pickupDateTime'),
          ),
        ),
      );
      expect(
        () => Ride.fromJson({...base, 'pickupDateTime': 'garbage'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson tolerates a malformed optional flightTime', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'clientId': 'c1',
        'creatorId': 'cr1',
        'companyId': 'co1',
        'pickupDateTime': '2026-03-15T10:00:00.000Z',
        'from': {'address': 'A'},
        'to': {'address': 'B'},
        'clientName': 'Client',
        'flightTime': 'not-a-date',
      });

      expect(ride.flightTime, isNull);
    });

    // Regression: flightTime used to be parsed without .toLocal() while
    // pickupDateTime was converted, so airport flight times rendered in UTC
    // while every other time on the ride was local. Both must be local, and
    // both must round-trip back to the same UTC instant on toJson.
    test('parses flightTime to local and round-trips to UTC like pickup', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'clientId': 'c1',
        'creatorId': 'cr1',
        'companyId': 'co1',
        'pickupDateTime': '2026-03-15T10:00:00.000Z',
        'from': {'address': 'A'},
        'to': {'address': 'B'},
        'clientName': 'Client',
        'isAirportTransfer': true,
        'flightTime': '2026-03-15T09:30:00.000Z',
      });

      expect(ride.flightTime!.isUtc, isFalse);
      // Same wall-clock offset handling as pickupDateTime (also local).
      expect(ride.pickupDateTime.isUtc, isFalse);
      expect(
        ride.flightTime!.toUtc().toIso8601String(),
        '2026-03-15T09:30:00.000Z',
      );
      expect(ride.toJson()['flightTime'], '2026-03-15T09:30:00.000Z');
    });

    // Regression: paidAt/confirmedAt were left in UTC while pickupDateTime was
    // local, so day/month grouping (e.g. billing totals) drifted by the offset
    // near day boundaries. Both must be local and round-trip back to UTC.
    test('parses paidAt and confirmedAt to local, round-trips to UTC', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'clientId': 'c1',
        'creatorId': 'cr1',
        'companyId': 'co1',
        'pickupDateTime': '2026-03-15T10:00:00.000Z',
        'from': {'address': 'A'},
        'to': {'address': 'B'},
        'clientName': 'Client',
        'paidAt': '2026-01-01T23:30:00.000Z',
        'confirmedAt': '2026-03-14T08:00:00.000Z',
      });

      expect(ride.paidAt!.isUtc, isFalse);
      expect(ride.confirmedAt!.isUtc, isFalse);
      expect(
        ride.paidAt!.toUtc().toIso8601String(),
        '2026-01-01T23:30:00.000Z',
      );
      expect(ride.toJson()['paidAt'], '2026-01-01T23:30:00.000Z');
      expect(ride.toJson()['confirmedAt'], '2026-03-14T08:00:00.000Z');
    });

    test(
      'isRemoteGate detects the MUC remote-stand sentinel (case-insensitive)',
      () {
        expect(
          TestFixtures.ride(
            isAirportTransfer: true,
            gate: 'REMOTE',
          ).isRemoteGate,
          isTrue,
        );
        expect(
          TestFixtures.ride(
            isAirportTransfer: true,
            gate: 'remote',
          ).isRemoteGate,
          isTrue,
        );
        expect(
          TestFixtures.ride(isAirportTransfer: true, gate: 'G18').isRemoteGate,
          isFalse,
        );
      },
    );

    test(
      'fullFlightInfo renders a remote stand as "Bus gate", not "Gate REMOTE"',
      () {
        final ride = TestFixtures.ride(
          isAirportTransfer: true,
          flightNumber: 'LH429',
          gate: 'REMOTE',
          terminal: 'T2',
        );

        expect(ride.fullFlightInfo, contains('Bus gate'));
        expect(ride.fullFlightInfo, isNot(contains('Gate REMOTE')));
        expect(ride.fullFlightInfo, contains('Terminal T2'));
      },
    );
  });

  group('RideStatus.fromString', () {
    test('parses all known statuses', () {
      expect(RideStatus.fromString('Requested'), RideStatus.requested);
      expect(RideStatus.fromString('Assigned'), RideStatus.assigned);
      expect(RideStatus.fromString('InProgress'), RideStatus.inProgress);
      expect(RideStatus.fromString('Completed'), RideStatus.completed);
      expect(RideStatus.fromString('Cancelled'), RideStatus.cancelled);
    });

    // Regression: HandedOff was added later; fromString must recognise it
    // (mutation: remove the handedOff case from the enum to confirm this fails).
    test('parses HandedOff correctly', () {
      expect(RideStatus.fromString('HandedOff'), RideStatus.handedOff);
      // Case-insensitive match as documented by the implementation
      expect(RideStatus.fromString('handedoff'), RideStatus.handedOff);
      expect(RideStatus.fromString('HANDEDOFF'), RideStatus.handedOff);
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

  // Regression tests for RideStatus.fromStringOrNull (bug #2 fix):
  // an unknown status must return null, NOT silently fall back to [requested].
  group('RideStatus.fromStringOrNull', () {
    test('returns null for an unknown status string', () {
      // This is the critical regression: the old fromString returned requested
      // for any unrecognised value, masking cancelled/completed rides in the UI.
      expect(RideStatus.fromStringOrNull('Unknown'), isNull);
      expect(RideStatus.fromStringOrNull('garbage'), isNull);
      expect(RideStatus.fromStringOrNull(''), isNull);
      expect(RideStatus.fromStringOrNull('UNKNOWN_STATUS'), isNull);
    });

    test('correctly parses all known status strings (exact case)', () {
      expect(RideStatus.fromStringOrNull('Requested'), RideStatus.requested);
      expect(RideStatus.fromStringOrNull('Assigned'), RideStatus.assigned);
      expect(RideStatus.fromStringOrNull('InProgress'), RideStatus.inProgress);
      expect(RideStatus.fromStringOrNull('Completed'), RideStatus.completed);
      expect(RideStatus.fromStringOrNull('Cancelled'), RideStatus.cancelled);
    });

    test('correctly parses known statuses in lowercase', () {
      expect(RideStatus.fromStringOrNull('requested'), RideStatus.requested);
      expect(RideStatus.fromStringOrNull('assigned'), RideStatus.assigned);
      expect(RideStatus.fromStringOrNull('inprogress'), RideStatus.inProgress);
      expect(RideStatus.fromStringOrNull('completed'), RideStatus.completed);
      expect(RideStatus.fromStringOrNull('cancelled'), RideStatus.cancelled);
    });

    test('correctly parses known statuses in uppercase', () {
      expect(RideStatus.fromStringOrNull('REQUESTED'), RideStatus.requested);
      expect(RideStatus.fromStringOrNull('ASSIGNED'), RideStatus.assigned);
      expect(RideStatus.fromStringOrNull('CANCELLED'), RideStatus.cancelled);
    });

    // Mutation probe: if fromStringOrNull returned RideStatus.requested instead of null
    // for an unknown value, the first assertion below would fail because the result
    // would equal RideStatus.requested rather than null.
    test(
      'unknown status is NOT silently mapped to requested (regression guard)',
      () {
        final result = RideStatus.fromStringOrNull(
          'cancelled_by_driver_custom',
        );
        // Must be null, never requested or any other status
        expect(result, isNull);
        expect(result, isNot(equals(RideStatus.requested)));
      },
    );
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
      final copied = original.copyWith(clientName: 'New Name', price: 99.99);

      expect(copied.clientName, 'New Name');
      expect(copied.price, 99.99);
    });

    // Regression: flightTime used a plain `?? this.flightTime`, so passing null
    // could not clear it. It now uses the sentinel pattern: omitted keeps the
    // value, explicit null clears it.
    test('keeps flightTime when the argument is omitted', () {
      final original = TestFixtures.airportRide();
      expect(original.flightTime, isNotNull);

      final copied = original.copyWith(clientName: 'X');
      expect(copied.flightTime, original.flightTime);
    });

    test('clears flightTime when null is passed explicitly', () {
      final original = TestFixtures.airportRide();
      expect(original.flightTime, isNotNull);

      final copied = original.copyWith(flightTime: null);
      expect(copied.flightTime, isNull);
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
      expect(
        TestFixtures.airportRide(flightStatus: 'On Time').flightStatusIcon,
        '✅',
      );
      expect(
        TestFixtures.airportRide(flightStatus: 'Delayed').flightStatusIcon,
        '⏰',
      );
      expect(
        TestFixtures.airportRide(flightStatus: 'Cancelled').flightStatusIcon,
        '❌',
      );
      expect(
        TestFixtures.airportRide(flightStatus: 'landed').flightStatusIcon,
        '🛬',
      );
      // Unknown/unmapped → neutral info icon, NOT the alarming "❓".
      expect(
        TestFixtures.airportRide(flightStatus: 'unknown').flightStatusIcon,
        'ℹ️',
      );
    });

    test('flightStatusIcon returns empty for null flightStatus', () {
      final ride = TestFixtures.airportRide(flightStatus: null);
      expect(ride.flightStatusIcon, '');
    });

    test(
      'fullFlightInfo includes flight number, gate, terminal — but NOT the raw status',
      () {
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
        // The status is localized at the call site, so it is no longer baked into fullFlightInfo.
        expect(info, isNot(contains('On Time')));
      },
    );

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
      final ride = TestFixtures.ride(
        isAirportTransfer: true,
        flightNumber: null,
      );
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

    // Regression: flightInfo used to substitute DateTime.now() when flightTime
    // was null, fabricating a wrong time and hiding the missing data. An
    // airport transfer with no flight time must yield no FlightInfo at all.
    test('flightInfo returns null when airport transfer has no flightTime', () {
      final ride = TestFixtures.ride(isAirportTransfer: true);
      expect(ride.flightTime, isNull);
      expect(ride.flightInfo, isNull);
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

    // driverEnRoute getter — gates the "Driver on the way" label on the client
    // side; true only when the driver has started location tracking.
    test('driverEnRoute is false when driverLocation is null', () {
      final ride = TestFixtures.ride(); // no driverLocation by default
      expect(ride.driverEnRoute, isFalse);
    });

    test('driverEnRoute is true when driverLocation is non-null', () {
      final ride = Ride(
        id: 'ride-1',
        clientId: 'client-1',
        creatorId: 'creator-1',
        companyId: 'company-1',
        pickupDateTime: DateTime(2026, 3, 15, 10, 0),
        from: TestFixtures.location(),
        to: TestFixtures.location(address: 'Dropoff St'),
        clientName: 'Test Client',
        status: RideStatus.assigned,
        driverLocation: TestFixtures.location(
          address: 'Driver current position',
          latitude: 48.14,
          longitude: 11.57,
        ),
      );
      expect(ride.driverEnRoute, isTrue);
    });
  });

  // isTrackable — controls whether a ride should appear on the live map.
  //
  // Mutation check performed: temporarily changed `isTrackable` to always
  // return `false`; the "true" assertions below turned red. Restored the
  // correct implementation.
  group('Ride.isTrackable', () {
    test('assigned → true', () {
      expect(
        TestFixtures.ride(status: RideStatus.assigned).isTrackable,
        isTrue,
      );
    });

    test('confirmed → true', () {
      expect(
        TestFixtures.ride(status: RideStatus.confirmed).isTrackable,
        isTrue,
      );
    });

    test('inProgress → true', () {
      expect(
        TestFixtures.ride(status: RideStatus.inProgress).isTrackable,
        isTrue,
      );
    });

    test('handedOff → true', () {
      expect(
        TestFixtures.ride(status: RideStatus.handedOff).isTrackable,
        isTrue,
      );
    });

    test('requested → false (no driver yet)', () {
      expect(
        TestFixtures.ride(status: RideStatus.requested).isTrackable,
        isFalse,
      );
    });

    test('completed → false (ride is done)', () {
      expect(
        TestFixtures.ride(status: RideStatus.completed).isTrackable,
        isFalse,
      );
    });

    test('cancelled → false (ride is done)', () {
      expect(
        TestFixtures.ride(status: RideStatus.cancelled).isTrackable,
        isFalse,
      );
    });

    // Completeness guard: every RideStatus must be either trackable or not —
    // if a new status is added without updating isTrackable this test will
    // remind the author to make a conscious choice.
    test(
      'every RideStatus is covered by the trackable/non-trackable partition',
      () {
        const trackable = {
          RideStatus.assigned,
          RideStatus.confirmed,
          RideStatus.inProgress,
          RideStatus.handedOff,
        };
        const nonTrackable = {
          RideStatus.requested,
          RideStatus.completed,
          RideStatus.cancelled,
        };
        for (final status in RideStatus.values) {
          final covered =
              trackable.contains(status) || nonTrackable.contains(status);
          expect(
            covered,
            isTrue,
            reason:
                'RideStatus.$status is not listed in trackable or nonTrackable — '
                'update the isTrackable getter and this test.',
          );
        }
      },
    );
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

    // A live WS checkpoint update only re-renders if the new Ride is != the old
    // one — so airportCheckpoint must participate in equality and hashCode.
    test('a different airportCheckpoint means not equal', () {
      final a = TestFixtures.ride(airportCheckpoint: 'landed');
      final b = a.copyWith(airportCheckpoint: 'terminal_exit');
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });
  });
}
