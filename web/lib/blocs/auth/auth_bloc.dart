import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(privateUserKey);
      final token = prefs.getString(privateTokenKey);
      
      // Check biometric availability and settings
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
      // Create fresh ApiClient for login
      privateApiClient = ApiClient();

      final loginResponse = await privateApiClient.login(
        event.email,
        event.password,
      );

      if (loginResponse != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          privateUserKey,
          jsonEncode(loginResponse['person']),
        );
        await prefs.setString(privateTokenKey, loginResponse['token']);

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(privateUserKey);
      await prefs.remove(privateTokenKey);

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

      // Check if biometric is available and enabled
      final biometricAvailable = await privateBiometricService.isAvailable;
      final biometricEnabled = await privateBiometricService.isBiometricEnabled;

      if (!biometricAvailable) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Биометрия недоступна на этом устройстве',
        ));
        return;
      }

      if (!biometricEnabled) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Биометрия не настроена. Включите в настройках',
        ));
        return;
      }

      // Authenticate with biometrics
      final result = await privateBiometricService.authenticate();

      if (result.isSuccess) {
        // Get stored user data
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString(privateUserKey);
        final token = prefs.getString(privateTokenKey);

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
            errorMessage: 'Данные пользователя не найдены. Войдите заново',
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
        errorMessage: 'Ошибка биометрической аутентификации: $e',
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
          errorMessage: 'Биометрия недоступна на этом устройстве',
        ));
        return;
      }

      if (event.enabled) {
        // Test biometric authentication before enabling
        final result = await privateBiometricService.authenticate(
          reason: 'Подтвердите настройку биометрического входа',
        );

        if (result.isSuccess) {
          await privateBiometricService.setBiometricEnabled(true, userId: event.userId);
          emit(state.copyWith(biometricEnabled: true));
        } else {
          emit(state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Не удалось настроить биометрию: ${result.message}',
          ));
        }
      } else {
        // Disable biometric
        await privateBiometricService.setBiometricEnabled(false);
        emit(state.copyWith(biometricEnabled: false));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Ошибка настройки биометрии: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    privateApiClient.dispose();
    return super.close();
  }
}
