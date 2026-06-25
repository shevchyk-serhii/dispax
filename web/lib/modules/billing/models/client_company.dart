import '../../core/json_parse.dart';

class ClientCompany {
  final String id;
  final String name;
  final String taxiCompanyId;
  final String? email;
  final String? phone;
  final String? address;
  final String? preferredLanguage;
  final String? vatId;

  const ClientCompany({
    required this.id,
    required this.name,
    required this.taxiCompanyId,
    this.email,
    this.phone,
    this.address,
    this.preferredLanguage,
    this.vatId,
  });

  factory ClientCompany.fromJson(Map<String, dynamic> json) => ClientCompany(
    id: JsonParse.requiredString(json, 'id'),
    name: JsonParse.requiredString(json, 'name'),
    taxiCompanyId: JsonParse.requiredString(json, 'taxiCompanyId'),
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    preferredLanguage: json['preferredLanguage'] as String?,
    vatId: json['vatId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'taxiCompanyId': taxiCompanyId,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (address != null) 'address': address,
    if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
    if (vatId != null) 'vatId': vatId,
  };
}

class CreateClientCompanyRequest {
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? preferredLanguage;
  final String? vatId;

  const CreateClientCompanyRequest({
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.preferredLanguage,
    this.vatId,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (address != null) 'address': address,
    if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
    if (vatId != null) 'vatId': vatId,
  };
}
