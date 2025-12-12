import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthInitializeRequested extends AuthEvent {
  const AuthInitializeRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthErrorCleared extends AuthEvent {
  const AuthErrorCleared();
}

class AuthBiometricLoginRequested extends AuthEvent {
  const AuthBiometricLoginRequested();
}

class AuthBiometricSetupRequested extends AuthEvent {
  final bool enabled;
  final String? userId;

  const AuthBiometricSetupRequested({
    required this.enabled,
    this.userId,
  });

  @override
  List<Object?> get props => [enabled, userId];
}
