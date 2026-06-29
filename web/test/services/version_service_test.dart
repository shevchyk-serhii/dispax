import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/services/version_service.dart';
import '../helpers/mocks.dart';

void main() {
  late MockApiClient mockApiClient;
  late VersionService service;

  setUp(() {
    mockApiClient = MockApiClient();
    service = VersionService(apiClient: mockApiClient);
  });

  http.Response jsonResponse(dynamic body, {int statusCode = 200}) =>
      http.Response(jsonEncode(body), statusCode);

  group('VersionService.fetchBackendVersion', () {
    test('200 parses version/commit/branch/buildTime', () async {
      when(() => mockApiClient.get('/version')).thenAnswer(
        (_) async => jsonResponse({
          'version': '0.1.0',
          'commit': 'a1b2c3d',
          'branch': 'master',
          'buildTime': '2026-06-29T06:23:24Z',
        }),
      );

      final v = await service.fetchBackendVersion();

      expect(v.version, '0.1.0');
      expect(v.commit, 'a1b2c3d');
      expect(v.branch, 'master');
      expect(v.buildTime, '2026-06-29T06:23:24Z');
      expect(v.display, '0.1.0 +a1b2c3d');
    });

    test('non-200 throws ApiException', () async {
      when(() => mockApiClient.get('/version')).thenAnswer(
        (_) async => jsonResponse({'error': 'fail'}, statusCode: 500),
      );

      expect(() => service.fetchBackendVersion(), throwsA(isA<ApiException>()));
    });

    test('display falls back to version when commit is empty', () {
      const v = BackendVersion(
        version: '0.1.0',
        commit: '',
        branch: 'master',
        buildTime: '',
      );
      expect(v.display, '0.1.0');
    });
  });
}
