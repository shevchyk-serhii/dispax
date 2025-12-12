import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_state_event.dart';
import 'app_state_state.dart';

class AppStateBloc extends Bloc<AppStateEvent, AppState> {
  AppStateBloc() : super(const AppState()) {
    on<AppInitialized>(onAppInitialized);
  }

  void onAppInitialized(
    AppInitialized event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(isInitialized: true));
  }
}