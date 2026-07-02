class CreateUserRequest {
  final String name;
  final String email;
  // Required by the backend contract: POST /api/users rejects a body without
  // a password (temporary, forced change on first login), so a call site
  // that forgets it must not compile.
  final String password;
  final String? phone;
  final String role;
  final String? companyId;

  const CreateUserRequest({
    required this.name,
    required this.email,
    required this.password,
    this.phone,
    this.role = 'CLIENT',
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      if (phone != null) 'phone': phone,
      'role': role,
      if (companyId != null) 'companyId': companyId,
    };
  }
}

class UpdateUserRequest {
  final String? name;
  final String? email;
  final String? phone;
  final bool? isVip;
  final String? preferredDriverId;

  /// Business client-company link. Tri-state, matching the backend contract:
  /// null = leave unchanged, '' (empty string) = clear the link,
  /// a UUID string = assign the client to that company.
  final String? clientCompanyId;

  const UpdateUserRequest({
    this.name,
    this.email,
    this.phone,
    this.isVip,
    this.preferredDriverId,
    this.clientCompanyId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (isVip != null) 'isVip': isVip,
      if (preferredDriverId != null) 'preferredDriverId': preferredDriverId,
      if (clientCompanyId != null) 'clientCompanyId': clientCompanyId,
    };
  }
}
