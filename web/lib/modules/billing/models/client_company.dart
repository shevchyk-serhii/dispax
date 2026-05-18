class ClientCompany {
  final String id;
  final String name;
  final String taxiCompanyId;
  final String? email;
  final String? phone;
  final String? address;

  const ClientCompany({
    required this.id,
    required this.name,
    required this.taxiCompanyId,
    this.email,
    this.phone,
    this.address,
  });

  factory ClientCompany.fromJson(Map<String, dynamic> json) => ClientCompany(
        id: json['id'] as String,
        name: json['name'] as String,
        taxiCompanyId: json['taxiCompanyId'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'taxiCompanyId': taxiCompanyId,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
      };
}

class CreateClientCompanyRequest {
  final String name;
  final String? email;
  final String? phone;
  final String? address;

  const CreateClientCompanyRequest({
    required this.name,
    this.email,
    this.phone,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
      };
}
