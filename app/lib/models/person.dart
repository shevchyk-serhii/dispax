enum PersonRole { driver, client, secretary, dispatcher }

class Person {
  final int id;
  final String name;
  final String email;
  final PersonRole role;
  final int? companyId;
  final String? licenseNumber;
  final String? phone;

  Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyId,
    this.licenseNumber,
    this.phone,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: PersonRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
      ),
      companyId: json['companyId'],
      licenseNumber: json['licenseNumber'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'companyId': companyId,
      'licenseNumber': licenseNumber,
      'phone': phone,
    };
  }

  bool get isDriver => role == PersonRole.driver;
  bool get isClient => role == PersonRole.client;
  bool get isSecretary => role == PersonRole.secretary;
  bool get isDispatcher => role == PersonRole.dispatcher;
}
