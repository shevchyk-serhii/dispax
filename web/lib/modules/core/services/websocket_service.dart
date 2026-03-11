import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/websocket_event.dart';
import 'api_client.dart';

class WebSocketService {
  static final WebSocketService instance = WebSocketService._();

  WebSocketService._();

  WebSocket? _socket;
  final _eventController = StreamController<WebSocketEvent>.broadcast();
  Timer? _reconnectTimer;
  String? _token;
  int _reconnectAttempt = 0;
  bool _shouldReconnect = false;

  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  String get _wsUrl {
    final baseUrl = ApiClient.privateBaseUrl;
    final httpUrl = baseUrl.replaceFirst('/api', '');
    final wsUrl = httpUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$wsUrl/api/ws?token=$_token';
  }

  Future<void> connect(String token) async {
    _token = token;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_token == null || !_shouldReconnect) return;

    try {
      _socket?.close();
      _socket = await WebSocket.connect(_wsUrl);
      _reconnectAttempt = 0;
      debugPrint('WebSocket connected');

      _socket!.listen(
        (data) {
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
          debugPrint('WebSocket error: $error');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    final delay = min(30, pow(2, _reconnectAttempt).toInt());
    _reconnectAttempt++;

    debugPrint('WebSocket reconnecting in ${delay}s (attempt $_reconnectAttempt)');
    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _socket?.close();
    _socket = null;
    _token = null;
    _reconnectAttempt = 0;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
