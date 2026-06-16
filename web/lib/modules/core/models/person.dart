enum PersonRole {
  driver,
  client,
  secretary,
  dispatcher,
  admin,
  clientSecretary,
  superAdmin,
}

extension PersonRoleWire on PersonRole {
  /// Canonical wire representation (SCREAMING_SNAKE_CASE) matching the backend
  /// `PersonRole.toWire` (see core/.../CoreDomain.scala). Used when sending the
  /// role back to the server.
  String get wire {
    switch (this) {
      case PersonRole.clientSecretary:
        return 'CLIENT_SECRETARY';
      case PersonRole.superAdmin:
        return 'SUPER_ADMIN';
      default:
        return name.toUpperCase();
    }
  }
}

/// Parses a role string from the API. Tolerant to case and to the presence or
/// absence of underscores, so both `SUPER_ADMIN` and `SUPERADMIN` resolve to
/// [PersonRole.superAdmin]. Returns `null` on an unknown value so callers can
/// decide how to handle it instead of silently collapsing to `client`.
PersonRole? personRoleFromString(String? raw) {
  if (raw == null) return null;
  final normalized = raw.toLowerCase().replaceAll('_', '');
  for (final role in PersonRole.values) {
    if (role.name.toLowerCase() == normalized) return role;
  }
  return null;
}

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
  final int reminderMinutes;

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
    this.reminderMinutes = 60,
  });

  static String _extractId(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) return raw['value']?.toString() ?? '';
    return raw.toString();
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: _extractId(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: personRoleFromString(json['role']?.toString()) ?? PersonRole.client,
      companyId: json['companyId'] != null
          ? _extractId(json['companyId'])
          : null,
      licenseNumber: json['licenseNumber']?.toString(),
      phone: json['phone']?.toString(),
      vehicleInfo: json['vehicleInfo'] != null
          ? VehicleInfo.fromJson(json['vehicleInfo'])
          : null,
      isVip: json['isVip'] ?? false,
      preferredDriverId: json['preferredDriverId']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      reminderMinutes: (json['reminderMinutes'] as int?) ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.wire,
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
  bool get isSuperAdmin => role == PersonRole.superAdmin;
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
