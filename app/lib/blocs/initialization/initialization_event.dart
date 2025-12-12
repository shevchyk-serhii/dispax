abstract class InitializationEvent {
  const InitializationEvent();
}

class InitializeApp extends InitializationEvent {
  const InitializeApp();
}

class RetryInitialization extends InitializationEvent {
  const RetryInitialization();
}