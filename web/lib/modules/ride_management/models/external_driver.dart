import '../../core/json_parse.dart';

class ExternalDriver {
  final String id;
  final String name;
  final String? phone;
  final String? partnerCompanyId;
  final String taxiCompanyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExternalDriver({
    required this.id,
    required this.name,
    this.phone,
    this.partnerCompanyId,
    required this.taxiCompanyId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExternalDriver.fromJson(Map<String, dynamic> json) {
    return ExternalDriver(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone']?.toString(),
      partnerCompanyId: json['partnerCompanyId']?.toString(),
      taxiCompanyId: json['taxiCompanyId']?.toString() ?? '',
      createdAt: JsonParse.requiredDateTime(json, 'createdAt'),
      updatedAt: JsonParse.requiredDateTime(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'partnerCompanyId': partnerCompanyId,
    'taxiCompanyId': taxiCompanyId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
