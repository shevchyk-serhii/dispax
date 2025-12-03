import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/person.dart';
import '../../services/api_client.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  late ApiClient privateApiClient;

  static const String privateUserKey = 'current_user';
  static const String privateTokenKey = 'auth_token';

  AuthBloc() : super(AuthState.initial()) {
    privateApiClient = ApiClient();

    on<AuthInitializeRequested>(_onInitializeRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthErrorCleared>(_onErrorCleared);
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

      if (userData != null && token != null) {
        final userJson = jsonDecode(userData);
        final user = Person.fromJson(userJson);
        privateApiClient.setAuthToken(token);

        emit(AuthState.authenticated(user));
      } else {
        emit(AuthState.unauthenticated());
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

  @override
  Future<void> close() {
    privateApiClient.dispose();
    return super.close();
  }
}
