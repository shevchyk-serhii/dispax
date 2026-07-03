// Regression: the FCM token unregister must go out AUTHENTICATED and BEFORE
// the session is wiped.
//
// Previously PushNotificationService.unregisterToken always used the bare
// internal ApiClient (never given an auth token), and AuthBloc._clearSession
// cleared the shared client's token before unregistering — so the DELETE
// /users/fcm-token/{token} 401'd silently on every logout and the backend
// kept pushing this user's ride notifications to the logged-out device.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/modules/core/services/push_notification_service.dart';

import '../helpers/mocks.dart';

void main() {
  group('PushNotificationService.unregisterToken', () {
    test('sends the DELETE through the authenticated client', () async {
      final authedClient = MockApiClient();
      when(
        () => authedClient.post(any(), any()),
      ).thenAnswer((_) async => http.Response('{}', 200));
      when(
        () => authedClient.delete(any()),
      ).thenAnswer((_) async => http.Response('', 204));

      final service = PushNotificationService.instance;
      service.debugSetCurrentToken('fcm-token-1');
      addTearDown(() => service.debugSetCurrentToken(null));
      // Login flow: the authenticated client is handed over.
      await service.registerTokenWithClient(authedClient);

      await service.unregisterToken();

      // The unregister must carry Authorization — i.e. go through the
      // authenticated client, not the bare internal one.
      verify(() => authedClient.delete('/users/fcm-token/fcm-token-1'))
          .called(1);
    });
  });

  group('AuthBloc logout ordering', () {
    test('unregisters the FCM token before the auth token is cleared', () async {
      final mockApiClient = MockApiClient();
      final mockPush = MockPushRegistrationService();
      final mockStorage = MockTokenStorage();
      final mockWs = MockWebSocketService();

      when(() => mockApiClient.dispose()).thenReturn(null);
      when(() => mockApiClient.clearAuthToken()).thenReturn(null);
      when(() => mockStorage.delete(any())).thenAnswer((_) async {});
      when(() => mockWs.disconnect()).thenReturn(null);
      when(() => mockPush.unregisterToken()).thenAnswer((_) async {});

      final bloc = AuthBloc(
        apiClient: mockApiClient,
        storage: mockStorage,
        webSocketService: mockWs,
        pushRegistrationService: mockPush,
      );

      bloc.add(const AuthLogoutRequested());
      await bloc.stream.firstWhere(
        (s) => s.status == AuthStatus.unauthenticated,
      );

      verifyInOrder([
        () => mockPush.unregisterToken(),
        () => mockApiClient.clearAuthToken(),
      ]);

      await bloc.close();
    });
  });
}
