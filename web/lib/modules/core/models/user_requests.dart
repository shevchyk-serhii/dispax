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

  const UpdateUserRequest({
    this.name,
    this.email,
    this.phone,
    this.isVip,
    this.preferredDriverId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (isVip != null) 'isVip': isVip,
      if (preferredDriverId != null) 'preferredDriverId': preferredDriverId,
    };
  }
}
