import '../../core/json_parse.dart';

class PartnerCompany {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String taxiCompanyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PartnerCompany({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    required this.taxiCompanyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PartnerCompany.fromJson(Map<String, dynamic> json) {
    return PartnerCompany(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      taxiCompanyId: json['taxiCompanyId']?.toString() ?? '',
      createdAt: JsonParse.requiredDateTime(json, 'createdAt'),
      updatedAt: JsonParse.requiredDateTime(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'taxiCompanyId': taxiCompanyId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
