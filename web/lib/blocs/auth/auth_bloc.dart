import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../modules/core/models/person.dart';
import '../../modules/core/services/api_client.dart';
import '../../locale_notifier.dart';
import '../../modules/core/services/location_clarification_service.dart';
import '../../modules/core/services/websocket_service.dart';
import '../../modules/core/services/push_notification_service.dart';
import '../../modules/auth/services/biometric_service.dart';
import '../../modules/flight_management/services/airport_timing_service.dart';
import '../../modules/flight_management/services/arrivals_board_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

abstract class TokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Storage abstraction that falls back to SharedPreferences on macOS/Web
/// where Keychain requires signing entitlements not available in debug.
class _TokenStorage implements TokenStorage {
  final FlutterSecureStorage? _secure;
  final bool _useFallback;

  _TokenStorage()
    : _useFallback = kIsWeb || Platform.isMacOS,
      _secure = (kIsWeb || Platform.isMacOS)
          ? null
          : const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<String?> read(String key) async {
    try {
      final secure = _secure;
      if (_useFallback || secure == null) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      }
      return await secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final secure = _secure;
      if (_useFallback || secure == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
        return;
      }
      await secure.write(key: key, value: value);
    } catch (_) {
      // Storage write failed — token won't persist across restarts
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final secure = _secure;
      if (_useFallback || secure == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
        return;
      }
      await secure.delete(key: key);
    } catch (_) {
      // Ignore delete failures
    }
  }
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  late ApiClient privateApiClient;
  late BiometricService privateBiometricService;
  final TokenStorage _storage;
  final WebSocketServiceBase _webSocketService;

  static const String privateUserKey = 'current_user';
  static const String privateTokenKey = 'auth_token';

  AuthBloc({
    ApiClient? apiClient,
    BiometricService? biometricService,
    TokenStorage? storage,
    WebSocketServiceBase? webSocketService,
  }) : _storage = storage ?? _TokenStorage(),
       _webSocketService = webSocketService ?? WebSocketService.instance,
       super(AuthState.initial()) {
    privateApiClient = apiClient ?? ApiClient();
    privateApiClient.onUnauthorized = () => add(const AuthSessionExpired());
    privateBiometricService = biometricService ?? BiometricService();

    on<AuthInitializeRequested>(_onInitializeRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthPasswordChangeRequested>(_onPasswordChangeRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthErrorCleared>(_onErrorCleared);
    on<AuthBiometricLoginRequested>(_onBiometricLoginRequested);
    on<AuthBiometricSetupRequested>(_onBiometricSetupRequested);
    on<AuthProfileRefreshRequested>(_onProfileRefreshRequested);
  }

  ApiClient get apiClient => privateApiClient;

  Future<void> _onInitializeRequested(
    AuthInitializeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      String? userData;
      String? token;
      try {
        userData = await _storage.read(privateUserKey);
        token = await _storage.read(privateTokenKey);
      } catch (e) {
        // Corrupted storage data — clear and start fresh
        try {
          await _storage.delete(privateUserKey);
        } catch (_) {}
        try {
          await _storage.delete(privateTokenKey);
        } catch (_) {}
      }

      bool biometricAvailable = false;
      bool biometricEnabled = false;
      try {
        biometricAvailable = await privateBiometricService.isAvailable;
        biometricEnabled = await privateBiometricService.isBiometricEnabled;
      } catch (_) {
        // Biometric not available on this platform
      }

      if (userData != null && token != null) {
        final userJson = jsonDecode(userData);
        final user = Person.fromJson(userJson);
        privateApiClient.setAuthToken(token);

        // Apply the user's preferred language — backend is the source of truth.
        final preferredLanguage = user.preferredLanguage;
        if (preferredLanguage != null) {
          final locale = localeFromString(preferredLanguage);
          if (locale != null) {
            localeNotifier.value = locale;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('language', preferredLanguage);
          }
        }

        /// Configure services with authenticated API client
        AirportTimingService.configure(privateApiClient);
        ArrivalsBoardService.configure(privateApiClient);
        LocationClarificationService.configure(privateApiClient);
        PushNotificationService.instance.registerTokenWithClient(
          privateApiClient,
        );

        /// Connect WebSocket for real-time updates
        _webSocketService.connect(token, wsBaseUrl: ApiClient.wsBaseUrl);

        // Restore into the forced-change gate too, so a session restored while a
        // temporary password is still pending cannot bypass the change screen.
        emit(
          user.mustChangePassword
              ? AuthState.mustChangePassword(
                  user,
                  biometricEnabled: biometricEnabled,
                  biometricAvailable: biometricAvailable,
                )
              : AuthState.authenticated(
                  user,
                  biometricEnabled: biometricEnabled,
                  biometricAvailable: biometricAvailable,
                ),
        );

        // The stored user is a snapshot from the last login and can be stale
        // (e.g. a profile photo uploaded later, or any field added to the DTO
        // after that login — hasAvatar). Re-fetch /users/profile in the
        // background so the restored session reflects the current backend state
        // without requiring an explicit logout→login. Non-fatal: if the refresh
        // fails (offline), the restored stored user stays in place.
        if (!user.mustChangePassword) {
          add(const AuthProfileRefreshRequested());
        }
      } else {
        emit(
          AuthState.unauthenticated(
            biometricEnabled: biometricEnabled,
            biometricAvailable: biometricAvailable,
          ),
        );
      }
    } catch (e) {
      emit(AuthState.error('Initialization error: $e', cause: e));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      final loginResponse = await privateApiClient.login(
        event.email,
        event.password,
      );

      if (loginResponse != null) {
        await _storage.write(
          privateUserKey,
          jsonEncode(loginResponse['person']),
        );
        await _storage.write(privateTokenKey, loginResponse['token']);

        privateApiClient.setAuthToken(loginResponse['token']);

        /// Configure services with authenticated API client
        AirportTimingService.configure(privateApiClient);
        ArrivalsBoardService.configure(privateApiClient);
        LocationClarificationService.configure(privateApiClient);
        PushNotificationService.instance.registerTokenWithClient(
          privateApiClient,
        );

        /// Connect WebSocket for real-time updates
        _webSocketService.connect(
          loginResponse['token'],
          wsBaseUrl: ApiClient.wsBaseUrl,
        );

        final user = Person.fromJson(loginResponse['person']);

        // Apply the user's preferred language — backend is the source of truth.
        final preferredLanguage = user.preferredLanguage;
        if (preferredLanguage != null) {
          final locale = localeFromString(preferredLanguage);
          if (locale != null) {
            localeNotifier.value = locale;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('language', preferredLanguage);
          }
        }

        // Carry the biometric flags into the authenticated state so the Face ID
        // login button (gated on biometricAvailable && biometricEnabled) shows
        // immediately after a password login when biometrics are already set up,
        // and so the Settings toggle reflects availability. Mirrors
        // _onInitializeRequested; without this they defaulted to false and the
        // button stayed hidden until the next app launch / session restore.
        bool biometricAvailable = false;
        bool biometricEnabled = false;
        try {
          biometricAvailable = await privateBiometricService.isAvailable;
          biometricEnabled = await privateBiometricService.isBiometricEnabled;
        } catch (_) {
          // Biometric not available on this platform
        }

        // A user created with a temporary password must change it before using
        // the app — gate behind the forced password-change screen.
        emit(
          user.mustChangePassword
              ? AuthState.mustChangePassword(
                  user,
                  biometricEnabled: biometricEnabled,
                  biometricAvailable: biometricAvailable,
                )
              : AuthState.authenticated(
                  user,
                  biometricEnabled: biometricEnabled,
                  biometricAvailable: biometricAvailable,
                ),
        );
      } else {
        emit(AuthState.error('Invalid email or password'));
      }
    } catch (e) {
      emit(AuthState.error('Login error: $e', cause: e));
    }
  }

  /// Forced password change for a temporary-password user. Changes the password
  /// via the API, then re-logs in with the new password so the session carries a
  /// fresh token (the backend invalidates the old token on change) and the
  /// updated user (mustChangePassword now false) — landing the user in the app.
  Future<void> _onPasswordChangeRequested(
    AuthPasswordChangeRequested event,
    Emitter<AuthState> emit,
  ) async {
    final email = state.user?.email;
    if (email == null) {
      emit(AuthState.error('No user to change password for'));
      return;
    }
    emit(AuthState.loading());
    try {
      await privateApiClient.put('/users/change-password', {
        'currentPassword': event.currentPassword,
        'newPassword': event.newPassword,
      });
    } catch (e) {
      // Surface the failure but keep the user on the forced-change gate so they
      // can retry (e.g. wrong temporary password, weak new password).
      emit(
        AuthState(
          status: AuthStatus.mustChangePassword,
          user: state.user,
          errorMessage: 'Failed to change password: $e',
          error: e,
        ),
      );
      return;
    }
    // Re-authenticate with the new password; reuses the full login path
    // (token persist, WS connect, biometric flags, mustChangePassword re-check).
    await _onLoginRequested(
      AuthLoginRequested(email: email, password: event.newPassword),
      emit,
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      await _clearSession();
      emit(AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.error('Logout error: $e', cause: e));
    }
  }

  /// Forced logout on a 401 (expired/invalid token). Clears the session and
  /// surfaces a "session expired" message on the login screen so the user knows
  /// why they were signed out, instead of silently dropping to it.
  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    // Ignore if we are not (or no longer) authenticated — avoids clobbering a
    // fresh login screen with a stale "session expired" message.
    if (!state.isAuthenticated) return;
    try {
      await _clearSession();
    } catch (_) {
      // Best-effort cleanup; we still want to surface the expiry below.
    }
    emit(AuthState.error('Session expired. Please sign in again.'));
  }

  /// Tears down all session state: stored token/user, in-memory token, the
  /// WebSocket connection, and the FCM registration.
  Future<void> _clearSession() async {
    await _storage.delete(privateUserKey);
    await _storage.delete(privateTokenKey);

    privateApiClient.clearAuthToken();

    /// Disconnect WebSocket
    _webSocketService.disconnect();

    /// Unregister FCM token
    await PushNotificationService.instance.unregisterToken();
  }

  void _onErrorCleared(AuthErrorCleared event, Emitter<AuthState> emit) {
    if (state.hasError) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: null,
          error: null,
        ),
      );
    }
  }

  Future<void> _onBiometricLoginRequested(
    AuthBiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: AuthStatus.loading,
          errorMessage: null,
          error: null,
        ),
      );

      final biometricAvailable = await privateBiometricService.isAvailable;
      final biometricEnabled = await privateBiometricService.isBiometricEnabled;

      if (!biometricAvailable) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Biometrics is not available on this device',
          ),
        );
        return;
      }

      if (!biometricEnabled) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Biometrics is not configured. Enable it in settings',
          ),
        );
        return;
      }

      final result = await privateBiometricService.authenticate();

      if (result.isSuccess) {
        final userData = await _storage.read(privateUserKey);
        final token = await _storage.read(privateTokenKey);

        if (userData != null && token != null) {
          final userJson = jsonDecode(userData);
          final user = Person.fromJson(userJson);
          privateApiClient.setAuthToken(token);

          _webSocketService.connect(token, wsBaseUrl: ApiClient.wsBaseUrl);

          emit(
            AuthState.authenticated(
              user,
              biometricEnabled: biometricEnabled,
              biometricAvailable: biometricAvailable,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'User data not found. Please log in again',
            ),
          );
        }
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: result.message,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Biometric authentication error: $e',
          error: e,
        ),
      );
    }
  }

  Future<void> _onBiometricSetupRequested(
    AuthBiometricSetupRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final biometricAvailable = await privateBiometricService.isAvailable;

      if (!biometricAvailable) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Biometrics is not available on this device',
          ),
        );
        return;
      }

      if (event.enabled) {
        // requireEnabled:false — this IS the enable step, so the persisted
        // flag is still false here; gating on it would make setup impossible.
        final result = await privateBiometricService.authenticate(
          reason: 'Confirm biometric login setup',
          requireEnabled: false,
        );

        if (result.isSuccess) {
          await privateBiometricService.setBiometricEnabled(
            true,
            userId: event.userId,
          );
          emit(state.copyWith(biometricEnabled: true));
        } else {
          emit(
            state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Failed to setup biometrics: ${result.message}',
            ),
          );
        }
      } else {
        await privateBiometricService.setBiometricEnabled(false);
        emit(state.copyWith(biometricEnabled: false));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Biometric setup error: $e',
          error: e,
        ),
      );
    }
  }

  Future<void> _onProfileRefreshRequested(
    AuthProfileRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final response = await privateApiClient.get('/users/profile');
      if (response.statusCode == 200) {
        final userJson = jsonDecode(response.body);
        final user = Person.fromJson(userJson);
        // Persist the refreshed user so the next app start reflects changes
        await _storage.write(privateUserKey, jsonEncode(userJson));
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            errorMessage: null,
          ),
        );
      }
    } catch (_) {
      // Refresh failures are non-fatal — current state is preserved.
    }
  }

  @override
  Future<void> close() {
    privateApiClient.dispose();
    return super.close();
  }
}
