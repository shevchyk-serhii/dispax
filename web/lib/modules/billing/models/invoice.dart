import '../../core/json_parse.dart';

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String? rideId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double total;
  final DateTime createdAt;

  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    this.rideId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.createdAt,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
    id: JsonParse.requiredString(json, 'id'),
    invoiceId: JsonParse.requiredString(json, 'invoiceId'),
    rideId: JsonParse.optionalString(json, 'rideId'),
    description: JsonParse.requiredString(json, 'description'),
    quantity: JsonParse.requiredDouble(json, 'quantity'),
    unitPrice: JsonParse.requiredDouble(json, 'unitPrice'),
    total: JsonParse.requiredDouble(json, 'total'),
    createdAt: JsonParse.requiredDateTime(json, 'createdAt'),
  );
}

enum InvoiceStatus {
  draft('Draft'),
  sent('Sent'),
  paid('Paid'),
  cancelled('Cancelled');

  const InvoiceStatus(this.value);
  final String value;

  String get displayName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Entwurf';
      case InvoiceStatus.sent:
        return 'Gesendet';
      case InvoiceStatus.paid:
        return 'Bezahlt';
      case InvoiceStatus.cancelled:
        return 'Storniert';
    }
  }

  static InvoiceStatus fromString(String value) =>
      InvoiceStatus.values.firstWhere(
        (s) => s.value.toLowerCase() == value.toLowerCase(),
        orElse: () => InvoiceStatus.draft,
      );
}

class Invoice {
  final String id;
  final String number;
  final String clientCompanyId;
  final String taxiCompanyId;
  final InvoiceStatus status;
  final DateTime periodFrom;
  final DateTime periodTo;
  final double subtotalAmount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final String? notes;
  final DateTime? dueDate;
  final DateTime? sentAt;
  final DateTime? paidAt;
  final DateTime? reminderSentAt;
  final String? pdfPath;
  final List<InvoiceItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    required this.id,
    required this.number,
    required this.clientCompanyId,
    required this.taxiCompanyId,
    required this.status,
    required this.periodFrom,
    required this.periodTo,
    required this.subtotalAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.totalAmount,
    required this.currency,
    this.notes,
    this.dueDate,
    this.sentAt,
    this.paidAt,
    this.reminderSentAt,
    this.pdfPath,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: JsonParse.requiredString(json, 'id'),
    number: JsonParse.requiredString(json, 'number'),
    clientCompanyId: JsonParse.requiredString(json, 'clientCompanyId'),
    taxiCompanyId: JsonParse.requiredString(json, 'taxiCompanyId'),
    status: InvoiceStatus.fromString(JsonParse.requiredString(json, 'status')),
    periodFrom: JsonParse.requiredDateTime(json, 'periodFrom'),
    periodTo: JsonParse.requiredDateTime(json, 'periodTo'),
    subtotalAmount: JsonParse.requiredDouble(json, 'subtotalAmount'),
    taxRate: JsonParse.requiredDouble(json, 'taxRate'),
    taxAmount: JsonParse.requiredDouble(json, 'taxAmount'),
    totalAmount: JsonParse.requiredDouble(json, 'totalAmount'),
    currency: JsonParse.requiredString(json, 'currency'),
    notes: JsonParse.optionalString(json, 'notes'),
    dueDate: JsonParse.optionalDateTime(json, 'dueDate'),
    sentAt: JsonParse.optionalDateTime(json, 'sentAt'),
    paidAt: JsonParse.optionalDateTime(json, 'paidAt'),
    reminderSentAt: JsonParse.optionalDateTime(json, 'reminderSentAt'),
    pdfPath: JsonParse.optionalString(json, 'pdfPath'),
    items: (json['items'] as List<dynamic>? ?? [])
        .map((i) => InvoiceItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    createdAt: JsonParse.requiredDateTime(json, 'createdAt'),
    updatedAt: JsonParse.requiredDateTime(json, 'updatedAt'),
  );
}

class CreateInvoiceRequest {
  final String clientCompanyId;
  final DateTime periodFrom;
  final DateTime periodTo;
  final double taxRate;
  final String currency;
  final String? notes;
  final DateTime? dueDate;

  const CreateInvoiceRequest({
    required this.clientCompanyId,
    required this.periodFrom,
    required this.periodTo,
    this.taxRate = 0,
    this.currency = 'EUR',
    this.notes,
    this.dueDate,
  });

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'clientCompanyId': clientCompanyId,
    'periodFrom': _fmtDate(periodFrom),
    'periodTo': _fmtDate(periodTo),
    'taxRate': taxRate,
    'currency': currency,
    if (notes != null) 'notes': notes,
    if (dueDate != null) 'dueDate': _fmtDate(dueDate!),
  };
}
