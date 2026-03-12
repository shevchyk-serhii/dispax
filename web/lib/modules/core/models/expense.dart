enum ExpenseCategory {
  fuel('Fuel'),
  parking('Parking'),
  tolls('Tolls'),
  cleaning('Cleaning'),
  maintenance('Maintenance'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }
}

class Expense {
  final String id;
  final String? rideId;
  final String driverId;
  final String companyId;
  final ExpenseCategory category;
  final double amount;
  final String currency;
  final String? description;
  final String? receiptUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    this.rideId,
    required this.driverId,
    required this.companyId,
    required this.category,
    required this.amount,
    this.currency = 'EUR',
    this.description,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?['value'] ?? json['id'] ?? '',
      rideId: json['rideId']?['value'] ?? json['rideId'],
      driverId: json['driverId']?['value'] ?? json['driverId'] ?? '',
      companyId: json['companyId']?['value'] ?? json['companyId'] ?? '',
      category: ExpenseCategory.fromString(json['category'] ?? 'Other'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EUR',
      description: json['description'],
      receiptUrl: json['receiptUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class CreateExpenseRequest {
  final String? rideId;
  final String category;
  final double amount;
  final String? description;

  const CreateExpenseRequest({
    this.rideId,
    required this.category,
    required this.amount,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      if (rideId != null) 'rideId': rideId,
      'category': category,
      'amount': amount,
      if (description != null) 'description': description,
    };
  }
}
