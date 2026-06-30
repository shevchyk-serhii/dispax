abstract class InitializationState {
  const InitializationState();
}

class InitializationLoading extends InitializationState {
  final String statusMessage;

  const InitializationLoading(this.statusMessage);
}

class InitializationCompleted extends InitializationState {
  const InitializationCompleted();
}

class InitializationError extends InitializationState {
  final String errorMessage;

  /// Typed cause, kept for diagnostics/tests. The splash screen shows
  /// [errorMessage] (it renders before localization is ready), but the message
  /// is a neutral, non-technical sentence — the raw cause stays in the logs.
  final Object? error;

  const InitializationError(this.errorMessage, {this.error});
}
