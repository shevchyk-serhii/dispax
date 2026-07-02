import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/services/ride_service.dart';

/// The "Share" action posts to /api/rides/{id}/share-link and turns the returned relative path into a shareable URL.
/// The guest tracking page itself is server-rendered HTML (Mapbox GL JS), not Flutter — so only the link-creation
/// path lives in the app and needs a test here.
void main() {
  group('RideService.createShareLink', () {
    test('posts to the share-link endpoint and returns a URL ending in the path', () async {
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

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/rides/ride-1/share-link');
      expect(url, endsWith('/track/tok42'));
    });

    test('uses the absolute url from the backend verbatim when present', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({
            'token': 'tok42',
            'path': '/track/tok42',
            'url': 'https://track.dispax.de/track/tok42',
          }),
          200,
        ),
      );
      final service = RideService(
        apiClient: ApiClient(client: client, baseUrl: 'http://x/api'),
      );

      final url = await service.createShareLink('ride-1');

      expect(url, 'https://track.dispax.de/track/tok42');
    });

    test('throws on a non-200 response', () async {
      final client = MockClient(
        (req) async => http.Response('{"error":"nope"}', 404),
      );
      final service = RideService(
        apiClient: ApiClient(client: client, baseUrl: 'http://x/api'),
      );

      expect(() => service.createShareLink('ride-1'), throwsA(isA<ApiException>()));
    });
  });
}
