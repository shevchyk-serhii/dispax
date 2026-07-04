// Query parameters must be built via proper encoding, not string
// concatenation (audit 2026-07-02, defense-in-depth): a value containing a
// reserved character (space, `&`, `=`) used to break the query apart or
// inject extra parameters. The withQuery helper funnels every value through
// Uri's query encoding; these tests assert reserved characters survive the
// round-trip intact at the real service call sites.

import 'package:dispax/modules/billing/services/invoice_service.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/services/query_string.dart';
import 'package:dispax/modules/ride_management/services/ride_service.dart';
import 'package:dispax/modules/schedule_management/services/schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('withQuery', () {
    test('encodes reserved characters in values', () {
      final endpoint = withQuery('/x', {'q': 'a b&c=d'});
      // The raw string must not leak an unencoded & or = into the query.
      expect(endpoint, '/x?q=${Uri.encodeQueryComponent('a b&c=d')}');
      expect(Uri.parse(endpoint).queryParameters['q'], 'a b&c=d');
    });

    test('keeps multiple parameters separate', () {
      final uri = Uri.parse(
        withQuery('/x', {'from': '2026-07-03', 'to': '2026-07-04'}),
      );
      expect(uri.queryParameters, {'from': '2026-07-03', 'to': '2026-07-04'});
    });

    test('drops null values (optional parameters)', () {
      expect(withQuery('/x', {'a': '1', 'b': null}), '/x?a=1');
    });

    test('returns the bare path when no parameter is present', () {
      expect(withQuery('/x', {}), '/x');
      expect(withQuery('/x', {'a': null}), '/x');
    });
  });

  group('service call sites round-trip reserved characters', () {
    late Uri captured;

    ApiClient capturingClient(String body) => ApiClient(
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(body, 200);
      }),
      baseUrl: 'http://localhost:8080/api',
    );

    test('ScheduleService.getScheduleForDateRange', () async {
      final service = ScheduleService(apiClient: capturingClient('[]'));
      await service.getScheduleForDateRange('2026 06&27', 'x=y');

      expect(captured.queryParameters['from'], '2026 06&27');
      expect(captured.queryParameters['to'], 'x=y');
      // The reserved characters did not split off a bogus parameter.
      expect(captured.queryParameters.length, 2);
    });

    test('RideService.getRidesByDrivers', () async {
      final service = RideService(apiClient: capturingClient('[]'));
      await service.getRidesByDrivers([
        'driver 1',
        'driver&2',
      ], DateTime(2026, 7, 3));

      expect(captured.path, endsWith('/rides/by-drivers'));
      expect(captured.queryParameters['driverIds'], 'driver 1,driver&2');
      expect(captured.queryParameters['from'], '2026-07-03');
      expect(captured.queryParameters['to'], '2026-07-03');
    });

    test('InvoiceService.getBillableRides', () async {
      final service = InvoiceService(apiClient: capturingClient('[]'));
      await service.getBillableRides(
        'company & sons',
        from: DateTime(2026, 7, 1),
      );

      expect(captured.queryParameters['clientCompanyId'], 'company & sons');
      expect(captured.queryParameters['from'], '2026-07-01');
      // `to` was not passed and must not appear at all.
      expect(captured.queryParameters.containsKey('to'), isFalse);
    });

    test(
      'InvoiceService.getInvoices keeps limit/offset and optional status',
      () async {
        final service = InvoiceService(apiClient: capturingClient('[]'));
        await service.getInvoices(limit: 10, offset: 20);

        expect(captured.queryParameters, {'limit': '10', 'offset': '20'});
      },
    );
  });
}
