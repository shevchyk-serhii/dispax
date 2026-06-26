import 'package:equatable/equatable.dart';
import '../../modules/core/models/person.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,

  /// Logged in with a temporary password: the user is identified but gated
  /// behind the forced password-change screen until they set a new password.
  mustChangePassword,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final Person? user;
  final String? errorMessage;
  final bool biometricEnabled;
  final bool biometricAvailable;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
  });

  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.initial);
  }

  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading);
  }

  factory AuthState.authenticated(
    Person user, {
    bool biometricEnabled = false,
    bool biometricAvailable = false,
  }) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      biometricEnabled: biometricEnabled,
      biometricAvailable: biometricAvailable,
    );
  }

  /// Authenticated but holding a temporary password — render the forced-change screen.
  factory AuthState.mustChangePassword(
    Person user, {
    bool biometricEnabled = false,
    bool biometricAvailable = false,
  }) {
    return AuthState(
      status: AuthStatus.mustChangePassword,
      user: user,
      biometricEnabled: biometricEnabled,
      biometricAvailable: biometricAvailable,
    );
  }

  factory AuthState.unauthenticated({
    bool biometricEnabled = false,
    bool biometricAvailable = false,
  }) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      biometricEnabled: biometricEnabled,
      biometricAvailable: biometricAvailable,
    );
  }

  factory AuthState.error(
    String message, {
    bool biometricEnabled = false,
    bool biometricAvailable = false,
  }) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
      biometricEnabled: biometricEnabled,
      biometricAvailable: biometricAvailable,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    Person? user,
    String? errorMessage,
    bool? biometricEnabled,
    bool? biometricAvailable,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    );
  }

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get mustChangePassword => status == AuthStatus.mustChangePassword;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => status == AuthStatus.error;

  @override
  List<Object?> get props => [
    status,
    user,
    errorMessage,
    biometricEnabled,
    biometricAvailable,
  ];
}
