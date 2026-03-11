import 'package:flutter_test/flutter_test.dart';
import 'package:oktopus/modules/core/models/websocket_event.dart';

void main() {
  group('WebSocketEvent', () {
    test('fromJson parses all fields', () {
      final json = {
        'type': 'RideStatusChanged',
        'rideId': 'ride-1',
        'driverId': 'driver-1',
        'clientId': 'client-1',
        'newStatus': 'Completed',
        'latitude': 48.1,
        'longitude': 11.5,
        'locationType': 'driver',
        'companyId': 'company-1',
      };

      final event = WebSocketEvent.fromJson(json);

      expect(event.type, 'RideStatusChanged');
      expect(event.rideId, 'ride-1');
      expect(event.driverId, 'driver-1');
      expect(event.clientId, 'client-1');
      expect(event.newStatus, 'Completed');
      expect(event.latitude, 48.1);
      expect(event.longitude, 11.5);
      expect(event.locationType, 'driver');
      expect(event.companyId, 'company-1');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'type': 'RideCreated',
        'companyId': 'company-1',
      };

      final event = WebSocketEvent.fromJson(json);

      expect(event.type, 'RideCreated');
      expect(event.rideId, isNull);
      expect(event.driverId, isNull);
      expect(event.newStatus, isNull);
    });

    test('isRideStatusChanged', () {
      final event = WebSocketEvent.fromJson({
        'type': 'RideStatusChanged',
        'companyId': 'c1',
      });
      expect(event.isRideStatusChanged, isTrue);
      expect(event.isRideAssigned, isFalse);
    });

    test('isRideAssigned', () {
      final event = WebSocketEvent.fromJson({
        'type': 'RideAssigned',
        'companyId': 'c1',
      });
      expect(event.isRideAssigned, isTrue);
      expect(event.isRideCreated, isFalse);
    });

    test('isRideCreated', () {
      final event = WebSocketEvent.fromJson({
        'type': 'RideCreated',
        'companyId': 'c1',
      });
      expect(event.isRideCreated, isTrue);
      expect(event.isLocationUpdated, isFalse);
    });

    test('isLocationUpdated', () {
      final event = WebSocketEvent.fromJson({
        'type': 'LocationUpdated',
        'companyId': 'c1',
      });
      expect(event.isLocationUpdated, isTrue);
      expect(event.isChatMessage, isFalse);
    });

    test('isChatMessage', () {
      final event = WebSocketEvent.fromJson({
        'type': 'ChatMessageSent',
        'companyId': 'c1',
      });
      expect(event.isChatMessage, isTrue);
      expect(event.isRideStatusChanged, isFalse);
    });

    test('data stores original json', () {
      final json = {
        'type': 'RideCreated',
        'companyId': 'c1',
        'extra': 'data',
      };
      final event = WebSocketEvent.fromJson(json);
      expect(event.data['extra'], 'data');
    });
  });
}
