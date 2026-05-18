import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/test_data_service.dart';
import 'initialization_event.dart';
import 'initialization_state.dart';

class InitializationBloc extends Bloc<InitializationEvent, InitializationState> {
  InitializationBloc() : super(const InitializationLoading('Initializing Dispax...')) {
    on<InitializeApp>(onInitializeApp);
    on<RetryInitialization>(onRetryInitialization);
  }

  Future<void> onInitializeApp(
    InitializeApp event,
    Emitter<InitializationState> emit,
  ) async {
    await initializeApp(emit);
  }

  Future<void> onRetryInitialization(
    RetryInitialization event,
    Emitter<InitializationState> emit,
  ) async {
    emit(const InitializationLoading('Retrying initialization...'));
    await initializeApp(emit);
  }

  Future<void> initializeApp(Emitter<InitializationState> emit) async {
    try {
      emit(const InitializationLoading('Checking server connection...'));
      await Future.delayed(const Duration(milliseconds: 500));

      final isServerAvailable = await TestDataService.isServerAvailable();
      if (!isServerAvailable) {
        emit(const InitializationLoading('Server offline, using cached data...'));
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      emit(const InitializationCompleted());
    } catch (e) {
      print('Error during initialization: $e');
      emit(InitializationError('Initialization failed: ${e.toString()}'));
    }
  }
}
