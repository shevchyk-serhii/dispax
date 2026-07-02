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

  /// Primary role — used for dashboard routing and display. Unchanged by the
  /// multi-role feature; changing it would require a new login.
  final PersonRole role;
  final String? companyId;
  final String? licenseNumber;
  final String? phone;
  final VehicleInfo? vehicleInfo;
  final bool isVip;
  final String? preferredDriverId;
  final String status;
  final int reminderMinutes;

  /// Business client-company this client belongs to (e.g. "BMW AG"), as a
  /// ClientCompany id. Null when the client is not linked to any company.
  /// Distinct from [companyId], which is the taxi company (the tenant).
  final String? clientCompanyId;

  /// Full set of roles the person carries. Always includes [role].
  /// Defaults to {role} when the server does not send the `roles` field
  /// (e.g. for very old cached responses — back-compat fallback).
  final Set<PersonRole> roles;

  /// True when the person has a profile photo stored on the server.
  /// Raw bytes are fetched separately via ApiClient.getBytes('/users/$id/avatar').
  final bool hasAvatar;

  /// Human-readable company name, resolved server-side. Populated only by the
  /// profile endpoint (`GET /users/profile`); null elsewhere or when the
  /// company is unknown. Shown instead of the raw [companyId].
  final String? companyName;

  /// User-selected UI language (en, de, uk). Null means use the device/system
  /// locale. Stored on the backend and applied on login so the preference
  /// follows the user across devices.
  final String? preferredLanguage;

  /// True when the account was created with a temporary password and the user
  /// must change it before using the app. Set by the backend on creation and
  /// cleared once the password is changed. Drives the forced-change gate on login.
  final bool mustChangePassword;

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
    this.clientCompanyId,
    Set<PersonRole>? roles,
    this.hasAvatar = false,
    this.companyName,
    this.preferredLanguage,
    this.mustChangePassword = false,
  }) : roles = roles != null ? {...roles, role} : {role};

  /// Returns true when the person carries [r] as one of their roles.
  bool hasRole(PersonRole r) => roles.contains(r);

  /// True when the person can act as a driver (has the driver role).
  bool get canDrive => hasRole(PersonRole.driver);

  static String _extractId(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) return raw['value']?.toString() ?? '';
    return raw.toString();
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    final primaryRole =
        personRoleFromString(json['role']?.toString()) ?? PersonRole.client;
    // Parse the roles array; fall back to {primaryRole} if absent or empty.
    Set<PersonRole>? parsedRoles;
    final rawRoles = json['roles'];
    if (rawRoles is List && rawRoles.isNotEmpty) {
      parsedRoles = rawRoles
          .map((r) => personRoleFromString(r?.toString()))
          .whereType<PersonRole>()
          .toSet();
    }
    return Person(
      id: _extractId(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: primaryRole,
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
      clientCompanyId: json['clientCompanyId'] != null
          ? _extractId(json['clientCompanyId'])
          : null,
      roles: parsedRoles,
      hasAvatar: json['hasAvatar'] as bool? ?? false,
      companyName: json['companyName']?.toString(),
      preferredLanguage: json['preferredLanguage']?.toString(),
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.wire,
      'roles': roles.map((r) => r.wire).toList(),
      'companyId': companyId,
      'licenseNumber': licenseNumber,
      'phone': phone,
      'vehicleInfo': vehicleInfo?.toJson(),
      'isVip': isVip,
      'preferredDriverId': preferredDriverId,
      'status': status,
      'clientCompanyId': clientCompanyId,
      'hasAvatar': hasAvatar,
      'companyName': companyName,
      'preferredLanguage': preferredLanguage,
      'mustChangePassword': mustChangePassword,
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
