import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../modules/core/models/person.dart';
import '../../modules/core/services/api_client.dart';
import '../../modules/auth/services/biometric_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  late ApiClient privateApiClient;
  late BiometricService privateBiometricService;
  
  static const String privateUserKey = 'current_user';
  static const String privateTokenKey = 'auth_token';
  
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  AuthBloc() : super(AuthState.initial()) {
    privateApiClient = ApiClient();
    privateBiometricService = BiometricService();

    on<AuthInitializeRequested>(_onInitializeRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthErrorCleared>(_onErrorCleared);
    on<AuthBiometricLoginRequested>(_onBiometricLoginRequested);
    on<AuthBiometricSetupRequested>(_onBiometricSetupRequested);
  }

  ApiClient get apiClient => privateApiClient;

  Future<void> _onInitializeRequested(
    AuthInitializeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthState.loading());

    try {
      final userData = await _secureStorage.read(key: privateUserKey);
      final token = await _secureStorage.read(key: privateTokenKey);

      final biometricAvailable = await privateBiometricService.isAvailable;
      final biometricEnabled = await privateBiometricService.isBiometricEnabled;

      if (userData != null && token != null) {
        final userJson = jsonDecode(userData);
        final user = Person.fromJson(userJson);
        privateApiClient.setAuthToken(token);

        emit(AuthState.authenticated(user,
          biometricEnabled: biometricEnabled,
          biometricAvailable: biometricAvailable,
        ));
      } else {
        emit(AuthState.unauthenticated(
          biometricEnabled: biometricEnabled,
          biometricAvailable: biometricAvailable,
        ));
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
      privateApiClient = ApiClient();

      final loginResponse = await privateApiClient.login(
        event.email,
        event.password,
      );

      if (loginResponse != null) {
        await _secureStorage.write(
          key: privateUserKey,
          value: jsonEncode(loginResponse['person']),
        );
        await _secureStorage.write(key: privateTokenKey, value: loginResponse['token']);

        privateApiClient.setAuthToken(loginResponse['token']);

        final user = Person.fromJson(loginResponse['person']);
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
      await _secureStorage.delete(key: privateUserKey);
      await _secureStorage.delete(key: privateTokenKey);

      privateApiClient.clearAuthToken();

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
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Biometrics is not available on this device',
        ));
        return;
      }

      if (!biometricEnabled) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Biometrics is not configured. Enable it in settings',
        ));
        return;
      }

      final result = await privateBiometricService.authenticate();

      if (result.isSuccess) {
        final userData = await _secureStorage.read(key: privateUserKey);
        final token = await _secureStorage.read(key: privateTokenKey);

        if (userData != null && token != null) {
          final userJson = jsonDecode(userData);
          final user = Person.fromJson(userJson);
          privateApiClient.setAuthToken(token);

          emit(AuthState.authenticated(user,
            biometricEnabled: biometricEnabled,
            biometricAvailable: biometricAvailable,
          ));
        } else {
          emit(state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'User data not found. Please log in again',
          ));
        }
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.message,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Biometric authentication error: $e',
      ));
    }
  }

  Future<void> _onBiometricSetupRequested(
    AuthBiometricSetupRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final biometricAvailable = await privateBiometricService.isAvailable;

      if (!biometricAvailable) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Biometrics is not available on this device',
        ));
        return;
      }

      if (event.enabled) {
        final result = await privateBiometricService.authenticate(
          reason: 'Confirm biometric login setup',
        );

        if (result.isSuccess) {
          await privateBiometricService.setBiometricEnabled(true, userId: event.userId);
          emit(state.copyWith(biometricEnabled: true));
        } else {
          emit(state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Failed to setup biometrics: ${result.message}',
          ));
        }
      } else {
        await privateBiometricService.setBiometricEnabled(false);
        emit(state.copyWith(biometricEnabled: false));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Biometric setup error: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    privateApiClient.dispose();
    return super.close();
  }
}
