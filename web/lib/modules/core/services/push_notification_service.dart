import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();

  PushNotificationService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  bool _initialized = false;
  bool get isInitialized => _initialized;
  final ApiClient _apiClient = ApiClient();
  StreamSubscription? _tokenRefreshSubscription;
  String? _currentToken;

  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessage => _messageController.stream;

  Future<void> initialize() async {
    // Skip initialization on iOS Simulator as APNS is not supported and it causes noisy logs
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final isSimulator = !Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
      if (isSimulator) {
        debugPrint('PushNotificationService: Skipping initialization on iOS Simulator');
        return;
      }
    }

    try {
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

        _initialized = true;
      } else {
        debugPrint('Push notification permission denied');
      }
    } catch (e) {
      debugPrint('Push notification initialization failed: $e');
    }
  }

  Future<void> _getAndRegisterToken() async {
    try {
      _currentToken = await _messaging.getToken();
      if (_currentToken != null) {
        await _registerTokenWithBackend(_currentToken!);
      }
    } catch (e) {
      final errorMessage = e.toString();
      if (!errorMessage.contains('apns-token-not-set')) {
        debugPrint('Error getting FCM token: $e');
      } else {
        debugPrint('FCM token not available (expected on iOS Simulator)');
      }
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
