import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../../core/services/api_client.dart';
import '../../core/models/websocket_event.dart';
import '../models/public_ride.dart';

/// Thrown when a guest tracking link is invalid or expired (HTTP 404). The screen shows a friendly "link expired"
/// state for this rather than a generic error.
class GuestLinkExpiredException implements Exception {
  const GuestLinkExpiredException();
}

/// Read-only access to a ride via a public guest tracking token. No auth: the token itself authorizes exactly one
/// ride. Backed by a tokenless [ApiClient] (no `setAuthToken`), so requests carry no Authorization header.
class GuestTrackService {
  final ApiClient _apiClient;

  GuestTrackService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PublicRide> fetchPublicRide(String token) async {
    final response = await _apiClient.get('/track/$token');
    if (response.statusCode == 404) {
      throw const GuestLinkExpiredException();
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load tracking link (${response.statusCode})',
      );
    }
    return PublicRide.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

/// Lightweight guest WebSocket client for `/api/ws/track?token=`. Mirrors the auth socket's reconnect backoff but is
/// deliberately decoupled from [WebSocketService] (no auth/token assumptions, no singleton) so a guest page can open
/// it without the rest of the app's session machinery.
class GuestWebSocketClient {
  final String _wsBaseUrl;
  final String _token;
  WebSocketChannel? _channel;
  final _eventController = StreamController<WebSocketEvent>.broadcast();
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _shouldReconnect = false;

  GuestWebSocketClient({required String wsBaseUrl, required String token})
    : _wsBaseUrl = wsBaseUrl,
      _token = token;

  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  String get _wsUrl => Uri.parse(
    '$_wsBaseUrl/api/ws/track',
  ).replace(queryParameters: {'token': _token}).toString();

  void connect() {
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    _doConnect();
  }

  void _doConnect() {
    if (!_shouldReconnect) return;
    try {
      _channel?.sink.close(ws_status.normalClosure);
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen(
        (data) {
          _reconnectAttempt = 0;
          try {
            final event = WebSocketEvent.fromJson(jsonDecode(data as String));
            _eventController.add(event);
          } catch (e) {
            debugPrint('Guest WebSocket parse error: $e');
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
    } catch (e) {
      debugPrint('Guest WebSocket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectAttempt++;
    final delaySeconds = min(30, pow(2, _reconnectAttempt).toInt());
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _doConnect);
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close(ws_status.normalClosure);
    _eventController.close();
  }
}
