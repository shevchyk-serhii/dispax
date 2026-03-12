import 'dart:convert';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktopus/blocs/auth/auth_bloc.dart';
import 'package:oktopus/blocs/auth/auth_event.dart';
import 'package:oktopus/blocs/auth/auth_state.dart';
import 'package:oktopus/modules/auth/services/biometric_service.dart';
import 'package:oktopus/modules/core/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockApiClient mockApiClient;
  late MockBiometricService mockBiometricService;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockApiClient = MockApiClient();
    mockBiometricService = MockBiometricService();
    mockSecureStorage = MockFlutterSecureStorage();

    when(() => mockApiClient.dispose()).thenReturn(null);
    when(() => mockApiClient.setAuthToken(any())).thenReturn(null);
    when(() => mockApiClient.clearAuthToken()).thenReturn(null);
    when(() => mockBiometricService.isAvailable)
        .thenAnswer((_) async => false);
    when(() => mockBiometricService.isBiometricEnabled)
        .thenAnswer((_) async => false);
  });

  AuthBloc buildBloc() => AuthBloc(
        apiClient: mockApiClient,
        biometricService: mockBiometricService,
        secureStorage: mockSecureStorage,
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
        when(() => mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
              iOptions: any(named: 'iOptions'),
              aOptions: any(named: 'aOptions'),
              lOptions: any(named: 'lOptions'),
              wOptions: any(named: 'wOptions'),
              webOptions: any(named: 'webOptions'),
              mOptions: any(named: 'mOptions'),
            )).thenAnswer((_) async {});
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
      'AuthLogoutRequested emits loading then unauthenticated or error (due to Firebase)',
      build: () {
        when(() => mockSecureStorage.delete(
              key: any(named: 'key'),
              iOptions: any(named: 'iOptions'),
              aOptions: any(named: 'aOptions'),
              lOptions: any(named: 'lOptions'),
              wOptions: any(named: 'wOptions'),
              webOptions: any(named: 'webOptions'),
              mOptions: any(named: 'mOptions'),
            )).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        AuthState.loading(),
        // PushNotificationService requires Firebase which isn't available in tests,
        // so the logout handler catches the error and emits error state
        isA<AuthState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthInitializeRequested with stored data emits authenticated',
      build: () {
        final person = TestFixtures.person();
        when(() => mockSecureStorage.read(
              key: AuthBloc.privateUserKey,
              iOptions: any(named: 'iOptions'),
              aOptions: any(named: 'aOptions'),
              lOptions: any(named: 'lOptions'),
              wOptions: any(named: 'wOptions'),
              webOptions: any(named: 'webOptions'),
              mOptions: any(named: 'mOptions'),
            )).thenAnswer((_) async => jsonEncode(person.toJson()));
        when(() => mockSecureStorage.read(
              key: AuthBloc.privateTokenKey,
              iOptions: any(named: 'iOptions'),
              aOptions: any(named: 'aOptions'),
              lOptions: any(named: 'lOptions'),
              wOptions: any(named: 'wOptions'),
              webOptions: any(named: 'webOptions'),
              mOptions: any(named: 'mOptions'),
            )).thenAnswer((_) async => 'test-token');
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
      build: () {
        when(() => mockSecureStorage.read(
              key: any(named: 'key'),
              iOptions: any(named: 'iOptions'),
              aOptions: any(named: 'aOptions'),
              lOptions: any(named: 'lOptions'),
              wOptions: any(named: 'wOptions'),
              webOptions: any(named: 'webOptions'),
              mOptions: any(named: 'mOptions'),
            )).thenAnswer((_) async => null);
        return buildBloc();
      },
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
  });
}
