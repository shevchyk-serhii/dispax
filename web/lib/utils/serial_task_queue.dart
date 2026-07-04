import 'dart:async';

/// Runs submitted async tasks strictly one after another, in submission
/// order — a minimal mutex/serial queue.
///
/// Used to serialize map-marker updates: the delete→await→create sequence
/// that replaces the driver dot is not atomic, so a second update (a REST
/// fetch racing the first WebSocket ping, an event burst on reconnect) or a
/// pulse-timer tick could interleave with it — deleting an already-deleted
/// annotation, updating one that is gone, or leaving a duplicate marker.
/// Funnelling every marker mutation through one queue makes each
/// delete+create pair atomic with respect to the others.
class SerialTaskQueue {
  Future<void> _tail = Future<void>.value();

  /// Enqueues [task] to run once every previously enqueued task has finished.
  ///
  /// Returns a future that completes when [task] completes, with its error if
  /// it throws. A failing task never breaks the chain: subsequent tasks still
  /// run.
  Future<void> run(Future<void> Function() task) {
    final result = _tail.then((_) => task());
    // Swallow the error only on the internal chain — the caller still
    // observes it through [result].
    _tail = result.catchError((Object _) {});
    return result;
  }
}
