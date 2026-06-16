import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/billing/models/invoice.dart';

void main() {
  // ─── InvoiceStatus ────────────────────────────────────────────────────────

  group('InvoiceStatus.fromString', () {
    test('parses all known statuses (capitalized — server format)', () {
      expect(InvoiceStatus.fromString('Draft'), InvoiceStatus.draft);
      expect(InvoiceStatus.fromString('Sent'), InvoiceStatus.sent);
      expect(InvoiceStatus.fromString('Paid'), InvoiceStatus.paid);
      expect(InvoiceStatus.fromString('Cancelled'), InvoiceStatus.cancelled);
    });

    test('is case insensitive', () {
      expect(InvoiceStatus.fromString('draft'), InvoiceStatus.draft);
      expect(InvoiceStatus.fromString('SENT'), InvoiceStatus.sent);
      expect(InvoiceStatus.fromString('pAiD'), InvoiceStatus.paid);
    });

    test('returns draft as fallback for unknown value', () {
      expect(InvoiceStatus.fromString('unknown'), InvoiceStatus.draft);
      expect(InvoiceStatus.fromString(''), InvoiceStatus.draft);
    });

    test('displayName returns German labels', () {
      expect(InvoiceStatus.draft.displayName, 'Entwurf');
      expect(InvoiceStatus.sent.displayName, 'Gesendet');
      expect(InvoiceStatus.paid.displayName, 'Bezahlt');
      expect(InvoiceStatus.cancelled.displayName, 'Storniert');
    });
  });

  // ─── InvoiceItem ──────────────────────────────────────────────────────────

  group('InvoiceItem.fromJson', () {
    Map<String, dynamic> _itemJson({String? rideId}) => {
      'id': 'item-1',
      'invoiceId': 'inv-1',
      if (rideId != null) 'rideId': rideId,
      'description': 'Airport MUC → Marienplatz',
      'quantity': 1,
      'unitPrice': 85.0,
      'total': 85.0,
      'createdAt': '2026-05-15T10:00:00.000Z',
    };

    test('parses all fields correctly', () {
      final item = InvoiceItem.fromJson(_itemJson(rideId: 'ride-99'));
      expect(item.id, 'item-1');
      expect(item.invoiceId, 'inv-1');
      expect(item.rideId, 'ride-99');
      expect(item.description, 'Airport MUC → Marienplatz');
      expect(item.quantity, 1.0);
      expect(item.unitPrice, 85.0);
      expect(item.total, 85.0);
      expect(item.createdAt, DateTime.parse('2026-05-15T10:00:00.000Z'));
    });

    test('rideId is null when absent', () {
      final item = InvoiceItem.fromJson(_itemJson());
      expect(item.rideId, isNull);
    });

    test('numeric fields parsed from int JSON values', () {
      final json = _itemJson()
        ..['quantity'] = 2
        ..['unitPrice'] = 50
        ..['total'] = 100;
      final item = InvoiceItem.fromJson(json);
      expect(item.quantity, 2.0);
      expect(item.unitPrice, 50.0);
      expect(item.total, 100.0);
    });
  });

  // ─── Invoice ──────────────────────────────────────────────────────────────

  group('Invoice.fromJson', () {
    Map<String, dynamic> _invoiceJson({
      String status = 'Draft',
      List<dynamic> items = const [],
      String? notes,
      String? dueDate,
      String? sentAt,
      String? paidAt,
      String? reminderSentAt,
      String? pdfPath,
    }) => {
      'id': 'inv-1',
      'number': 'INV-2026-0001',
      'clientCompanyId': 'cc-1',
      'taxiCompanyId': 'tc-1',
      'status': status,
      'periodFrom': '2026-01-01',
      'periodTo': '2026-01-31',
      'subtotalAmount': 100.0,
      'taxRate': 19.0,
      'taxAmount': 19.0,
      'totalAmount': 119.0,
      'currency': 'EUR',
      'items': items,
      'createdAt': '2026-01-01T12:00:00.000Z',
      'updatedAt': '2026-01-02T08:00:00.000Z',
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'dueDate': dueDate,
      if (sentAt != null) 'sentAt': sentAt,
      if (paidAt != null) 'paidAt': paidAt,
      if (reminderSentAt != null) 'reminderSentAt': reminderSentAt,
      if (pdfPath != null) 'pdfPath': pdfPath,
    };

    test('parses required fields correctly', () {
      final inv = Invoice.fromJson(_invoiceJson());
      expect(inv.id, 'inv-1');
      expect(inv.number, 'INV-2026-0001');
      expect(inv.clientCompanyId, 'cc-1');
      expect(inv.taxiCompanyId, 'tc-1');
      expect(inv.status, InvoiceStatus.draft);
      expect(inv.periodFrom, DateTime(2026, 1, 1));
      expect(inv.periodTo, DateTime(2026, 1, 31));
      expect(inv.subtotalAmount, 100.0);
      expect(inv.taxRate, 19.0);
      expect(inv.taxAmount, 19.0);
      expect(inv.totalAmount, 119.0);
      expect(inv.currency, 'EUR');
    });

    test('optional fields are null when absent', () {
      final inv = Invoice.fromJson(_invoiceJson());
      expect(inv.notes, isNull);
      expect(inv.dueDate, isNull);
      expect(inv.sentAt, isNull);
      expect(inv.paidAt, isNull);
      expect(inv.reminderSentAt, isNull);
      expect(inv.pdfPath, isNull);
      expect(inv.items, isEmpty);
    });

    test('parses optional fields when present', () {
      final inv = Invoice.fromJson(
        _invoiceJson(
          notes: 'Bitte bis 28.02 zahlen',
          dueDate: '2026-02-28',
          sentAt: '2026-01-10T09:00:00.000Z',
          paidAt: '2026-02-01T14:30:00.000Z',
          reminderSentAt: '2026-03-05T08:00:00.000Z',
          pdfPath: '/tmp/invoices/INV-2026-0001.pdf',
        ),
      );
      expect(inv.notes, 'Bitte bis 28.02 zahlen');
      expect(inv.dueDate, DateTime(2026, 2, 28));
      expect(inv.sentAt, DateTime.parse('2026-01-10T09:00:00.000Z'));
      expect(inv.paidAt, DateTime.parse('2026-02-01T14:30:00.000Z'));
      expect(inv.reminderSentAt, DateTime.parse('2026-03-05T08:00:00.000Z'));
      expect(inv.pdfPath, '/tmp/invoices/INV-2026-0001.pdf');
    });

    test('parses nested items list', () {
      final itemJson = {
        'id': 'item-1',
        'invoiceId': 'inv-1',
        'description': 'Ride A',
        'quantity': 1.0,
        'unitPrice': 50.0,
        'total': 50.0,
        'createdAt': '2026-01-15T10:00:00.000Z',
      };
      final inv = Invoice.fromJson(_invoiceJson(items: [itemJson]));
      expect(inv.items.length, 1);
      expect(inv.items.first.description, 'Ride A');
      expect(inv.items.first.total, 50.0);
    });

    test('parses all invoice statuses from server format', () {
      for (final entry in {
        'Draft': InvoiceStatus.draft,
        'Sent': InvoiceStatus.sent,
        'Paid': InvoiceStatus.paid,
        'Cancelled': InvoiceStatus.cancelled,
      }.entries) {
        final inv = Invoice.fromJson(_invoiceJson(status: entry.key));
        expect(
          inv.status,
          entry.value,
          reason: 'status "${entry.key}" should map to ${entry.value}',
        );
      }
    });
  });

  // ─── CreateInvoiceRequest ─────────────────────────────────────────────────

  group('CreateInvoiceRequest.toJson', () {
    test('serializes dates as yyyy-MM-dd strings', () {
      final req = CreateInvoiceRequest(
        clientCompanyId: 'cc-1',
        periodFrom: DateTime(2026, 1, 1),
        periodTo: DateTime(2026, 1, 31),
      );
      final json = req.toJson();
      expect(json['periodFrom'], '2026-01-01');
      expect(json['periodTo'], '2026-01-31');
    });

    test('pads single-digit months and days with zeros', () {
      final req = CreateInvoiceRequest(
        clientCompanyId: 'cc-1',
        periodFrom: DateTime(2026, 3, 5),
        periodTo: DateTime(2026, 3, 9),
      );
      final json = req.toJson();
      expect(json['periodFrom'], '2026-03-05');
      expect(json['periodTo'], '2026-03-09');
    });

    test('includes all required fields', () {
      final req = CreateInvoiceRequest(
        clientCompanyId: 'cc-1',
        periodFrom: DateTime(2026, 1, 1),
        periodTo: DateTime(2026, 1, 31),
        taxRate: 19.0,
        currency: 'EUR',
      );
      final json = req.toJson();
      expect(json['clientCompanyId'], 'cc-1');
      expect(json['taxRate'], 19.0);
      expect(json['currency'], 'EUR');
    });

    test('omits null optional fields', () {
      final req = CreateInvoiceRequest(
        clientCompanyId: 'cc-1',
        periodFrom: DateTime(2026, 1, 1),
        periodTo: DateTime(2026, 1, 31),
      );
      final json = req.toJson();
      expect(json.containsKey('notes'), isFalse);
      expect(json.containsKey('dueDate'), isFalse);
    });

    test('includes optional fields when set', () {
      final req = CreateInvoiceRequest(
        clientCompanyId: 'cc-1',
        periodFrom: DateTime(2026, 1, 1),
        periodTo: DateTime(2026, 1, 31),
        notes: 'Monatliche Abrechnung',
        dueDate: DateTime(2026, 2, 28),
      );
      final json = req.toJson();
      expect(json['notes'], 'Monatliche Abrechnung');
      expect(json['dueDate'], '2026-02-28');
    });

    test('defaults: taxRate=0, currency=EUR', () {
      final req = CreateInvoiceRequest(
        clientCompanyId: 'cc-1',
        periodFrom: DateTime(2026, 1, 1),
        periodTo: DateTime(2026, 1, 31),
      );
      final json = req.toJson();
      expect(json['taxRate'], 0);
      expect(json['currency'], 'EUR');
    });
  });
}
