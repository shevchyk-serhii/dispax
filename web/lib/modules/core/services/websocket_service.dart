import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../models/websocket_event.dart';

/// Minimal interface the AuthBloc depends on so tests can inject a no-op stub
/// without opening a real WebSocket connection.
abstract class WebSocketServiceBase {
  Future<void> connect(String token, {required String wsBaseUrl});
  void disconnect();
}

class WebSocketService implements WebSocketServiceBase {
  static final WebSocketService instance = WebSocketService._();

  WebSocketService._() : _channelFactory = WebSocketChannel.connect;

  /// Test-only constructor: injects the channel factory so tests can observe
  /// connection attempts without opening a real socket.
  @visibleForTesting
  WebSocketService.forTest(this._channelFactory);

  final WebSocketChannel Function(Uri) _channelFactory;

  WebSocketChannel? _channel;
  final _eventController = StreamController<WebSocketEvent>.broadcast();
  Timer? _reconnectTimer;
  String? _token;
  String? _wsBaseUrl;
  int _reconnectAttempt = 0;
  bool _shouldReconnect = false;

  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  String get _wsUrl {
    final uri = Uri.parse(
      '$_wsBaseUrl/api/ws',
    ).replace(queryParameters: {'token': _token ?? ''});
    return uri.toString();
  }

  @override
  Future<void> connect(String token, {required String wsBaseUrl}) async {
    // A reconnect scheduled before this explicit connect (e.g. the socket
    // dropped shortly before a re-login) must not fire afterwards: the stale
    // timer would close the fresh channel and reopen it, losing events in the
    // window. disconnect() already cancels it; connect() must too.
    _reconnectTimer?.cancel();
    _token = token;
    _wsBaseUrl = wsBaseUrl;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_token == null || !_shouldReconnect) return;

    try {
      // 1000 (normalClosure), not 1001 (goingAway): the web_socket backend
      // rejects 1001 ("close code must be 1000 or in the range 3000-4999"),
      // which threw on every reconnect and tore the socket into a reconnect loop.
      _channel?.sink.close(ws_status.normalClosure);
      // Browser WebSocket can't send custom headers; the token is carried in
      // the query string (`?token=...`, see `_wsUrl`), which the server accepts.
      final channel = _channelFactory(Uri.parse(_wsUrl));
      _channel = channel;
      debugPrint('WebSocket connected');

      channel.stream.listen(
        (data) {
          // Receiving any frame confirms a live connection — reset the backoff
          // here rather than on connect, so a flapping socket keeps backing off.
          _reconnectAttempt = 0;
          try {
            final json = jsonDecode(data as String);
            final event = WebSocketEvent.fromJson(json);
            _eventController.add(event);
          } catch (e) {
            debugPrint('WebSocket parse error: $e');
          }
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('WebSocket connect error: $error');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    final delay = max(1, min(30, pow(2, _reconnectAttempt).toInt()));
    _reconnectAttempt++;

    debugPrint(
      'WebSocket reconnecting in ${delay}s (attempt $_reconnectAttempt)',
    );
    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  @override
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    // 1000, not 1001 — see _doConnect: the web_socket backend rejects 1001.
    _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    _token = null;
    _reconnectAttempt = 0;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
