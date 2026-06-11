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
        id: json['id'] as String,
        invoiceId: json['invoiceId'] as String,
        rideId: json['rideId'] as String?,
        description: json['description'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
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

  static InvoiceStatus fromString(String value) => InvoiceStatus.values.firstWhere(
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
        id: json['id'] as String,
        number: json['number'] as String,
        clientCompanyId: json['clientCompanyId'] as String,
        taxiCompanyId: json['taxiCompanyId'] as String,
        status: InvoiceStatus.fromString(json['status'] as String),
        periodFrom: DateTime.parse(json['periodFrom'] as String),
        periodTo: DateTime.parse(json['periodTo'] as String),
        subtotalAmount: (json['subtotalAmount'] as num).toDouble(),
        taxRate: (json['taxRate'] as num).toDouble(),
        taxAmount: (json['taxAmount'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        currency: json['currency'] as String,
        notes: json['notes'] as String?,
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
        sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt'] as String) : null,
        paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
        reminderSentAt:
            json['reminderSentAt'] != null ? DateTime.parse(json['reminderSentAt'] as String) : null,
        pdfPath: json['pdfPath'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => InvoiceItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
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
