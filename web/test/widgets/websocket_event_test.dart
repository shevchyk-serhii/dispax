// Tests for WebSocketEvent.isEtaAtRisk getter and the EtaAtRisk payload
// accessor getters.
//
// The Scala backend emits an EtaAtRisk WS event encoded by ZIO-JSON as a
// discriminated union:
//   {"EtaAtRisk": {"rideId":..., "driverId":..., "etaMinutes":...,
//                  "minutesUntilPickup":..., "slackMinutes":..., ...}}
//
// The Scala case-class field is `minutesUntilPickup`. The Flutter getter
// `pickupInMinutes` reads `data['minutesUntilPickup']` to match this wire
// field name.

import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/models/websocket_event.dart';

// Helpers ------------------------------------------------------------------

/// A typical ZIO-JSON encoded EtaAtRisk WS payload as the server sends it.
/// Field name is `minutesUntilPickup` matching the Scala case-class field.
Map<String, dynamic> _etaAtRiskJson({
  String rideId = 'ride-abc',
  String driverId = 'driver-xyz',
  String clientId = 'client-111',
  int etaMinutes = 12,
  int minutesUntilPickup = 7,
  int slackMinutes = -5,
  String companyId = 'company-99',
}) => {
  'EtaAtRisk': {
    'rideId': rideId,
    'driverId': driverId,
    'clientId': clientId,
    'etaMinutes': etaMinutes,
    'minutesUntilPickup': minutesUntilPickup,
    'slackMinutes': slackMinutes,
    'companyId': companyId,
  },
};

/// A non-EtaAtRisk event for negative-type assertions.
Map<String, dynamic> _rideStatusChangedJson() => {
  'RideStatusChanged': {
    'rideId': 'ride-001',
    'newStatus': 'Assigned',
    'driverId': 'driver-001',
    'clientId': 'client-001',
    'companyId': 'company-01',
  },
};

void main() {
  group('WebSocketEvent.isEtaAtRisk', () {
    test('returns true for an EtaAtRisk payload', () {
      final event = WebSocketEvent.fromJson(_etaAtRiskJson());
      expect(event.isEtaAtRisk, isTrue);
    });

    test('returns false for a non-EtaAtRisk event', () {
      final event = WebSocketEvent.fromJson(_rideStatusChangedJson());
      expect(event.isEtaAtRisk, isFalse);
    });

    test('type is "EtaAtRisk"', () {
      final event = WebSocketEvent.fromJson(_etaAtRiskJson());
      expect(event.type, equals('EtaAtRisk'));
    });
  });

  group('WebSocketEvent EtaAtRisk field accessors', () {
    late WebSocketEvent event;

    setUp(() {
      event = WebSocketEvent.fromJson(
        _etaAtRiskJson(
          rideId: 'ride-abc',
          driverId: 'driver-xyz',
          etaMinutes: 12,
          minutesUntilPickup: 7,
          slackMinutes: -5,
        ),
      );
    });

    test('etaRiskDriverId returns driverId from payload', () {
      expect(event.etaRiskDriverId, equals('driver-xyz'));
    });

    test('etaMinutes returns etaMinutes from payload', () {
      expect(event.etaMinutes, equals(12));
    });

    test('slackMinutes returns slackMinutes (negative = at risk)', () {
      expect(event.slackMinutes, equals(-5));
      expect(
        event.slackMinutes! < 0,
        isTrue,
        reason: 'negative slack means driver is late',
      );
    });

    // ------------------------------------------------------------------
    // PRODUCTION BUG: the Scala EtaAtRisk case class uses
    // `minutesUntilPickup` as the field name.  ZIO-JSON encodes it
    // literally as "minutesUntilPickup" in the JSON payload.
    //
    // The Flutter getter reads `data['pickupInMinutes']`, which is a
    // different key and will always be null for a real server payload.
    //
    // The test below asserts the CORRECT behaviour (getter returns the
    // actual value).  It WILL FAIL until the production code is fixed to
    // use `data['minutesUntilPickup']` (or the backend renames its field
    // to `pickupInMinutes`).
    // ------------------------------------------------------------------
    test(
      'pickupInMinutes reads minutesUntilPickup from real server payload',
      () {
        // The raw data map has key 'minutesUntilPickup' (Scala field name).
        expect(
          event.data.containsKey('minutesUntilPickup'),
          isTrue,
          reason: 'server encodes the field as minutesUntilPickup',
        );
        expect(
          event.data.containsKey('pickupInMinutes'),
          isFalse,
          reason: 'server does NOT send pickupInMinutes',
        );
        // Getter now correctly reads data['minutesUntilPickup'].
        expect(
          event.pickupInMinutes,
          equals(7),
          reason:
              'pickupInMinutes getter must read data["minutesUntilPickup"] '
              'to match the Scala EtaAtRisk wire field name',
        );
      },
    );
  });

  group('WebSocketEvent EtaAtRisk edge cases', () {
    test('handles zero slack (exactly on threshold)', () {
      final event = WebSocketEvent.fromJson(
        _etaAtRiskJson(etaMinutes: 7, minutesUntilPickup: 7, slackMinutes: 0),
      );
      expect(event.slackMinutes, equals(0));
      expect(event.etaMinutes, equals(7));
    });

    test('handles large negative slack (very late)', () {
      final event = WebSocketEvent.fromJson(
        _etaAtRiskJson(
          etaMinutes: 30,
          minutesUntilPickup: 5,
          slackMinutes: -25,
        ),
      );
      expect(event.slackMinutes, equals(-25));
    });

    test('etaMinutes works when value is an integer JSON number', () {
      // ZIO-JSON always encodes Int as a JSON number; toInt() must handle it.
      final event = WebSocketEvent.fromJson(_etaAtRiskJson(etaMinutes: 3));
      expect(event.etaMinutes, equals(3));
    });

    test('companyId is populated from nested payload', () {
      final event = WebSocketEvent.fromJson(
        _etaAtRiskJson(companyId: 'company-99'),
      );
      expect(event.companyId, equals('company-99'));
    });

    test('isRideStatusChanged is false for EtaAtRisk', () {
      final event = WebSocketEvent.fromJson(_etaAtRiskJson());
      expect(event.isRideStatusChanged, isFalse);
    });

    test('isLocationUpdated is false for EtaAtRisk', () {
      final event = WebSocketEvent.fromJson(_etaAtRiskJson());
      expect(event.isLocationUpdated, isFalse);
    });
  });
}
