import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/models/websocket_event.dart';

void main() {
  group('WebSocketEvent', () {
    // Server sends ZIO sealed trait format: {"TypeName": {payload}}
    test('fromJson parses ZIO sealed trait format', () {
      final json = {
        'RideStatusChanged': {
          'rideId': 'ride-1',
          'driverId': 'driver-1',
          'clientId': 'client-1',
          'newStatus': 'Completed',
          'companyId': 'company-1',
        },
      };

      final event = WebSocketEvent.fromJson(json);

      expect(event.type, 'RideStatusChanged');
      expect(event.rideId, 'ride-1');
      expect(event.driverId, 'driver-1');
      expect(event.clientId, 'client-1');
      expect(event.newStatus, 'Completed');
      expect(event.companyId, 'company-1');
    });

    test('fromJson parses LocationUpdated with userId as driverId', () {
      final json = {
        'LocationUpdated': {
          'userId': 'driver-1',
          'latitude': 48.1,
          'longitude': 11.5,
          'locationType': 'driver',
          'companyId': 'company-1',
        },
      };

      final event = WebSocketEvent.fromJson(json);

      expect(event.type, 'LocationUpdated');
      expect(event.driverId, 'driver-1');
      expect(event.latitude, 48.1);
      expect(event.longitude, 11.5);
      expect(event.locationType, 'driver');
      expect(event.companyId, 'company-1');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'RideCreated': {
          'rideId': 'ride-1',
          'companyId': 'company-1',
        },
      };

      final event = WebSocketEvent.fromJson(json);

      expect(event.type, 'RideCreated');
      expect(event.rideId, 'ride-1');
      expect(event.driverId, isNull);
      expect(event.newStatus, isNull);
      expect(event.latitude, isNull);
      expect(event.longitude, isNull);
    });

    test('isRideStatusChanged', () {
      final event = WebSocketEvent.fromJson({
        'RideStatusChanged': {'companyId': 'c1'},
      });
      expect(event.isRideStatusChanged, isTrue);
      expect(event.isRideAssigned, isFalse);
    });

    test('isRideAssigned', () {
      final event = WebSocketEvent.fromJson({
        'RideAssigned': {'companyId': 'c1'},
      });
      expect(event.isRideAssigned, isTrue);
      expect(event.isRideCreated, isFalse);
    });

    test('isRideCreated', () {
      final event = WebSocketEvent.fromJson({
        'RideCreated': {'companyId': 'c1'},
      });
      expect(event.isRideCreated, isTrue);
      expect(event.isLocationUpdated, isFalse);
    });

    test('isLocationUpdated', () {
      final event = WebSocketEvent.fromJson({
        'LocationUpdated': {'companyId': 'c1'},
      });
      expect(event.isLocationUpdated, isTrue);
      expect(event.isChatMessage, isFalse);
    });

    test('isChatMessage', () {
      final event = WebSocketEvent.fromJson({
        'ChatMessageSent': {'companyId': 'c1'},
      });
      expect(event.isChatMessage, isTrue);
      expect(event.isRideStatusChanged, isFalse);
    });

    test('data stores payload fields', () {
      final json = {
        'RideCreated': {
          'companyId': 'c1',
          'extra': 'value',
        },
      };
      final event = WebSocketEvent.fromJson(json);
      expect(event.data['extra'], 'value');
      expect(event.data['companyId'], 'c1');
    });

    test('driverId falls back to userId field', () {
      final json = {
        'LocationUpdated': {
          'userId': 'driver-uuid',
          'companyId': 'c1',
        },
      };
      final event = WebSocketEvent.fromJson(json);
      expect(event.driverId, 'driver-uuid');
    });

    test('driverId prefers driverId over userId', () {
      final json = {
        'RideAssigned': {
          'driverId': 'driver-uuid',
          'userId': 'other-uuid',
          'companyId': 'c1',
        },
      };
      final event = WebSocketEvent.fromJson(json);
      expect(event.driverId, 'driver-uuid');
    });
  });
}
