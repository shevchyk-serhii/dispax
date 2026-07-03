import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/schedule_management/services/schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

/// Regression tests for the create-shift error path. The service used to build
/// the ApiException by hand (no statusCode, no server reason), so every backend
/// failure classified as [AppErrorKind.unknown] and the UI could only show the
/// generic "something went wrong" snackbar. It must thread the response through
/// [ApiException.fromResponse] so a 409 classifies as a conflict and carries
/// the backend's reason.
void main() {
  late MockApiClient apiClient;
  late ScheduleService service;

  setUp(() {
    apiClient = MockApiClient();
    service = ScheduleService(apiClient: apiClient);
  });

  test('createScheduleDay maps a 409 to a conflict-kind ApiException', () async {
    when(() => apiClient.post('/schedules', any())).thenAnswer(
      (_) async => http.Response(
        '{"error":"Driver 1111 already has an overlapping shift on 2026-07-03"}',
        409,
      ),
    );

    await expectLater(
      service.createScheduleDay(
        driverId: 'driver-1',
        date: '2026-07-03',
        startTime: '08:00',
        endTime: '16:00',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.kind, 'kind', AppErrorKind.conflict)
            .having(
              (e) => e.message,
              'message',
              contains('already has an overlapping shift'),
            ),
      ),
    );
  });

  test('createBatch maps a 409 to a conflict-kind ApiException', () async {
    when(() => apiClient.post('/schedules/batch', any())).thenAnswer(
      (_) async => http.Response(
        '{"error":"Driver 1111 already has an overlapping shift on 2026-07-04"}',
        409,
      ),
    );

    await expectLater(
      service.createBatch(
        driverId: 'driver-1',
        days: [
          {'date': '2026-07-04', 'startTime': '08:00', 'endTime': '16:00'},
        ],
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.kind, 'kind', AppErrorKind.conflict),
      ),
    );
  });

  test(
    'createScheduleDay maps a 400 to a validation-kind ApiException',
    () async {
      when(() => apiClient.post('/schedules', any())).thenAnswer(
        (_) async => http.Response('{"error":"Person is not a driver"}', 400),
      );

      await expectLater(
        service.createScheduleDay(
          driverId: 'driver-1',
          date: '2026-07-03',
          startTime: '08:00',
          endTime: '16:00',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', AppErrorKind.validation)
              .having(
                (e) => e.message,
                'message',
                contains('Person is not a driver'),
              ),
        ),
      );
    },
  );
}
