enum PersonRole { driver, client, secretary, dispatcher }

class Person {
  final int id;
  final String name;
  final String email;
  final PersonRole role;
  final int? companyId;
  final String? licenseNumber;
  final String? phone;
  final VehicleInfo? vehicleInfo;

  Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyId,
    this.licenseNumber,
    this.phone,
    this.vehicleInfo,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: PersonRole.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == json['role'].toString().toLowerCase(),
        orElse: () => PersonRole.client, // Default fallback
      ),
      companyId: json['companyId'],
      licenseNumber: json['licenseNumber'],
      phone: json['phone'],
      vehicleInfo: json['vehicleInfo'] != null 
          ? VehicleInfo.fromJson(json['vehicleInfo']) 
          : null,
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
      'vehicleInfo': vehicleInfo?.toJson(),
    };
  }

  bool get isDriver => role == PersonRole.driver;
  bool get isClient => role == PersonRole.client;
  bool get isSecretary => role == PersonRole.secretary;
  bool get isDispatcher => role == PersonRole.dispatcher;
}

class VehicleInfo {
  final String make;
  final String model;
  final String? color;
  final String? licensePlate;
  final int? year;

  const VehicleInfo({
    required this.make,
    required this.model,
    this.color,
    this.licensePlate,
    this.year,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      color: json['color'],
      licensePlate: json['licensePlate'],
      year: json['year'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'color': color,
      'licensePlate': licensePlate,
      'year': year,
    };
  }
}
