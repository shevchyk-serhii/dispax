import 'dart:convert';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/modules/auth/services/biometric_service.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockApiClient mockApiClient;
  late MockBiometricService mockBiometricService;
  late MockTokenStorage mockStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockBiometricService = MockBiometricService();
    mockStorage = MockTokenStorage();

    when(() => mockApiClient.dispose()).thenReturn(null);
    when(() => mockApiClient.setAuthToken(any())).thenReturn(null);
    when(() => mockApiClient.clearAuthToken()).thenReturn(null);
    when(() => mockBiometricService.isAvailable)
        .thenAnswer((_) async => false);
    when(() => mockBiometricService.isBiometricEnabled)
        .thenAnswer((_) async => false);
    when(() => mockStorage.read(any())).thenAnswer((_) async => null);
    when(() => mockStorage.write(any(), any())).thenAnswer((_) async {});
    when(() => mockStorage.delete(any())).thenAnswer((_) async {});
  });

  AuthBloc buildBloc() => AuthBloc(
        apiClient: mockApiClient,
        biometricService: mockBiometricService,
        storage: mockStorage,
      );

  group('AuthBloc', () {
    test('initial state is unauthenticated', () {
      final bloc = buildBloc();
      expect(bloc.state.status, AuthStatus.initial);
      bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested success emits loading then authenticated',
      build: () {
        final person = TestFixtures.person();
        when(() => mockApiClient.login(any(), any())).thenAnswer(
          (_) async => {
            'person': person.toJson(),
            'token': 'test-token',
          },
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'test@test.com', password: 'pass'),
      ),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.authenticated)
            .having((s) => s.user, 'user', isNotNull),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested null response emits error',
      build: () {
        when(() => mockApiClient.login(any(), any()))
            .thenAnswer((_) async => null);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'bad@test.com', password: 'wrong'),
      ),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.error)
            .having((s) => s.errorMessage, 'errorMessage',
                'Invalid email or password'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested failure emits error',
      build: () {
        when(() => mockApiClient.login(any(), any()))
            .thenThrow(ApiException('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'test@test.com', password: 'pass'),
      ),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLogoutRequested emits loading then unauthenticated',
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthInitializeRequested with stored data emits authenticated',
      build: () {
        final person = TestFixtures.person();
        when(() => mockStorage.read(AuthBloc.privateUserKey))
            .thenAnswer((_) async => jsonEncode(person.toJson()));
        when(() => mockStorage.read(AuthBloc.privateTokenKey))
            .thenAnswer((_) async => 'test-token');
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthInitializeRequested()),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.authenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthInitializeRequested without stored data emits unauthenticated',
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthInitializeRequested()),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthErrorCleared clears error and goes to unauthenticated',
      build: buildBloc,
      seed: () => AuthState.error('Some error'),
      act: (bloc) => bloc.add(const AuthErrorCleared()),
      expect: () => [
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated)
            .having((s) => s.errorMessage, 'errorMessage', isNull),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthBiometricLoginRequested when not available emits error',
      build: () {
        when(() => mockBiometricService.isAvailable)
            .thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthBiometricLoginRequested()),
      expect: () => [
        isA<AuthState>().having((s) => s.isLoading, 'isLoading', true),
        isA<AuthState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.errorMessage, 'msg',
                contains('not available')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthBiometricLoginRequested when not enabled emits error',
      build: () {
        when(() => mockBiometricService.isAvailable)
            .thenAnswer((_) async => true);
        when(() => mockBiometricService.isBiometricEnabled)
            .thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthBiometricLoginRequested()),
      expect: () => [
        isA<AuthState>().having((s) => s.isLoading, 'isLoading', true),
        isA<AuthState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.errorMessage, 'msg',
                contains('not configured')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthBiometricSetupRequested(true) sets biometricEnabled true',
      build: () {
        when(() => mockBiometricService.isAvailable)
            .thenAnswer((_) async => true);
        when(() => mockBiometricService.authenticate(
              reason: any(named: 'reason'),
              stickyAuth: any(named: 'stickyAuth'),
            )).thenAnswer((_) async => BiometricAuthResult.success);
        when(() => mockBiometricService.setBiometricEnabled(
              true,
              userId: any(named: 'userId'),
            )).thenAnswer((_) async => true);
        return buildBloc();
      },
      seed: () => const AuthState(status: AuthStatus.authenticated),
      act: (bloc) => bloc.add(
        const AuthBiometricSetupRequested(enabled: true, userId: 'user-1'),
      ),
      expect: () => [
        isA<AuthState>()
            .having((s) => s.biometricEnabled, 'biometricEnabled', true),
      ],
    );

    test('apiClient is the same instance after repeated logins', () async {
      // Regression: previously a new ApiClient was created on each login,
      // causing RideBloc (which holds a reference to the original) to lose the token.
      final person = TestFixtures.person();
      when(() => mockApiClient.login(any(), any())).thenAnswer(
        (_) async => {'person': person.toJson(), 'token': 'token-1'},
      );

      final bloc = buildBloc();
      final clientBefore = bloc.apiClient;

      bloc.add(const AuthLoginRequested(email: 'a@b.com', password: 'pass'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.apiClient, same(clientBefore));
      bloc.close();
    });

    test('setAuthToken is called with new token on repeated login', () async {
      // Token must be updated on the shared ApiClient instance so all services
      // that hold a reference to it automatically use the new token.
      final person = TestFixtures.person();
      when(() => mockApiClient.login(any(), any())).thenAnswer(
        (_) async => {'person': person.toJson(), 'token': 'new-token'},
      );

      final bloc = buildBloc();
      bloc.add(const AuthLoginRequested(email: 'a@b.com', password: 'pass'));
      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockApiClient.setAuthToken('new-token')).called(1);
      bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'AuthBiometricSetupRequested(false) sets biometricEnabled false',
      build: () {
        when(() => mockBiometricService.isAvailable)
            .thenAnswer((_) async => true);
        when(() => mockBiometricService.setBiometricEnabled(false))
            .thenAnswer((_) async => true);
        return buildBloc();
      },
      seed: () => const AuthState(
          status: AuthStatus.authenticated, biometricEnabled: true),
      act: (bloc) => bloc.add(
        const AuthBiometricSetupRequested(enabled: false),
      ),
      expect: () => [
        isA<AuthState>()
            .having((s) => s.biometricEnabled, 'biometricEnabled', false),
      ],
    );

    test('ApiClient 401 triggers auto-logout via onUnauthorized callback', () async {
      final httpClient = MockClient((_) async => http.Response('', 401));
      final realApiClient = ApiClient(
        client: httpClient,
        baseUrl: 'http://localhost:8080/api',
      );
      realApiClient.setAuthToken('expired-token');

      final bloc = AuthBloc(
        apiClient: realApiClient,
        biometricService: mockBiometricService,
        storage: mockStorage,
      );

      // Trigger 401 — onUnauthorized fires → AuthLogoutRequested dispatched
      try {
        await realApiClient.get('/rides');
      } on UnauthorizedException {
        // expected
      }

      // Give the bloc time to process the dispatched event
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        bloc.state.status,
        anyOf(AuthStatus.loading, AuthStatus.unauthenticated),
      );

      await bloc.close();
    });
  });
}
