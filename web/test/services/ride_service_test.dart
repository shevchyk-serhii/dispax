import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:oktopus/modules/core/services/api_client.dart';
import 'package:oktopus/modules/ride_management/models/ride.dart';
import 'package:oktopus/modules/ride_management/services/ride_service.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class FakeUri extends Fake implements Uri {}

void main() {
  late MockApiClient mockApiClient;
  late RideService rideService;

  setUpAll(() {
    registerFallbackValue(FakeUri());
    registerFallbackValue(TestFixtures.person());
    registerFallbackValue(TestFixtures.createRideRequest());
    registerFallbackValue(TestFixtures.ride());
    registerFallbackValue(RideStatus.requested);
  });

  setUp(() {
    mockApiClient = MockApiClient();
    rideService = RideService(apiClient: mockApiClient);
    when(() => mockApiClient.dispose()).thenReturn(null);
  });

  http.Response jsonResponse(dynamic body, {int statusCode = 200}) {
    return http.Response(jsonEncode(body), statusCode);
  }

  group('RideService', () {
    group('getAllRides', () {
      test('200 returns parsed list', () async {
        when(() => mockApiClient.get('/rides')).thenAnswer(
          (_) async =>
              jsonResponse([TestFixtures.rideJson(), TestFixtures.rideJson(id: 'ride-2')]),
        );

        final rides = await rideService.getAllRides();
        expect(rides.length, 2);
        expect(rides.first, isA<Ride>());
      });

      test('non-200 throws ApiException', () async {
        when(() => mockApiClient.get('/rides')).thenAnswer(
          (_) async => jsonResponse({'error': 'fail'}, statusCode: 500),
        );

        expect(
          () => rideService.getAllRides(),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('getRidesForUser', () {
      test('200 returns parsed list for client', () async {
        final client = TestFixtures.person(); // role: client, id: person-1
        when(() => mockApiClient.get('/rides/client/${client.id}')).thenAnswer(
          (_) async => jsonResponse([TestFixtures.rideJson()]),
        );

        final rides = await rideService.getRidesForUser(client);
        expect(rides.length, 1);
      });

      test('200 returns parsed list for secretary (uses /rides)', () async {
        final secretary = TestFixtures.secretary();
        when(() => mockApiClient.get('/rides')).thenAnswer(
          (_) async => jsonResponse([TestFixtures.rideJson()]),
        );

        final rides = await rideService.getRidesForUser(secretary);
        expect(rides.length, 1);
      });
    });

    group('getRideById', () {
      test('200 returns Ride', () async {
        when(() => mockApiClient.get('/rides/ride-1')).thenAnswer(
          (_) async => jsonResponse(TestFixtures.rideJson()),
        );

        final ride = await rideService.getRideById('ride-1');
        expect(ride, isNotNull);
        expect(ride!.id, 'ride-1');
      });

      test('404 returns null', () async {
        when(() => mockApiClient.get('/rides/missing')).thenAnswer(
          (_) async => jsonResponse({}, statusCode: 404),
        );

        final ride = await rideService.getRideById('missing');
        expect(ride, isNull);
      });
    });

    group('createRide', () {
      test('201 returns Ride', () async {
        when(() => mockApiClient.post('/rides', any())).thenAnswer(
          (_) async =>
              jsonResponse(TestFixtures.rideJson(id: 'created'), statusCode: 201),
        );

        final ride =
            await rideService.createRide(TestFixtures.createRideRequest());
        expect(ride.id, 'created');
      });

      test('non-201 throws', () async {
        when(() => mockApiClient.post('/rides', any())).thenAnswer(
          (_) async => jsonResponse({}, statusCode: 400),
        );

        expect(
          () => rideService.createRide(TestFixtures.createRideRequest()),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('updateRide', () {
      test('200 returns Ride', () async {
        when(() => mockApiClient.put('/rides/ride-1', any())).thenAnswer(
          (_) async => jsonResponse(TestFixtures.rideJson()),
        );

        final ride =
            await rideService.updateRide('ride-1', TestFixtures.ride());
        expect(ride, isNotNull);
      });

      test('404 returns null', () async {
        when(() => mockApiClient.put('/rides/missing', any())).thenAnswer(
          (_) async => jsonResponse({}, statusCode: 404),
        );

        final ride =
            await rideService.updateRide('missing', TestFixtures.ride());
        expect(ride, isNull);
      });
    });

    group('updateRideStatus', () {
      test('200 returns true', () async {
        when(() => mockApiClient.put('/rides/ride-1/status', any()))
            .thenAnswer((_) async => jsonResponse({}));

        expect(
          await rideService.updateRideStatus('ride-1', RideStatus.completed),
          isTrue,
        );
      });

      test('404 returns false', () async {
        when(() => mockApiClient.put('/rides/missing/status', any()))
            .thenAnswer((_) async => jsonResponse({}, statusCode: 404));

        expect(
          await rideService.updateRideStatus('missing', RideStatus.completed),
          isFalse,
        );
      });
    });

    group('getPendingRides', () {
      test('200 returns list', () async {
        when(() => mockApiClient.get('/rides/pending')).thenAnswer(
          (_) async => jsonResponse([TestFixtures.rideJson()]),
        );

        final rides = await rideService.getPendingRides();
        expect(rides.length, 1);
      });
    });

    group('assignDriver', () {
      test('200 returns Ride', () async {
        when(() =>
                mockApiClient.put('/rides/ride-1/assign-driver', any()))
            .thenAnswer(
          (_) async => jsonResponse(TestFixtures.rideJson()),
        );

        final ride = await rideService.assignDriver('ride-1', 'driver-1');
        expect(ride, isA<Ride>());
      });
    });

    group('reassignDriver', () {
      test('200 returns Ride', () async {
        when(() =>
                mockApiClient.put('/rides/ride-1/reassign-driver', any()))
            .thenAnswer(
          (_) async => jsonResponse(TestFixtures.rideJson()),
        );

        final ride = await rideService.reassignDriver('ride-1', 'driver-2');
        expect(ride, isA<Ride>());
      });
    });

    group('getDriverProximity', () {
      test('200 returns map', () async {
        when(() => mockApiClient.get('/rides/ride-1/driver-location'))
            .thenAnswer(
          (_) async => jsonResponse({
            'latitude': 48.1,
            'longitude': 11.5,
            'distance': 500,
          }),
        );

        final result = await rideService.getDriverProximity('ride-1');
        expect(result, isNotNull);
        expect(result!['latitude'], 48.1);
      });

      test('error returns null', () async {
        when(() => mockApiClient.get('/rides/ride-1/driver-location'))
            .thenThrow(ApiException('fail'));

        final result = await rideService.getDriverProximity('ride-1');
        expect(result, isNull);
      });
    });

    group('updateDriverLocation', () {
      test('error fails silently', () async {
        when(() => mockApiClient.put(any(), any()))
            .thenThrow(ApiException('fail'));

        // Should not throw
        await rideService.updateDriverLocation('driver-1', 48.1, 11.5);
      });
    });

    group('cancelRide', () {
      test('200 completes without error', () async {
        when(() => mockApiClient.put('/rides/ride-1/cancel', any()))
            .thenAnswer((_) async => jsonResponse({}));

        await expectLater(
          rideService.cancelRide('ride-1', 'Client Request'),
          completes,
        );
      });

      test('sends reason to correct endpoint', () async {
        Map<String, dynamic>? capturedBody;
        when(() => mockApiClient.put('/rides/ride-1/cancel', any()))
            .thenAnswer((invocation) async {
          capturedBody = invocation.positionalArguments[1] as Map<String, dynamic>;
          return jsonResponse({});
        });

        await rideService.cancelRide('ride-1', 'Client Request');

        expect(capturedBody?['reason'], 'Client Request');
        expect(capturedBody?.containsKey('status'), isFalse);
      });

      test('non-200 throws ApiException', () async {
        when(() => mockApiClient.put('/rides/ride-1/cancel', any()))
            .thenAnswer((_) async => jsonResponse({}, statusCode: 400));

        expect(
          () => rideService.cancelRide('ride-1', 'Other'),
          throwsA(isA<ApiException>()),
        );
      });

      test('network error throws ApiException', () async {
        when(() => mockApiClient.put('/rides/ride-1/cancel', any()))
            .thenThrow(ApiException('Network error'));

        expect(
          () => rideService.cancelRide('ride-1', 'Other'),
          throwsA(isA<ApiException>()),
        );
      });

      test('sends fee when provided', () async {
        Map<String, dynamic>? capturedBody;
        when(() => mockApiClient.put('/rides/ride-1/cancel', any()))
            .thenAnswer((invocation) async {
          capturedBody = invocation.positionalArguments[1] as Map<String, dynamic>;
          return jsonResponse({});
        });

        await rideService.cancelRide('ride-1', 'No show', fee: 25.0);

        expect(capturedBody?['reason'], 'No show');
        expect(capturedBody?['fee'], 25.0);
      });

      test('does not send fee when not provided', () async {
        Map<String, dynamic>? capturedBody;
        when(() => mockApiClient.put('/rides/ride-1/cancel', any()))
            .thenAnswer((invocation) async {
          capturedBody = invocation.positionalArguments[1] as Map<String, dynamic>;
          return jsonResponse({});
        });

        await rideService.cancelRide('ride-1', 'Client Request');

        expect(capturedBody?.containsKey('fee'), isFalse);
      });
    });
  });
}
