class CreateUserRequest {
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? companyId;

  const CreateUserRequest({
    required this.name,
    required this.email,
    this.phone,
    this.role = 'CLIENT',
    this.companyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
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

  const UpdateUserRequest({
    this.name,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    };
  }
}
