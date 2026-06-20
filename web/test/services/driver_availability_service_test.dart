import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/driver_management/services/driver_availability_service.dart';

void main() {
  group('DriverAvailabilityService', () {
    ApiClient apiClientReturning(String body, int status) =>
        ApiClient(client: MockClient((_) async => http.Response(body, status)));

    group('isAvailable', () {
      test('returns true when status is Available', () async {
        final svc = DriverAvailabilityService(
          apiClientReturning('{"status":"Available"}', 200),
        );
        expect(await svc.isAvailable('d1'), isTrue);
      });

      test('returns false when status is Offline', () async {
        final svc = DriverAvailabilityService(
          apiClientReturning('{"status":"Offline"}', 200),
        );
        expect(await svc.isAvailable('d1'), isFalse);
      });

      test('returns false on non-200 response', () async {
        final svc = DriverAvailabilityService(apiClientReturning('{}', 500));
        expect(await svc.isAvailable('d1'), isFalse);
      });

      test('returns false (does not throw) on transport error', () async {
        final svc = DriverAvailabilityService(
          ApiClient(
            client: MockClient((_) async => throw Exception('network down')),
          ),
        );
        expect(await svc.isAvailable('d1'), isFalse);
      });
    });

    group('setAvailable', () {
      test('returns true on 200', () async {
        final svc = DriverAvailabilityService(apiClientReturning('{}', 200));
        expect(await svc.setAvailable('d1', true), isTrue);
      });

      test('returns false on non-200', () async {
        final svc = DriverAvailabilityService(apiClientReturning('{}', 409));
        expect(await svc.setAvailable('d1', false), isFalse);
      });

      test('sends the expected status payload', () async {
        late String capturedBody;
        final svc = DriverAvailabilityService(
          ApiClient(
            client: MockClient((req) async {
              capturedBody = req.body;
              return http.Response('{}', 200);
            }),
          ),
        );
        await svc.setAvailable('d1', true);
        expect(capturedBody, contains('Available'));
      });
    });
  });
}
