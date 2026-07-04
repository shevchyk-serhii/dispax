// SerialTaskQueue serializes the map screens' driver-marker updates: the
// delete→await→create pair is not atomic, so without the queue a concurrent
// update (WS burst, REST fetch racing the first ping) or a pulse-timer tick
// could interleave with it and delete a live marker / leave a duplicate.

import 'dart:async';

import 'package:dispax/utils/serial_task_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SerialTaskQueue', () {
    test('concurrent submissions run strictly one after another', () async {
      final queue = SerialTaskQueue();
      final events = <String>[];
      final firstTaskGate = Completer<void>();

      // First update: "delete" then, after an await (suspended on the gate),
      // "create" — exactly the non-atomic marker replacement.
      final first = queue.run(() async {
        events.add('delete-1');
        await firstTaskGate.future;
        events.add('create-1');
      });
      // Second update fired while the first is still between delete and
      // create.
      final second = queue.run(() async {
        events.add('delete-2');
        events.add('create-2');
      });

      // Let the microtask loop run: the second task must NOT have started.
      await Future<void>.delayed(Duration.zero);
      expect(events, ['delete-1']);

      firstTaskGate.complete();
      await Future.wait([first, second]);

      expect(events, [
        'delete-1',
        'create-1',
        'delete-2',
        'create-2',
      ], reason: 'delete/create pairs must never interleave');
    });

    test('tasks run in submission order', () async {
      final queue = SerialTaskQueue();
      final order = <int>[];
      await Future.wait([
        for (var i = 0; i < 5; i++)
          queue.run(() async {
            // Yield so an unserialized implementation would shuffle.
            await Future<void>.delayed(Duration.zero);
            order.add(i);
          }),
      ]);
      expect(order, [0, 1, 2, 3, 4]);
    });

    test('a failing task does not break the chain for later tasks', () async {
      final queue = SerialTaskQueue();
      final events = <String>[];

      final failing = queue.run(() async => throw StateError('boom'));
      final following = queue.run(() async => events.add('ran'));

      await expectLater(failing, throwsStateError);
      await following;
      expect(events, ['ran']);
    });
  });
}
