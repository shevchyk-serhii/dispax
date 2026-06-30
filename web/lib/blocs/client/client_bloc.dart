import 'package:flutter_bloc/flutter_bloc.dart';
import '../../modules/core/services/user_service.dart';
import 'client_event.dart';
import 'client_state.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  final UserService privateUserService;

  ClientBloc({UserService? userService})
    : privateUserService = userService ?? UserService(),
      super(ClientState.initial()) {
    on<ClientLoadRequested>(_onLoadRequested);
    on<ClientCreateRequested>(_onCreateRequested);
    on<ClientUpdateRequested>(_onUpdateRequested);
    on<ClientDeactivateRequested>(_onDeactivateRequested);
    on<ClientSearchRequested>(_onSearchRequested);
  }

  Future<void> _onLoadRequested(
    ClientLoadRequested event,
    Emitter<ClientState> emit,
  ) async {
    emit(ClientState.loading());

    try {
      final clients = await privateUserService.getClients();
      emit(ClientState.loaded(clients));
    } catch (e) {
      emit(ClientState.error('Failed to load clients: $e', cause: e));
    }
  }

  Future<void> _onCreateRequested(
    ClientCreateRequested event,
    Emitter<ClientState> emit,
  ) async {
    emit(state.copyWith(status: ClientStateStatus.loading));

    try {
      final newClient = await privateUserService.createClient(event.request);
      final updatedClients = List.from(state.clients)..add(newClient);
      emit(ClientState.loaded(updatedClients.cast()));
    } catch (e) {
      emit(
        state.copyWith(
          status: ClientStateStatus.error,
          errorMessage: 'Failed to create client: $e',
          error: e,
        ),
      );
    }
  }

  Future<void> _onUpdateRequested(
    ClientUpdateRequested event,
    Emitter<ClientState> emit,
  ) async {
    emit(state.copyWith(status: ClientStateStatus.loading));

    try {
      final updated = await privateUserService.updateClient(
        event.clientId,
        event.request,
      );
      final updatedClients = state.clients.map((c) {
        return c.id == updated.id ? updated : c;
      }).toList();
      emit(ClientState.loaded(updatedClients));
    } catch (e) {
      emit(
        state.copyWith(
          status: ClientStateStatus.error,
          errorMessage: 'Failed to update client: $e',
          error: e,
        ),
      );
    }
  }

  Future<void> _onDeactivateRequested(
    ClientDeactivateRequested event,
    Emitter<ClientState> emit,
  ) async {
    emit(state.copyWith(status: ClientStateStatus.loading));

    try {
      await privateUserService.deactivateClient(event.clientId);
      final updatedClients = state.clients
          .where((c) => c.id != event.clientId)
          .toList();
      emit(ClientState.loaded(updatedClients));
    } catch (e) {
      emit(
        state.copyWith(
          status: ClientStateStatus.error,
          errorMessage: 'Failed to deactivate client: $e',
          error: e,
        ),
      );
    }
  }

  void _onSearchRequested(
    ClientSearchRequested event,
    Emitter<ClientState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  @override
  Future<void> close() {
    privateUserService.dispose();
    return super.close();
  }
}
