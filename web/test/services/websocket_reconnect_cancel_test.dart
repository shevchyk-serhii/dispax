// Regression: connect() must cancel a previously scheduled reconnect timer.
//
// If the socket dropped (reconnect scheduled) and the app then explicitly
// reconnects — e.g. forced-password-change -> re-login calls connect() without
// a disconnect() in between — the stale timer fired later, closed the fresh
// live channel and reopened it, creating a short window of lost events.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:dispax/modules/core/services/websocket_service.dart';

class _FakeSink extends Fake implements WebSocketSink {
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

class _FakeChannel extends Fake implements WebSocketChannel {
  _FakeChannel(this._controller);

  final StreamController<dynamic> _controller;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _FakeSink();
}

void main() {
  test('connect() cancels a pending reconnect timer scheduled by a drop', () {
    fakeAsync((async) {
      var connectAttempts = 0;
      final controllers = <StreamController<dynamic>>[];

      final service = WebSocketService.forTest((uri) {
        connectAttempts++;
        final controller = StreamController<dynamic>();
        controllers.add(controller);
        return _FakeChannel(controller);
      });

      // 1. Initial connect.
      unawaited(service.connect('tok', wsBaseUrl: 'ws://test'));
      async.flushMicrotasks();
      expect(connectAttempts, 1);

      // 2. The socket drops -> a reconnect is scheduled.
      unawaited(controllers[0].close());
      async.flushMicrotasks();

      // 3. Explicit re-connect (e.g. re-login) BEFORE the timer fires.
      unawaited(service.connect('tok', wsBaseUrl: 'ws://test'));
      async.flushMicrotasks();
      expect(connectAttempts, 2);

      // 4. The stale timer must NOT fire a third connect that would tear
      //    down the fresh channel (max backoff is 30s, elapse well past it).
      async.elapse(const Duration(seconds: 60));
      expect(
        connectAttempts,
        2,
        reason: 'a stale reconnect timer fired after an explicit connect()',
      );

      service.dispose();
      for (final c in controllers) {
        unawaited(c.close());
      }
    });
  });
}
