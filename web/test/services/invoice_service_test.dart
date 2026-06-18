import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dispax/modules/billing/services/invoice_service.dart';
import 'package:dispax/modules/core/services/api_client.dart';

void main() {
  group('InvoiceService', () {
    group('downloadPdf', () {
      test('sends Accept: application/pdf', () async {
        late Map<String, String> capturedHeaders;
        final client = MockClient((request) async {
          capturedHeaders = request.headers;
          // Minimal valid PDF magic bytes
          return http.Response.bytes(
            [0x25, 0x50, 0x44, 0x46],
            200,
            headers: {'content-type': 'application/pdf'},
          );
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final service = InvoiceService(apiClient: apiClient);
        await service.downloadPdf('invoice-123');

        expect(capturedHeaders['Accept'], 'application/pdf');
      });

      test('returns bodyBytes on 200', () async {
        final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D];
        final client = MockClient(
          (_) async => http.Response.bytes(
            pdfBytes,
            200,
            headers: {'content-type': 'application/pdf'},
          ),
        );

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final service = InvoiceService(apiClient: apiClient);
        final bytes = await service.downloadPdf('invoice-123');

        expect(bytes, pdfBytes);
      });

      test('throws ApiException on non-200 (e.g. 406)', () async {
        final client = MockClient(
          (_) async => http.Response('Not Acceptable', 406),
        );

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final service = InvoiceService(apiClient: apiClient);

        await expectLater(
          () => service.downloadPdf('invoice-123'),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('downloadRideReceipt', () {
      test('sends Accept: application/pdf', () async {
        late Map<String, String> capturedHeaders;
        final client = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response.bytes(
            [0x25, 0x50, 0x44, 0x46],
            200,
            headers: {'content-type': 'application/pdf'},
          );
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final service = InvoiceService(apiClient: apiClient);
        await service.downloadRideReceipt('ride-456');

        expect(capturedHeaders['Accept'], 'application/pdf');
      });

      test('returns bodyBytes on 200', () async {
        final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D];
        final client = MockClient(
          (_) async => http.Response.bytes(
            pdfBytes,
            200,
            headers: {'content-type': 'application/pdf'},
          ),
        );

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final service = InvoiceService(apiClient: apiClient);
        final bytes = await service.downloadRideReceipt('ride-456');

        expect(bytes, pdfBytes);
      });

      test('includes taxRate query param', () async {
        late Uri capturedUri;
        final client = MockClient((request) async {
          capturedUri = request.url;
          return http.Response.bytes(
            [0x25, 0x50, 0x44, 0x46],
            200,
            headers: {'content-type': 'application/pdf'},
          );
        });

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final service = InvoiceService(apiClient: apiClient);
        await service.downloadRideReceipt('ride-456', taxRate: 19);

        expect(capturedUri.queryParameters['taxRate'], '19');
      });

      test('throws ApiException on non-200', () async {
        final client = MockClient(
          (_) async => http.Response('Server Error', 500),
        );

        final apiClient = ApiClient(
          client: client,
          baseUrl: 'http://localhost:8080/api',
        );
        final service = InvoiceService(apiClient: apiClient);

        await expectLater(
          () => service.downloadRideReceipt('ride-456'),
          throwsA(isA<ApiException>()),
        );
      });
    });
  });
}
