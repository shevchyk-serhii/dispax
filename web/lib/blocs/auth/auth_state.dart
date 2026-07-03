import 'package:equatable/equatable.dart';
import '../../modules/core/services/api_client.dart' show ApiException;
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

  /// Typed cause for NETWORK-class auth failures (login/logout/init/biometric
  /// transport errors). Null for intentional DOMAIN messages (invalid
  /// credentials, session expired, "no user to change password for", a biometric
  /// plugin reason) — those are already human-readable and must NOT be collapsed
  /// to a generic message. The display sites use `state.error` to decide: typed
  /// cause → `friendlyError`; otherwise show [errorMessage] verbatim.
  final Object? error;
  final bool biometricEnabled;
  final bool biometricAvailable;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.error,
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

  /// [cause] should be set ONLY for network-class failures (so the UI maps it
  /// via `friendlyError`); leave it null for intentional domain messages.
  factory AuthState.error(
    String message, {
    Object? cause,
    bool biometricEnabled = false,
    bool biometricAvailable = false,
  }) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
      error: cause,
      biometricEnabled: biometricEnabled,
      biometricAvailable: biometricAvailable,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    Person? user,
    // [errorMessage]/[error] use a sentinel so callers can distinguish "leave
    // as is" (omit the argument) from "explicitly clear it" (pass null). A
    // plain nullable parameter cannot tell those apart, so an omitted argument
    // used to silently null the field — producing a `status == error` state
    // with no message, which rendered an empty login error banner. Same
    // pattern as RideState.copyWith.
    Object? errorMessage = _unset,
    Object? error = _unset,
    bool? biometricEnabled,
    bool? biometricAvailable,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      error: identical(error, _unset) ? this.error : error,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    );
  }

  static const Object _unset = Object();

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
    error is ApiException ? (error as ApiException).kind : error?.runtimeType,
    biometricEnabled,
    biometricAvailable,
  ];
}
