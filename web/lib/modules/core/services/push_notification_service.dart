import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();

  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient();
  StreamSubscription? _tokenRefreshSubscription;
  String? _currentToken;

  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessage => _messageController.stream;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _getAndRegisterToken();

      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        _registerTokenWithBackend(token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FCM foreground message: ${message.messageId}');
        _messageController.add(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('FCM message opened app: ${message.messageId}');
        _messageController.add(message);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _messageController.add(initialMessage);
      }
    } else {
      debugPrint('Push notification permission denied');
    }
  }

  Future<void> _getAndRegisterToken() async {
    try {
      _currentToken = await _messaging.getToken();
      if (_currentToken != null) {
        await _registerTokenWithBackend(_currentToken!);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _apiClient.post('/users/fcm-token', {
        'token': token,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> unregisterToken() async {
    if (_currentToken != null) {
      try {
        await _apiClient.delete('/users/fcm-token/$_currentToken');
      } catch (e) {
        debugPrint('Error unregistering FCM token: $e');
      }
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _messageController.close();
    _apiClient.dispose();
  }
}
