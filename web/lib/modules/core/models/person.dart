enum PersonRole { driver, client, secretary, dispatcher, admin }

class Person {
  final String id;
  final String name;
  final String email;
  final PersonRole role;
  final String? companyId;
  final String? licenseNumber;
  final String? phone;
  final VehicleInfo? vehicleInfo;
  final bool isVip;
  final String? preferredDriverId;
  final String status;

  Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyId,
    this.licenseNumber,
    this.phone,
    this.vehicleInfo,
    this.isVip = false,
    this.preferredDriverId,
    this.status = 'ACTIVE',
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: PersonRole.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == json['role'].toString().toLowerCase(),
        orElse: () => PersonRole.client,
      ),
      companyId: json['companyId']?.toString(),
      licenseNumber: json['licenseNumber']?.toString(),
      phone: json['phone']?.toString(),
      vehicleInfo: json['vehicleInfo'] != null
          ? VehicleInfo.fromJson(json['vehicleInfo'])
          : null,
      isVip: json['isVip'] ?? false,
      preferredDriverId: json['preferredDriverId']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
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
      'isVip': isVip,
      'preferredDriverId': preferredDriverId,
      'status': status,
    };
  }

  bool get isDriver => role == PersonRole.driver;
  bool get isClient => role == PersonRole.client;
  bool get isSecretary => role == PersonRole.secretary;
  bool get isDispatcher => role == PersonRole.dispatcher;
  bool get isAdmin => role == PersonRole.admin;
  bool get isActive => status == 'ACTIVE';
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
