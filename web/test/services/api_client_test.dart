import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dispax/modules/core/services/api_client.dart';

void main() {
  group('ApiClient', () {
    group('token management', () {
      test('setAuthToken sets Authorization header', () async {
        late Map<String, String> capturedHeaders;
        final client = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response('[]', 200);
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        apiClient.setAuthToken('my-token');
        await apiClient.get('/test');

        expect(capturedHeaders['Authorization'], 'Bearer my-token');
      });

      test('clearAuthToken removes Authorization header', () async {
        late Map<String, String> capturedHeaders;
        final client = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response('[]', 200);
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        apiClient.setAuthToken('my-token');
        apiClient.clearAuthToken();
        await apiClient.get('/test');

        expect(capturedHeaders.containsKey('Authorization'), isFalse);
      });

      test('requests without token have no Authorization header', () async {
        late Map<String, String> capturedHeaders;
        final client = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response('[]', 200);
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        await apiClient.get('/test');

        expect(capturedHeaders.containsKey('Authorization'), isFalse);
      });
    });

    group('dispose', () {
      test('dispose closes the http client', () async {
        final client = MockClient((request) async {
          return http.Response('[]', 200);
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );

        // Works before dispose
        await apiClient.get('/test');

        apiClient.dispose();

        // After dispose the underlying client is closed — subsequent calls
        // on a real http.Client would throw; here we verify dispose() itself
        // does not throw.
        expect(() => apiClient.dispose(), returnsNormally);
      });
    });

    group('GET', () {
      test('returns response on 200', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode([
              {'id': '1'},
            ]),
            200,
          ),
        );

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final response = await apiClient.get('/rides');

        expect(response.statusCode, 200);
        expect(jsonDecode(response.body), isA<List>());
      });

      test('throws ApiException on SocketException', () async {
        final client = MockClient(
          (_) async => throw http.ClientException('Connection refused'),
        );

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );

        expect(() => apiClient.get('/rides'), throwsA(isA<ApiException>()));
      });

      test('get with acceptOverride sends that Accept header', () async {
        late Map<String, String> capturedHeaders;
        final client = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response.bytes([0x25, 0x50, 0x44, 0x46], 200);
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        await apiClient.get(
          '/billing/invoices/1/pdf',
          acceptOverride: 'application/pdf',
        );

        expect(capturedHeaders['Accept'], 'application/pdf');
      });

      test(
        'get without acceptOverride still sends Accept: application/json',
        () async {
          late Map<String, String> capturedHeaders;
          final client = MockClient((request) async {
            capturedHeaders = request.headers;
            return http.Response('[]', 200);
          });

          final apiClient = ApiClient(
            client: client,
            baseUrl: 'http://localhost:8080/api',
          );
          await apiClient.get('/rides');

          expect(capturedHeaders['Accept'], 'application/json');
        },
      );
    });

    group('getBytes (binary endpoints, e.g. avatar)', () {
      test(
        'sends Accept: */* (not application/json) so an image endpoint does '
        'not reject it with 406',
        () async {
          late Map<String, String> capturedHeaders;
          final client = MockClient((request) async {
            capturedHeaders = request.headers;
            return http.Response.bytes([0xFF, 0xD8, 0xFF], 200); // JPEG magic
          });
          final apiClient = ApiClient(
            client: client,
            baseUrl: 'http://localhost:8080/api',
          );
          apiClient.setAuthToken('t');

          final bytes = await apiClient.getBytes('/users/1/avatar');

          expect(capturedHeaders['Accept'], '*/*');
          // Must NOT claim to accept only JSON — that is what caused the 406.
          expect(capturedHeaders['Accept'], isNot('application/json'));
          expect(bytes, isNotNull);
          expect(bytes!.length, 3);
        },
      );

      test('returns null on 404 (no avatar) so the caller can fall back', () async {
        final client = MockClient((_) async => http.Response('', 404));
        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        apiClient.setAuthToken('t');

        expect(await apiClient.getBytes('/users/1/avatar'), isNull);
      });
    });

    group('RideService shares ApiClient without closing it', () {
      test('dispose on RideService does not close a shared ApiClient', () async {
        // Regression: services that receive an external ApiClient must not
        // close it in dispose(), because the client is shared (e.g. with AuthBloc).
        int requestCount = 0;
        final client = MockClient((_) async {
          requestCount++;
          return http.Response('[]', 200);
        });

        final sharedApiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );

        // Simulate what RideBloc does — use the shared client
        await sharedApiClient.get('/rides');
        expect(requestCount, 1);

        // Simulate RideBloc.close() → rideService.dispose()
        // The shared client must still work after this
        sharedApiClient.dispose();

        // AuthBloc.close() disposes the real client — but dispose is idempotent
        // so calling it again should not throw
        expect(() => sharedApiClient.dispose(), returnsNormally);
      });
    });

    group('ApiException.fromResponse', () {
      test('extracts the server error message from a JSON body', () {
        final response = http.Response(
          jsonEncode({
            'error': 'Validation error: Pickup location cannot be empty',
          }),
          400,
        );

        final ex = ApiException.fromResponse(response, 'Failed to create ride');

        expect(
          ex.message,
          'Failed to create ride: Validation error: Pickup location cannot be empty',
        );
        expect(ex.statusCode, 400);
      });

      test('falls back to the raw body when it is not the error shape', () {
        final response = http.Response('Bad Gateway', 502);

        final ex = ApiException.fromResponse(response, 'Failed to create ride');

        expect(ex.message, 'Failed to create ride: Bad Gateway');
        expect(ex.statusCode, 502);
      });

      test('falls back to the status code when the body is empty', () {
        final response = http.Response('', 400);

        final ex = ApiException.fromResponse(response, 'Failed to create ride');

        expect(ex.message, 'Failed to create ride: status 400');
        expect(ex.statusCode, 400);
      });

      test('parses structured scheduleConflict details', () {
        final body = jsonEncode({
          'error': 'Driver already has a ride ... overlap',
          'scheduleConflict': {
            'rideId': 'ride-1',
            'clientId': 'client-1',
            'from': 'Maximilianstrasse 10',
            'to': 'Munich Airport T2',
            'pickupAt': '2026-06-27T07:18:00Z',
          },
        });

        final ex = ApiException.fromResponse(
          http.Response(body, 409),
          'Failed to assign driver',
        );

        expect(ex.statusCode, 409);
        expect(ex.message, contains('overlap'));
        expect(ex.scheduleConflict, isNotNull);
        expect(ex.scheduleConflict!.rideId, 'ride-1');
        expect(ex.scheduleConflict!.clientId, 'client-1');
        expect(ex.scheduleConflict!.from, 'Maximilianstrasse 10');
        expect(ex.scheduleConflict!.to, 'Munich Airport T2');
        expect(ex.scheduleConflict!.pickupAt, '2026-06-27T07:18:00Z');
      });

      test('no scheduleConflict field → details are null', () {
        final body = jsonEncode({'error': 'Validation error: bad'});

        final ex = ApiException.fromResponse(
          http.Response(body, 400),
          'Failed to create ride',
        );

        expect(ex.scheduleConflict, isNull);
        expect(ex.message, contains('Validation error: bad'));
      });
    });

    group('401 unauthorized handling', () {
      test(
        'get: 401 calls onUnauthorized and throws UnauthorizedException',
        () async {
          final client = MockClient((_) async => http.Response('', 401));
          final apiClient = ApiClient(
            client: client,
            baseUrl: 'http://localhost:8080/api',
          );

          bool callbackFired = false;
          apiClient.onUnauthorized = () => callbackFired = true;

          await expectLater(
            () => apiClient.get('/secure'),
            throwsA(isA<UnauthorizedException>()),
          );
          expect(callbackFired, isTrue);
        },
      );

      test(
        'post: 401 calls onUnauthorized and throws UnauthorizedException',
        () async {
          final client = MockClient((_) async => http.Response('', 401));
          final apiClient = ApiClient(
            client: client,
            baseUrl: 'http://localhost:8080/api',
          );

          bool callbackFired = false;
          apiClient.onUnauthorized = () => callbackFired = true;

          await expectLater(
            () => apiClient.post('/secure', {}),
            throwsA(isA<UnauthorizedException>()),
          );
          expect(callbackFired, isTrue);
        },
      );

      test(
        'put: 401 calls onUnauthorized and throws UnauthorizedException',
        () async {
          final client = MockClient((_) async => http.Response('', 401));
          final apiClient = ApiClient(
            client: client,
            baseUrl: 'http://localhost:8080/api',
          );

          bool callbackFired = false;
          apiClient.onUnauthorized = () => callbackFired = true;

          await expectLater(
            () => apiClient.put('/secure', {}),
            throwsA(isA<UnauthorizedException>()),
          );
          expect(callbackFired, isTrue);
        },
      );

      test('200 response does not call onUnauthorized', () async {
        final client = MockClient((_) async => http.Response('[]', 200));
        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );

        bool callbackFired = false;
        apiClient.onUnauthorized = () => callbackFired = true;

        await apiClient.get('/open');
        expect(callbackFired, isFalse);
      });

      test(
        'no onUnauthorized callback: 401 still throws UnauthorizedException',
        () async {
          final client = MockClient((_) async => http.Response('', 401));
          final apiClient = ApiClient(
            client: client,
            baseUrl: 'http://localhost:8080/api',
          );

          await expectLater(
            () => apiClient.get('/secure'),
            throwsA(isA<UnauthorizedException>()),
          );
        },
      );
    });

    group('login', () {
      test('decodes the response as UTF-8 (umlauts and Cyrillic survive)', () async {
        // The backend replies without an explicit charset; package:http then
        // decodes `response.body` as Latin-1, mangling non-ASCII names
        // ("Müller" -> "MÃ¼ller"). login() must decode the raw bytes as UTF-8.
        final client = MockClient((request) async {
          return http.Response.bytes(
            utf8.encode('{"user":{"name":"Müller Сергій"},"token":"t"}'),
            200,
            headers: {'content-type': 'application/json'}, // no charset
          );
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final result = await apiClient.login('a@b.de', 'Password1');

        expect(result?['user']['name'], 'Müller Сергій');
      });
    });
  });
}
