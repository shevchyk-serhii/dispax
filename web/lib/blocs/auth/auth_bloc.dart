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
      if (_useFallback) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      }
      return await _secure!.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      if (_useFallback) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
        return;
      }
      await _secure!.write(key: key, value: value);
    } catch (_) {
      // Storage write failed — token won't persist across restarts
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      if (_useFallback) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
        return;
      }
      await _secure!.delete(key: key);
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
    privateApiClient.onUnauthorized = () => add(AuthLogoutRequested());
    privateBiometricService = biometricService ?? BiometricService();

    on<AuthInitializeRequested>(_onInitializeRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
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
        if (user.preferredLanguage != null) {
          final locale = localeFromString(user.preferredLanguage);
          if (locale != null) {
            localeNotifier.value = locale;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('language', user.preferredLanguage!);
          }
        }

        /// Configure services with authenticated API client
        AirportTimingService.configure(privateApiClient);
        LocationClarificationService.configure(privateApiClient);
        PushNotificationService.instance.registerTokenWithClient(
          privateApiClient,
        );

        /// Connect WebSocket for real-time updates
        _webSocketService.connect(
          token,
          wsBaseUrl: ApiClient.wsBaseUrl,
        );

        emit(
          AuthState.authenticated(
            user,
            biometricEnabled: biometricEnabled,
            biometricAvailable: biometricAvailable,
          ),
        );
      } else {
        emit(
          AuthState.unauthenticated(
            biometricEnabled: biometricEnabled,
            biometricAvailable: biometricAvailable,
          ),
        );
      }
    } catch (e) {
      emit(AuthState.error('Initialization error: $e'));
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
        if (user.preferredLanguage != null) {
          final locale = localeFromString(user.preferredLanguage);
          if (locale != null) {
            localeNotifier.value = locale;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('language', user.preferredLanguage!);
          }
        }

        emit(AuthState.authenticated(user));
      } else {
        emit(AuthState.error('Invalid email or password'));
      }
    } catch (e) {
      emit(AuthState.error('Login error: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      await _storage.delete(privateUserKey);
      await _storage.delete(privateTokenKey);

      privateApiClient.clearAuthToken();

      /// Disconnect WebSocket
      _webSocketService.disconnect();

      /// Unregister FCM token
      await PushNotificationService.instance.unregisterToken();

      emit(AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.error('Logout error: $e'));
    }
  }

  void _onErrorCleared(AuthErrorCleared event, Emitter<AuthState> emit) {
    if (state.hasError) {
      emit(
        state.copyWith(status: AuthStatus.unauthenticated, errorMessage: null),
      );
    }
  }

  Future<void> _onBiometricLoginRequested(
    AuthBiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(state.copyWith(status: AuthStatus.loading));

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

          _webSocketService.connect(
            token,
            wsBaseUrl: ApiClient.wsBaseUrl,
          );

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
        final result = await privateBiometricService.authenticate(
          reason: 'Confirm biometric login setup',
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
