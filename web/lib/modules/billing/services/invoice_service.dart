import 'dart:convert';
import 'dart:typed_data';
import '../../core/services/api_client.dart';
import '../models/invoice.dart';
import '../models/billable_ride.dart';

class InvoiceService {
  final ApiClient _apiClient;
  final bool _ownsClient;

  InvoiceService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _ownsClient = apiClient == null;

  Future<List<Invoice>> getInvoices({
    InvoiceStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    var endpoint = '/billing/invoices?limit=$limit&offset=$offset';
    if (status != null) endpoint += '&status=${status.value}';
    final response = await _apiClient.get(endpoint);
    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException('Failed to fetch invoices: ${response.statusCode}');
  }

  Future<Invoice> getInvoice(String id) async {
    final response = await _apiClient.get('/billing/invoices/$id');
    if (response.statusCode == 200) {
      return Invoice.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException('Invoice not found: ${response.statusCode}');
  }

  Future<Invoice> createInvoice(CreateInvoiceRequest req) async {
    final response = await _apiClient.post('/billing/invoices', req.toJson());
    if (response.statusCode == 201) {
      return Invoice.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException('Failed to create invoice: ${response.statusCode}');
  }

  Future<Invoice> autoFill(String id) async {
    final response = await _apiClient.post(
      '/billing/invoices/$id/auto-fill',
      {},
    );
    if (response.statusCode == 200) {
      return Invoice.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException('Failed to auto-fill invoice: ${response.statusCode}');
  }

  /// Completed, unbilled rides of a client company — the per-ride selection source.
  Future<List<BillableRide>> getBillableRides(
    String clientCompanyId, {
    DateTime? from,
    DateTime? to,
  }) async {
    var endpoint = '/billing/billable-rides?clientCompanyId=$clientCompanyId';
    if (from != null) endpoint += '&from=${_fmtDate(from)}';
    if (to != null) endpoint += '&to=${_fmtDate(to)}';
    final response = await _apiClient.get(endpoint);
    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json
          .map((e) => BillableRide.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Failed to fetch billable rides: ${response.statusCode}',
    );
  }

  /// Fill a draft invoice from an explicit set of selected rides (per-ride billing).
  Future<Invoice> fillFromRides(String id, List<String> rideIds) async {
    final response = await _apiClient.post(
      '/billing/invoices/$id/fill-from-rides',
      {'rideIds': rideIds},
    );
    if (response.statusCode == 200) {
      return Invoice.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(
      'Failed to fill invoice from rides: ${response.statusCode}',
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Uint8List> downloadPdf(String id) async {
    final response = await _apiClient.get(
      '/billing/invoices/$id/pdf',
      acceptOverride: 'application/pdf',
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw ApiException('Failed to download PDF: ${response.statusCode}');
  }

  /// Single-ride German taxi receipt ("Quittung") PDF. The price is treated as gross.
  Future<Uint8List> downloadRideReceipt(
    String rideId, {
    double taxRate = 19,
  }) async {
    final response = await _apiClient.get(
      '/billing/rides/$rideId/receipt?taxRate=${taxRate.toStringAsFixed(0)}',
      acceptOverride: 'application/pdf',
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw ApiException('Failed to download receipt: ${response.statusCode}');
  }

  Future<Invoice> sendInvoice(String id) async {
    final response = await _apiClient.post('/billing/invoices/$id/send', {});
    if (response.statusCode == 200) {
      return Invoice.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException('Failed to send invoice: ${response.statusCode}');
  }

  Future<Invoice> markPaid(String id) async {
    final response = await _apiClient.post('/billing/invoices/$id/pay', {});
    if (response.statusCode == 200) {
      return Invoice.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(
      'Failed to mark invoice as paid: ${response.statusCode}',
    );
  }

  Future<void> deleteInvoice(String id) async {
    final response = await _apiClient.delete('/billing/invoices/$id');
    if (response.statusCode != 204) {
      throw ApiException('Failed to delete invoice: ${response.statusCode}');
    }
  }

  void dispose() {
    if (_ownsClient) _apiClient.dispose();
  }
}
