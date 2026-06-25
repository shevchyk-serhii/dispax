import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/models/websocket_event.dart';
import 'package:dispax/modules/ride_management/models/public_ride.dart';
import 'package:dispax/modules/ride_management/services/guest_track_service.dart';
import 'package:dispax/modules/ride_management/services/ride_service.dart';
import 'package:dispax/screens/guest_tracking_screen.dart';
import 'package:dispax/main.dart';

const _ridePayload = {
  'status': 'InProgress',
  'pickup': {
    'address': 'Marienplatz 1',
    'latitude': 48.1373,
    'longitude': 11.5754,
  },
  'dropoff': {
    'address': 'Flughafen MUC',
    'latitude': 48.3537,
    'longitude': 11.7861,
  },
  'driverLocation': {
    'latitude': 48.14,
    'longitude': 11.58,
    'updatedAt': '2026-06-25T10:00:00Z',
  },
  'etaMinutes': 7,
  'driverAssigned': true,
};

void main() {
  group('PublicRide.fromJson', () {
    test('parses the sanitized backend shape', () {
      final ride = PublicRide.fromJson(_ridePayload);
      expect(ride.status, 'InProgress');
      expect(ride.pickup.address, 'Marienplatz 1');
      expect(ride.dropoff.address, 'Flughafen MUC');
      expect(ride.driverLatitude, 48.14);
      expect(ride.etaMinutes, 7);
      expect(ride.driverAssigned, isTrue);
      expect(ride.hasDriverLocation, isTrue);
    });

    test('toJson-equivalent surface is minimal (no identity / price leak)', () {
      // The model's only data is status + route + driver coords + eta + driverAssigned. There are no driverId /
      // clientId / driverName / price members — referencing any would fail to compile, which is the real guard.
      final ride = PublicRide.fromJson(_ridePayload);
      expect(ride.runtimeType.toString(), 'PublicRide');
      expect(ride.hasDriverLocation, isTrue);
    });
  });

  group('GuestTrackService', () {
    test('fetchPublicRide returns the parsed ride on 200', () async {
      final client = MockClient(
        (req) async => http.Response(jsonEncode(_ridePayload), 200),
      );
      final service = GuestTrackService(
        apiClient: ApiClient(client: client, baseUrl: 'http://x/api'),
      );
      final ride = await service.fetchPublicRide('tok123');
      expect(ride.status, 'InProgress');
    });

    test('fetchPublicRide throws GuestLinkExpiredException on 404', () async {
      final client = MockClient(
        (req) async => http.Response('{"error":"not found"}', 404),
      );
      final service = GuestTrackService(
        apiClient: ApiClient(client: client, baseUrl: 'http://x/api'),
      );
      expect(
        () => service.fetchPublicRide('bad'),
        throwsA(isA<GuestLinkExpiredException>()),
      );
    });

    test(
      'fetchPublicRide sends NO Authorization header (guest, no token)',
      () async {
        late Map<String, String> headers;
        final client = MockClient((req) async {
          headers = req.headers;
          return http.Response(jsonEncode(_ridePayload), 200);
        });
        final service = GuestTrackService(
          apiClient: ApiClient(client: client, baseUrl: 'http://x/api'),
        );
        await service.fetchPublicRide('tok');
        expect(headers.containsKey('Authorization'), isFalse);
      },
    );
  });

  group('GuestTrackingScreen.shouldApplyGuestDriverLocation', () {
    WebSocketEvent loc(String type, {String location = 'driver'}) =>
        WebSocketEvent(
          type: type,
          companyId: '',
          locationType: location,
          latitude: 1.0,
          longitude: 2.0,
        );

    test('driver location update => applied', () {
      expect(
        GuestTrackingScreen.shouldApplyGuestDriverLocation(
          loc('LocationUpdated'),
        ),
        isTrue,
      );
    });

    test(
      'client location update => NOT applied (never show client position)',
      () {
        expect(
          GuestTrackingScreen.shouldApplyGuestDriverLocation(
            loc('LocationUpdated', location: 'client'),
          ),
          isFalse,
        );
      },
    );

    test('non-location event => NOT applied', () {
      expect(
        GuestTrackingScreen.shouldApplyGuestDriverLocation(
          const WebSocketEvent(type: 'RideStatusChanged', companyId: ''),
        ),
        isFalse,
      );
    });
  });

  group('main.guestTrackingTokenFromPath', () {
    test('extracts token from /track/<token>', () {
      expect(guestTrackingTokenFromPath('/track/abc123'), 'abc123');
    });
    test('returns null for a non-track path', () {
      expect(guestTrackingTokenFromPath('/dashboard'), isNull);
    });
    test('ignores query string', () {
      expect(guestTrackingTokenFromPath('/track/xyz?foo=bar'), 'xyz');
    });
  });

  group('RideService.createShareLink', () {
    test('builds an absolute URL from the backend path', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'token': 'tok42', 'path': '/track/tok42'}),
          200,
        );
      });
      final service = RideService(
        apiClient: ApiClient(client: client, baseUrl: 'http://x/api'),
      );
      final url = await service.createShareLink('ride-1');
      expect(captured.url.path, '/api/rides/ride-1/share-link');
      expect(url, endsWith('/track/tok42'));
    });
  });

  group('GuestTrackingScreen.guestStatusLabel', () {
    testWidgets('maps statuses to localized labels (EN)', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        GuestTrackingScreen.guestStatusLabel(
          l10n,
          'Requested',
          driverAssigned: false,
        ),
        'Finding a driver',
      );
      expect(
        GuestTrackingScreen.guestStatusLabel(
          l10n,
          'InProgress',
          driverAssigned: true,
        ),
        'On trip',
      );
      expect(
        GuestTrackingScreen.guestStatusLabel(
          l10n,
          'Completed',
          driverAssigned: true,
        ),
        'Trip completed',
      );
      expect(
        GuestTrackingScreen.guestStatusLabel(
          l10n,
          'Cancelled',
          driverAssigned: true,
        ),
        'Trip cancelled',
      );
    });
  });
}
