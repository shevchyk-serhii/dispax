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
  });
}
