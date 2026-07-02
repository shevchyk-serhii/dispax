import 'dart:convert';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/locale_notifier.dart';
import 'package:dispax/modules/auth/services/biometric_service.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/services/websocket_service.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockApiClient mockApiClient;
  late MockBiometricService mockBiometricService;
  late MockTokenStorage mockStorage;
  late MockWebSocketService mockWebSocketService;

  setUp(() {
    mockApiClient = MockApiClient();
    mockBiometricService = MockBiometricService();
    mockStorage = MockTokenStorage();
    mockWebSocketService = MockWebSocketService();

    when(() => mockApiClient.dispose()).thenReturn(null);
    when(() => mockApiClient.setAuthToken(any())).thenReturn(null);
    when(() => mockApiClient.clearAuthToken()).thenReturn(null);
    when(() => mockBiometricService.isAvailable).thenAnswer((_) async => false);
    when(
      () => mockBiometricService.isBiometricEnabled,
    ).thenAnswer((_) async => false);
    when(() => mockStorage.read(any())).thenAnswer((_) async => null);
    when(() => mockStorage.write(any(), any())).thenAnswer((_) async {});
    when(() => mockStorage.delete(any())).thenAnswer((_) async {});
    // Default: the background profile refresh dispatched after a restored session
    // returns the stored user unchanged. Individual tests override to assert the
    // refresh applies server-side changes (e.g. a newly-set hasAvatar).
    when(() => mockApiClient.get('/users/profile')).thenAnswer(
      (_) async => http.Response(jsonEncode(TestFixtures.person().toJson()), 200),
    );
    when(
      () => mockWebSocketService.connect(
        any(),
        wsBaseUrl: any(named: 'wsBaseUrl'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockWebSocketService.disconnect()).thenReturn(null);
  });

  AuthBloc buildBloc() => AuthBloc(
    apiClient: mockApiClient,
    biometricService: mockBiometricService,
    storage: mockStorage,
    webSocketService: mockWebSocketService,
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
          (_) async => {'person': person.toJson(), 'token': 'test-token'},
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

    // Onboarding: a user logging in with a temporary password must be gated
    // behind the forced password-change screen, not let into the app.
    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested emits mustChangePassword when the flag is set',
      build: () {
        final person = TestFixtures.person(mustChangePassword: true);
        when(() => mockApiClient.login(any(), any())).thenAnswer(
          (_) async => {'person': person.toJson(), 'token': 'test-token'},
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'temp@test.com', password: 'Temp1234'),
      ),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.mustChangePassword)
            .having((s) => s.user, 'user', isNotNull),
      ],
    );

    // Onboarding: changing the temporary password re-logs in with the new
    // password and lands the (now non-flagged) user in the authenticated state.
    blocTest<AuthBloc, AuthState>(
      'AuthPasswordChangeRequested changes password then authenticates',
      build: () {
        final flagged = TestFixtures.person(
          email: 'temp@test.com',
          mustChangePassword: true,
        );
        final activated = TestFixtures.person(email: 'temp@test.com');
        // First login (temporary) returns the flagged user; the re-login after
        // the change returns the activated (flag cleared) user.
        final logins = <Map<String, dynamic>>[
          {'person': flagged.toJson(), 'token': 'tmp-token'},
          {'person': activated.toJson(), 'token': 'new-token'},
        ];
        var loginCall = 0;
        when(
          () => mockApiClient.login(any(), any()),
        ).thenAnswer((_) async => logins[loginCall++]);
        when(
          () => mockApiClient.put(any(), any()),
        ).thenAnswer((_) async => http.Response('{}', 200));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const AuthLoginRequested(
            email: 'temp@test.com',
            password: 'Temp1234',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const AuthPasswordChangeRequested(
            currentPassword: 'Temp1234',
            newPassword: 'NewPass123',
          ),
        );
      },
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (s) => s.status,
          'status',
          AuthStatus.mustChangePassword,
        ),
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.authenticated)
            .having((s) => s.user?.mustChangePassword, 'flagCleared', false),
      ],
      verify: (_) {
        verify(
          () => mockApiClient.put('/users/change-password', any()),
        ).called(1);
      },
    );

    // Regression: a password login must carry the biometric flags from
    // BiometricService into the authenticated state. Previously the login
    // handler emitted AuthState.authenticated(user) without them, so they
    // defaulted to false and the Face ID button stayed hidden after login even
    // when biometrics were already enabled (until the next session restore).
    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested success propagates biometric flags into authenticated',
      build: () {
        final person = TestFixtures.person();
        when(() => mockApiClient.login(any(), any())).thenAnswer(
          (_) async => {'person': person.toJson(), 'token': 'test-token'},
        );
        when(
          () => mockBiometricService.isAvailable,
        ).thenAnswer((_) async => true);
        when(
          () => mockBiometricService.isBiometricEnabled,
        ).thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'test@test.com', password: 'pass'),
      ),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.authenticated)
            .having((s) => s.biometricAvailable, 'biometricAvailable', true)
            .having((s) => s.biometricEnabled, 'biometricEnabled', true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested null response emits error',
      build: () {
        when(
          () => mockApiClient.login(any(), any()),
        ).thenAnswer((_) async => null);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'bad@test.com', password: 'wrong'),
      ),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Invalid email or password',
            )
            // Phase 3 triage: an intentional DOMAIN message must NOT carry a
            // typed cause, so the UI shows it verbatim instead of collapsing it
            // to a generic "something went wrong" via friendlyError.
            .having((s) => s.error, 'error (domain → none)', isNull),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested failure emits error',
      build: () {
        when(
          () => mockApiClient.login(any(), any()),
        ).thenThrow(ApiException('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'test@test.com', password: 'pass'),
      ),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>()
            .having((s) => s.hasError, 'hasError', true)
            // A NETWORK-class failure DOES carry the typed cause → friendlyError.
            .having(
              (s) => s.error,
              'error (network → typed)',
              isA<ApiException>(),
            ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLogoutRequested emits loading then unauthenticated',
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (s) => s.status,
          'status',
          AuthStatus.unauthenticated,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthInitializeRequested with stored data emits authenticated',
      build: () {
        final person = TestFixtures.person();
        when(
          () => mockStorage.read(AuthBloc.privateUserKey),
        ).thenAnswer((_) async => jsonEncode(person.toJson()));
        when(
          () => mockStorage.read(AuthBloc.privateTokenKey),
        ).thenAnswer((_) async => 'test-token');
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthInitializeRequested()),
      // authenticated(restored) then a second authenticated after the background
      // /users/profile refresh dispatched by _onInitializeRequested.
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (s) => s.status,
          'status',
          AuthStatus.authenticated,
        ),
        isA<AuthState>().having(
          (s) => s.status,
          'status',
          AuthStatus.authenticated,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthInitializeRequested refreshes a stale stored user from /users/profile '
      '(picks up a hasAvatar set after the last login)',
      build: () {
        // Stored session is stale: it was saved by a login before the avatar
        // existed, so hasAvatar is false.
        final stored = TestFixtures.person(hasAvatar: false);
        when(
          () => mockStorage.read(AuthBloc.privateUserKey),
        ).thenAnswer((_) async => jsonEncode(stored.toJson()));
        when(
          () => mockStorage.read(AuthBloc.privateTokenKey),
        ).thenAnswer((_) async => 'test-token');
        // The backend now reports the avatar is present.
        final fresh = TestFixtures.person(hasAvatar: true);
        when(() => mockApiClient.get('/users/profile')).thenAnswer(
          (_) async => http.Response(jsonEncode(fresh.toJson()), 200),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthInitializeRequested()),
      // loading → authenticated(stale, hasAvatar:false) → authenticated(fresh,
      // hasAvatar:true) after the background refresh.
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having((s) => s.user?.hasAvatar, 'hasAvatar', false),
        isA<AuthState>().having((s) => s.user?.hasAvatar, 'hasAvatar', true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthInitializeRequested without stored data emits unauthenticated',
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthInitializeRequested()),
      expect: () => [
        AuthState.loading(),
        isA<AuthState>().having(
          (s) => s.status,
          'status',
          AuthStatus.unauthenticated,
        ),
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
        when(
          () => mockBiometricService.isAvailable,
        ).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthBiometricLoginRequested()),
      expect: () => [
        isA<AuthState>().having((s) => s.isLoading, 'isLoading', true),
        isA<AuthState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.errorMessage, 'msg', contains('not available')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthBiometricLoginRequested when not enabled emits error',
      build: () {
        when(
          () => mockBiometricService.isAvailable,
        ).thenAnswer((_) async => true);
        when(
          () => mockBiometricService.isBiometricEnabled,
        ).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthBiometricLoginRequested()),
      expect: () => [
        isA<AuthState>().having((s) => s.isLoading, 'isLoading', true),
        isA<AuthState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.errorMessage, 'msg', contains('not configured')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthBiometricSetupRequested(true) sets biometricEnabled true',
      build: () {
        when(
          () => mockBiometricService.isAvailable,
        ).thenAnswer((_) async => true);
        // Regression: at setup time biometrics are NOT yet enabled. The setup
        // path must call authenticate with requireEnabled:false, otherwise the
        // service short-circuits to "disabled" and enabling is impossible.
        when(
          () => mockBiometricService.isBiometricEnabled,
        ).thenAnswer((_) async => false);
        when(
          () => mockBiometricService.authenticate(
            reason: any(named: 'reason'),
            stickyAuth: any(named: 'stickyAuth'),
            requireEnabled: any(named: 'requireEnabled'),
          ),
        ).thenAnswer((_) async => BiometricAuthResult.success);
        when(
          () => mockBiometricService.setBiometricEnabled(
            true,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => true);
        return buildBloc();
      },
      seed: () => const AuthState(status: AuthStatus.authenticated),
      act: (bloc) => bloc.add(
        const AuthBiometricSetupRequested(enabled: true, userId: 'user-1'),
      ),
      expect: () => [
        isA<AuthState>().having(
          (s) => s.biometricEnabled,
          'biometricEnabled',
          true,
        ),
      ],
      verify: (_) {
        // Setup must bypass the "enabled" precondition.
        verify(
          () => mockBiometricService.authenticate(
            reason: any(named: 'reason'),
            stickyAuth: any(named: 'stickyAuth'),
            requireEnabled: false,
          ),
        ).called(1);
      },
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
      // Wait for the login to actually finish (deterministic, no fixed delay).
      await bloc.stream.firstWhere((s) => s.status == AuthStatus.authenticated);

      expect(bloc.apiClient, same(clientBefore));

      await bloc.close();
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
      await bloc.stream.firstWhere((s) => s.status == AuthStatus.authenticated);

      verify(() => mockApiClient.setAuthToken('new-token')).called(1);

      await bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'AuthBiometricSetupRequested(false) sets biometricEnabled false',
      build: () {
        when(
          () => mockBiometricService.isAvailable,
        ).thenAnswer((_) async => true);
        when(
          () => mockBiometricService.setBiometricEnabled(false),
        ).thenAnswer((_) async => true);
        return buildBloc();
      },
      seed: () => const AuthState(
        status: AuthStatus.authenticated,
        biometricEnabled: true,
      ),
      act: (bloc) =>
          bloc.add(const AuthBiometricSetupRequested(enabled: false)),
      expect: () => [
        isA<AuthState>().having(
          (s) => s.biometricEnabled,
          'biometricEnabled',
          false,
        ),
      ],
    );

    test('ApiClient 401 on an authenticated session forces logout with a '
        '"session expired" message', () async {
      // /users/profile must succeed (the background refresh dispatched on session
      // restore); only /rides returns 401 to drive the forced-logout under test.
      final person = TestFixtures.person();
      final httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/users/profile')) {
          return http.Response(jsonEncode(person.toJson()), 200);
        }
        return http.Response('', 401);
      });
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
      // The forced-logout guard only fires for an authenticated session, so
      // drive the bloc to authenticated via AuthInitializeRequested first.
      when(
        () => mockStorage.read(AuthBloc.privateUserKey),
      ).thenAnswer((_) async => jsonEncode(person.toJson()));
      when(
        () => mockStorage.read(AuthBloc.privateTokenKey),
      ).thenAnswer((_) async => 'expired-token');
      bloc.add(const AuthInitializeRequested());
      await bloc.stream.firstWhere((s) => s.status == AuthStatus.authenticated);

      // Trigger 401 — onUnauthorized fires → AuthSessionExpired dispatched
      try {
        await realApiClient.get('/rides');
      } on UnauthorizedException {
        // expected
      }

      // Wait deterministically for the bloc to reach a terminal error state.
      final state = await bloc.stream.firstWhere(
        (s) => s.status == AuthStatus.error,
      );
      expect(state.errorMessage, contains('Session expired'));
      // Session must be torn down: stored token/user cleared.
      verify(() => mockStorage.delete(AuthBloc.privateTokenKey)).called(1);

      WebSocketService.instance.disconnect();
      await bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'AuthSessionExpired is ignored when not authenticated (no stale '
      '"session expired" on a fresh login screen)',
      build: buildBloc,
      seed: AuthState.unauthenticated,
      act: (bloc) => bloc.add(const AuthSessionExpired()),
      expect: () => const <AuthState>[],
    );

    // ── Locale application on login / session restore ─────────────────────────
    //
    // When AuthBloc loads a user that has a preferredLanguage set on the backend,
    // it must apply that language to localeNotifier immediately so the UI switches
    // without requiring a restart (per the "live-switch" requirement).
    group('locale application', () {
      setUp(() {
        // Reset the global notifier before each test to prevent leakage.
        localeNotifier.value = null;
        // Provide a fake SharedPreferences backend so the in-memory write inside
        // AuthBloc._onLoginRequested / _onInitializeRequested does not hit a
        // real platform channel (which is unavailable in unit tests).
        SharedPreferences.setMockInitialValues({});
      });

      tearDown(() {
        localeNotifier.value = null;
      });

      test(
        'login with preferredLanguage "de" sets localeNotifier to Locale("de")',
        () async {
          final person = TestFixtures.person(preferredLanguage: 'de');
          when(() => mockApiClient.login(any(), any())).thenAnswer(
            (_) async => {'person': person.toJson(), 'token': 'test-token'},
          );

          final bloc = buildBloc();
          bloc.add(
            const AuthLoginRequested(email: 'test@test.com', password: 'pass'),
          );
          await bloc.stream.firstWhere(
            (s) => s.status == AuthStatus.authenticated,
          );

          expect(localeNotifier.value, const Locale('de'));

          await bloc.close();
        },
      );

      test(
        'login with preferredLanguage "uk" sets localeNotifier to Locale("uk")',
        () async {
          final person = TestFixtures.person(preferredLanguage: 'uk');
          when(() => mockApiClient.login(any(), any())).thenAnswer(
            (_) async => {'person': person.toJson(), 'token': 'test-token'},
          );

          final bloc = buildBloc();
          bloc.add(
            const AuthLoginRequested(email: 'test@test.com', password: 'pass'),
          );
          await bloc.stream.firstWhere(
            (s) => s.status == AuthStatus.authenticated,
          );

          expect(localeNotifier.value, const Locale('uk'));

          await bloc.close();
        },
      );

      test(
        'login with null preferredLanguage does not change localeNotifier',
        () async {
          // Set a pre-existing locale to confirm it is not touched.
          localeNotifier.value = const Locale('en');

          final person = TestFixtures.person(preferredLanguage: null);
          when(() => mockApiClient.login(any(), any())).thenAnswer(
            (_) async => {'person': person.toJson(), 'token': 'test-token'},
          );

          final bloc = buildBloc();
          bloc.add(
            const AuthLoginRequested(email: 'test@test.com', password: 'pass'),
          );
          await bloc.stream.firstWhere(
            (s) => s.status == AuthStatus.authenticated,
          );

          // localeNotifier must remain unchanged — we did not override it.
          expect(localeNotifier.value, const Locale('en'));

          await bloc.close();
        },
      );

      test(
        'AuthInitializeRequested with stored user that has preferredLanguage "de" sets localeNotifier',
        () async {
          final person = TestFixtures.person(preferredLanguage: 'de');
          when(
            () => mockStorage.read(AuthBloc.privateUserKey),
          ).thenAnswer((_) async => jsonEncode(person.toJson()));
          when(
            () => mockStorage.read(AuthBloc.privateTokenKey),
          ).thenAnswer((_) async => 'test-token');

          final bloc = buildBloc();
          bloc.add(const AuthInitializeRequested());
          await bloc.stream.firstWhere(
            (s) => s.status == AuthStatus.authenticated,
          );

          expect(localeNotifier.value, const Locale('de'));

          await bloc.close();
        },
      );

      test(
        'AuthInitializeRequested with stored user without preferredLanguage does not change localeNotifier',
        () async {
          localeNotifier.value = const Locale('uk');

          final person = TestFixtures.person(preferredLanguage: null);
          when(
            () => mockStorage.read(AuthBloc.privateUserKey),
          ).thenAnswer((_) async => jsonEncode(person.toJson()));
          when(
            () => mockStorage.read(AuthBloc.privateTokenKey),
          ).thenAnswer((_) async => 'test-token');

          final bloc = buildBloc();
          bloc.add(const AuthInitializeRequested());
          await bloc.stream.firstWhere(
            (s) => s.status == AuthStatus.authenticated,
          );

          // Pre-existing locale must be preserved — bloc must not clear it.
          expect(localeNotifier.value, const Locale('uk'));

          await bloc.close();
        },
      );
    });
  });
}
