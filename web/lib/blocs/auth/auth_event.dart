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

/// Change the password of the currently logged-in (temporary-password) user.
/// Used by the forced password-change screen; on success the user becomes fully
/// authenticated. `currentPassword` is the temporary password the dispatcher set.
class AuthPasswordChangeRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const AuthPasswordChangeRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object> get props => [currentPassword, newPassword];
}

/// Forced logout triggered by a 401 from the API (expired/invalid token).
/// Clears the session like a normal logout, but leaves the login screen with a
/// "session expired" message instead of dropping to it silently.
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
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

  const AuthBiometricSetupRequested({required this.enabled, this.userId});

  @override
  List<Object?> get props => [enabled, userId];
}

/// Trigger a silent refresh of the authenticated user's profile from the server.
/// Used after avatar upload/delete to propagate hasAvatar state to all widgets.
class AuthProfileRefreshRequested extends AuthEvent {
  const AuthProfileRefreshRequested();
}
