// Regression: a successful biometric login must run the same post-login
// wiring as the password/restore paths. Previously it only set the auth token
// and connected the WebSocket, skipping the API-client service configuration
// block and the FCM token (re)registration — so after a session-expired ->
// biometric re-login the services kept a stale client and push registration
// never happened.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/modules/auth/services/biometric_service.dart';
import 'package:dispax/modules/core/services/api_client.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class _FakeApiClient extends Fake implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeApiClient());
  });

  late MockApiClient mockApiClient;
  late MockBiometricService mockBiometricService;
  late MockTokenStorage mockStorage;
  late MockWebSocketService mockWs;
  late MockPushRegistrationService mockPush;

  setUp(() {
    mockApiClient = MockApiClient();
    mockBiometricService = MockBiometricService();
    mockStorage = MockTokenStorage();
    mockWs = MockWebSocketService();
    mockPush = MockPushRegistrationService();

    when(() => mockApiClient.dispose()).thenReturn(null);
    when(() => mockApiClient.setAuthToken(any())).thenReturn(null);
    when(() => mockBiometricService.isAvailable).thenAnswer((_) async => true);
    when(
      () => mockBiometricService.isBiometricEnabled,
    ).thenAnswer((_) async => true);
    when(
      () => mockBiometricService.authenticate(),
    ).thenAnswer((_) async => BiometricAuthResult.success);
    when(() => mockStorage.read(AuthBloc.privateUserKey)).thenAnswer(
      (_) async => jsonEncode(TestFixtures.person().toJson()),
    );
    when(
      () => mockStorage.read(AuthBloc.privateTokenKey),
    ).thenAnswer((_) async => 'bio-token');
    when(
      () => mockWs.connect(any(), wsBaseUrl: any(named: 'wsBaseUrl')),
    ).thenAnswer((_) async {});
    when(
      () => mockPush.registerTokenWithClient(any()),
    ).thenAnswer((_) async {});
    when(() => mockApiClient.get('/users/profile')).thenAnswer(
      (_) async =>
          http.Response(jsonEncode(TestFixtures.person().toJson()), 200),
    );
  });

  test('biometric login success registers the FCM token and connects the '
      'WebSocket (same post-login wiring as the password path)', () async {
    final bloc = AuthBloc(
      apiClient: mockApiClient,
      biometricService: mockBiometricService,
      storage: mockStorage,
      webSocketService: mockWs,
      pushRegistrationService: mockPush,
    );

    bloc.add(const AuthBiometricLoginRequested());
    await bloc.stream.firstWhere((s) => s.status == AuthStatus.authenticated);

    // FCM registration must be handed the authenticated client…
    verify(() => mockPush.registerTokenWithClient(mockApiClient)).called(1);
    // …and the WebSocket connected with the restored token.
    verify(
      () => mockWs.connect('bio-token', wsBaseUrl: any(named: 'wsBaseUrl')),
    ).called(1);

    await bloc.close();
  });
}
