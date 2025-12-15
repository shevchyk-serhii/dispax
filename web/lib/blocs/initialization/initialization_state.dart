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

  const InitializationError(this.errorMessage);
}