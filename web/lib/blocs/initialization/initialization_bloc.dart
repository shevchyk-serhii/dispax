import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/test_data_service.dart';
import 'initialization_event.dart';
import 'initialization_state.dart';

class InitializationBloc extends Bloc<InitializationEvent, InitializationState> {
  InitializationBloc() : super(const InitializationLoading('Initializing Oktopus Taxi...')) {
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
        emit(const InitializationCompleted());
        return;
      }

      emit(const InitializationLoading('Checking database status...'));

      final status = await TestDataService.getTestDataStatus();
      if (status != null) {
        final userCount = status['users_count'] ?? 0;
        final rideCount = status['rides_count'] ?? 0;

        emit(InitializationLoading('Found $userCount users, $rideCount rides'));
        await Future.delayed(const Duration(milliseconds: 500));

        if (userCount == 0 || rideCount == 0) {
          emit(const InitializationLoading('Setting up test data...'));

          final seedSuccess = await TestDataService.seedTestData();
          if (seedSuccess) {
            emit(const InitializationLoading('Test data loaded successfully!'));
          } else {
            emit(const InitializationLoading('Using default configuration...'));
          }
        } else {
          emit(const InitializationLoading('Database ready!'));
        }
      } else {
        emit(const InitializationLoading('Initializing database...'));
        await TestDataService.seedTestData();
      }

      await Future.delayed(const Duration(milliseconds: 1000));
      emit(const InitializationLoading('Welcome to Oktopus Taxi!'));
      await Future.delayed(const Duration(milliseconds: 500));
      emit(const InitializationCompleted());

    } catch (e) {
      print('Error during initialization: $e');
      emit(InitializationError('Initialization failed: ${e.toString()}'));
    }
  }
}